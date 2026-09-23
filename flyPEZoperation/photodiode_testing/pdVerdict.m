function v = pdVerdict(trace,Fs,camRate,whiteCt,varargin)
%pdVerdict Predict the rig's photodiode pass/fail decision for a bench trace.
%   Takes a high-rate bench recording, decimates it down to the camera frame
%   rate the way runPezControl does, and then runs the production pass/fail
%   math on it.  This answers "would the rig have called this trace good?"
%   without needing the camera, the GUI, or a real trial.
%
%   v = pdVerdict(trace,Fs,camRate,whiteCt)
%   v = pdVerdict(...,'Variant','v13'|'rawDataPrep'|'both')
%
%   trace   - raw photodiode samples, volts (vector)
%   Fs      - sample rate the trace was acquired at, Hz
%   camRate - camera frame rate to simulate, Hz (e.g. 6000)
%   whiteCt - expected number of bright pulses.  The stimulus computer
%             returns this over UDP; do not recompute it if you have it.
%
%   Returns a struct (or 1x2 struct array for 'both') with fields:
%     variant, decision, photoSignalTest, threshold, marginToThreshold,
%     avgBase, avgPeak, minRange, maxRange, nPeaks, whiteCt, peakPos,
%     rangeDiffPeaks, decimatedRate, nFrames.
%
%THE TWO VARIANTS DISAGREE, AND THAT MATTERS.  A trace can pass live and
%then fail reanalysis.  Both are reproduced here deliberately:
%
%   'v13'         - as acquired, runPezControl_v13.m lines 2964-3024
%                   (identical in runPezControl_v16_2.m lines 2995-3055).
%                   frmCount/100 chunks; avgBase = median of the first 300
%                   samples; avgPeak = median of the chunk IQRs; threshold
%                   5; incomplete if nPeaks < whiteCt-2.
%   'rawDataPrep' - as reanalysed, pez3000_rawDataPrep.m lines 686-780
%                   (local function visStimNidaqAnalyzer).  30 chunks;
%                   avgBase/avgPeak are the chunk MEANS of the min- and
%                   max-IQR chunks; threshold 10; incomplete if
%                   nPeaks < whiteCt-1.
%
%Note that in the v13 variant photoSignalTest subtracts a voltage level
%(avgBase) from a spread (median of IQRs), so it is dominated by the
%sensor's DC offset rather than by signal quality.  That is faithful to the
%rig, not a bug here.  The returned avgBase/avgPeak/minRange let you see
%which term is actually driving the number.
%
%This is a COPY of the production algorithm, not a call into it:
%visStimNidaqAnalyzer is a nested local function inside the analysis
%pipeline and cannot be called from outside.  If the production math
%changes, this file must be updated to match.
%
%See also pdLiveMonitor

p = inputParser;
addParameter(p,'Variant','both');
parse(p,varargin{:});
variant = lower(p.Results.Variant);

trace = double(trace(:));
if numel(trace) < 2
    error('pdVerdict:shortTrace','Need at least two samples.')
end
if Fs <= 0 || camRate <= 0
    error('pdVerdict:badRate','Fs and camRate must be positive.')
end
if camRate > Fs
    error('pdVerdict:upsample',...
        ['camRate (%g Hz) exceeds Fs (%g Hz).  This function decimates; '...
        'record faster than the frame rate you want to simulate.'],camRate,Fs)
end

%% Decimate to one sample per camera frame
%runPezControl does mean(reshape(data,overSampleFactor,nFrames)) with an
%integer oversample factor (v13:2933).  Bench traces will not generally
%divide evenly, so integrate-and-difference instead: for integer factors
%this is arithmetically identical to the reshape/mean, and for fractional
%ones it is the same boxcar without silently truncating the tail.
osf = Fs/camRate;
nFrames = floor(numel(trace)/osf);
if nFrames < 10
    error('pdVerdict:tooFewFrames',...
        'Trace decimates to only %d camera frames; record for longer.',nFrames)
end
cumTrace = [0;cumsum(trace)];
edgeIdx = (0:nFrames)'*osf + 1;
cumAtEdge = interp1((1:numel(cumTrace))',cumTrace,edgeIdx,'linear');
diodeData = diff(cumAtEdge)./osf;

%5-point moving average, as v13:2960.  Reimplemented rather than calling
%smooth() so this file does not need the Curve Fitting Toolbox; the
%shrinking-window endpoint handling matches smooth()'s documented default.
%At 6000 fps this boxcar spans 833 us against a 2.78 ms half-period, so it
%costs real amplitude -- skipping it would over-predict passing.
diodeData = localSmooth5(diodeData);

%The v13 variant takes its baseline as median(diodeData(1:300)), which only
%means anything if the trace starts BEFORE the stimulus, while the sensor is
%still in the dark.  A capture that begins mid-flicker puts avgBase halfway
%up the square wave and the scores become meaningless -- in testing, a
%perfect 1 V trace with no lead-in scored 0.5 and "failed" the gate.
%pdLiveMonitor deliberately starts recording before it triggers the
%stimulus; warn if someone feeds in a trace that does not.
baseSpan = min(300,nFrames);
if iqr(diodeData(1:baseSpan)) > 0.25*iqr(diodeData)
    warning('pdVerdict:noLeadIn',...
        ['The first %d decimated frames are almost as variable as the whole '...
        'trace, so this capture probably has no pre-stimulus dark lead-in. '...
        'avgBase will be wrong and the decision should not be trusted. '...
        'Record from before the stimulus starts.'],baseSpan)
end

%% Run the requested variant(s)
switch variant
    case 'v13'
        v = scoreOne(diodeData,camRate,whiteCt,'v13');
    case 'rawdataprep'
        v = scoreOne(diodeData,camRate,whiteCt,'rawDataPrep');
    case 'both'
        v = [scoreOne(diodeData,camRate,whiteCt,'v13'),...
            scoreOne(diodeData,camRate,whiteCt,'rawDataPrep')];
    otherwise
        error('pdVerdict:badVariant',...
            'Variant must be ''v13'', ''rawDataPrep'' or ''both''.')
end
for iterV = 1:numel(v)
    v(iterV).decimatedRate = camRate;
    v(iterV).nFrames = nFrames;
end

end

function v = scoreOne(diodeData,camRate,whiteCt,variantName)
%scoreOne One pass of the production decision math.

frmCount = numel(diodeData);
stimDwellTime = camRate/360;%camera frames per 360 Hz colour sub-frame

isV13 = strcmp(variantName,'v13');
if isV13
    nBrks = round(frmCount/100);
    threshold = 5;
    peakSlack = 2;
else
    nBrks = 30;
    threshold = 10;
    peakSlack = 1;
end
nBrks = max(nBrks,3);%linspace needs at least two chunks to exist

phBrks = round(linspace(1,frmCount,nBrks));
nChunk = numel(phBrks)-1;
ranges = zeros(nChunk,1);
means = zeros(nChunk,1);
for iterPh = 1:nChunk
    chunk = diodeData(phBrks(iterPh):phBrks(iterPh+1));
    ranges(iterPh) = iqr(chunk);
    means(iterPh) = mean(chunk);
end

if isV13
    %v13:2971-2972 -- a level minus a spread, faithfully reproduced
    baseSpan = min(300,frmCount);
    avgBase = median(diodeData(1:baseSpan));
    avgPeak = median(ranges);
else
    %rawDataPrep:748-749 -- both terms are chunk means
    baseCandidates = means(ranges == min(ranges));
    peakCandidates = means(ranges == max(ranges));
    avgBase = baseCandidates(1);
    avgPeak = peakCandidates(1);
end

minRange = min(ranges);
maxRange = max(ranges);
photoSignalTest = abs((avgPeak-avgBase)/minRange);

v = struct('variant',variantName,'decision','','photoSignalTest',photoSignalTest,...
    'threshold',threshold,'marginToThreshold',photoSignalTest-threshold,...
    'avgBase',avgBase,'avgPeak',avgPeak,'minRange',minRange,'maxRange',maxRange,...
    'nPeaks',0,'whiteCt',whiteCt,'peakPos',[],'rangeDiffPeaks',NaN,...
    'decimatedRate',NaN,'nFrames',NaN);

if photoSignalTest < threshold
    v.decision = 'signal to noise ratio insufficient';
    return
end

dataNorm = abs(diodeData-avgBase(1))./maxRange;
minPkHt = 0.25;
pkThresh = 0.5;
dataNorm(dataNorm > pkThresh) = pkThresh;
minPkDist = max(floor(stimDwellTime*1.5),1);
%A trace with no peaks above threshold is a legitimate outcome here (it is
%how a dead sensor presents), so do not let findpeaks warn about it.
warnState = warning('off','signal:findpeaks:largeMinPeakHeight');
[~,peakPos] = findpeaks(dataNorm,'MINPEAKHEIGHT',minPkHt,'MINPEAKDISTANCE',minPkDist);
warning(warnState);

v.peakPos = peakPos;
v.nPeaks = numel(peakPos);
flipLengths = diff(peakPos);
if isempty(flipLengths)
    v.rangeDiffPeaks = NaN;
else
    v.rangeDiffPeaks = max(flipLengths)-min(flipLengths);
end

if v.rangeDiffPeaks > 2
    v.decision = 'frames were dropped';
elseif v.nPeaks < whiteCt-peakSlack
    v.decision = 'visual stimulus incomplete';
else
    v.decision = 'good photodiode';
end

end

function y = localSmooth5(x)
%localSmooth5 Equivalent of smooth(x) with its default 5-point moving average.
%Endpoints use a shrinking symmetric window, matching smooth()'s behaviour:
%y(1) = x(1), y(2) = mean(x(1:3)), y(3) = mean(x(1:5)), and so on.

x = x(:);
n = numel(x);
y = x;
if n < 3
    return
end
cs = [0;cumsum(x)];
for iterS = 1:n
    halfSpan = min([2,iterS-1,n-iterS]);
    lo = iterS-halfSpan;
    hi = iterS+halfSpan;
    y(iterS) = (cs(hi+1)-cs(lo))/(hi-lo+1);
end

end
