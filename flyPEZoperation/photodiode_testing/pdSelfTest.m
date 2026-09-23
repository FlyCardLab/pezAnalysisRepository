function results = pdSelfTest(varargin)
%pdSelfTest Exercise pdVerdict on synthetic traces.  No hardware needed.
%   Builds photodiode traces with a known swing, known noise, and a known
%   single-pole bandwidth, then asks pdVerdict what the rig would decide.
%   Run this before trusting any bench measurement -- and run it on the rig
%   too, so you know the scoring behaves the same there.
%
%   pdSelfTest
%   results = pdSelfTest('Reps',20)
%
%Name/value arguments:
%   'Reps'    repetitions per condition (default 10)
%   'CamRate' camera frame rate to simulate (default 6000)
%   'Fs'      synthetic acquisition rate (default 50000)
%   'Quiet'   true to suppress printing (default false)
%
%WHAT IT ESTABLISHED.  The sweeps below are where the "want" targets in
%pdLiveMonitor's readout come from:
%
%   Bandwidth.  A sensor with a single-pole corner at 120 Hz passes; at
%   100 Hz it starts failing, and not on amplitude -- it fails on
%   'frames were dropped', because rounded peaks jitter their positions
%   past the range(diff(peakPos)) > 2 frame tolerance.  So the requirement
%   is fc >~ 120 Hz, i.e. a 10-90 rise time under about 2.9 ms, or
%   equivalently an AC/DC swing ratio above about 0.75.  That is a far
%   lower bar than "must resolve 360 Hz" implies -- the optical signal is a
%   180 Hz square wave, and the gate only needs one clean maximum per cycle.
%
%   Amplitude.  With a proper dark lead-in, a 50 mV swing passes down to an
%   SNR (swing / noise std) of about 5.  Absolute voltage barely matters;
%   the ratio to the noise floor is what the gate sees.
%
%   Lead-in.  A capture that starts mid-flicker scores nonsense -- an ideal
%   1 V trace with no dark lead-in scores 0.5 and "fails".  This is not a
%   bug in pdVerdict; it is what the rig's own formula does when avgBase
%   lands halfway up the square wave.  Always record from before onset.
%
%See also pdVerdict, pdLiveMonitor

p = inputParser;
addParameter(p,'Reps',10);
addParameter(p,'CamRate',6000);
addParameter(p,'Fs',50000);
addParameter(p,'Quiet',false);
parse(p,varargin{:});
reps = p.Results.Reps;
camRate = p.Results.CamRate;
Fs = p.Results.Fs;
loud = ~p.Results.Quiet;

flickerHz = 180;
stimDur = 0.417;%the default loom_10to180_lv40
leadDur = 0.12;
whiteCt = round(stimDur*flickerHz);
results = struct;

if loud
    fprintf('\npdSelfTest: %g Hz square wave, %g ms stimulus, whiteCt %d, simulating %g fps\n',...
        flickerHz,stimDur*1000,whiteCt,camRate);
end

%% Bandwidth sweep -- where does a slow sensor stop passing?
fcList = [60 80 100 120 150 200 300 1000];
bwFail13 = zeros(numel(fcList),1);
bwFailRD = zeros(numel(fcList),1);
bwRatio = zeros(numel(fcList),1);
for iterF = 1:numel(fcList)
    for iterR = 1:reps
        x = makeTrace(1.0,fcList(iterF),2e-4,Fs,flickerHz,stimDur,leadDur);
        v = pdVerdict(x,Fs,camRate,whiteCt);
        bwFail13(iterF) = bwFail13(iterF)+~strcmp(v(1).decision,'good photodiode');
        bwFailRD(iterF) = bwFailRD(iterF)+~strcmp(v(2).decision,'good photodiode');
    end
    bwRatio(iterF) = achievedRatio(fcList(iterF),Fs,flickerHz,stimDur);
end
results.bandwidth = struct('fc',fcList(:),'acOverDc',bwRatio,...
    'failV13',bwFail13,'failRawDataPrep',bwFailRD,'reps',reps);
if loud
    fprintf('\nBANDWIDTH (1 V swing, noise 2e-4)\n');
    fprintf('   fc(Hz)  ac/dc   v13 fail   rawDataPrep fail\n');
    for iterF = 1:numel(fcList)
        fprintf('   %6d  %.3f   %3d/%-3d    %3d/%-3d\n',fcList(iterF),bwRatio(iterF),...
            bwFail13(iterF),reps,bwFailRD(iterF),reps);
    end
end

%% Amplitude / noise sweep -- how small a swing still passes?
snrList = [2 5 10 50 500];
amp = 0.05;
snFail13 = zeros(numel(snrList),1);
snPst = zeros(numel(snrList),1);
for iterS = 1:numel(snrList)
    pstAcc = 0;
    for iterR = 1:reps
        x = makeTrace(amp,1000,amp/snrList(iterS),Fs,flickerHz,stimDur,leadDur);
        v = pdVerdict(x,Fs,camRate,whiteCt);
        snFail13(iterS) = snFail13(iterS)+~strcmp(v(1).decision,'good photodiode');
        pstAcc = pstAcc+v(1).photoSignalTest;
    end
    snPst(iterS) = pstAcc/reps;
end
results.amplitude = struct('snr',snrList(:),'swing',amp,...
    'failV13',snFail13,'meanPhotoSignalTest',snPst,'reps',reps);
if loud
    fprintf('\nAMPLITUDE (%g mV swing, fc 1 kHz)\n',amp*1000);
    fprintf('      SNR   mean pst   v13 fail\n');
    for iterS = 1:numel(snrList)
        fprintf('   %6g   %8.1f   %3d/%-3d\n',snrList(iterS),snPst(iterS),...
            snFail13(iterS),reps);
    end
end

%% Lead-in check -- confirm the warning fires and the score collapses
xGood = makeTrace(1.0,1000,2e-4,Fs,flickerHz,stimDur,leadDur);
xBad = makeTrace(1.0,1000,2e-4,Fs,flickerHz,stimDur,0);
vGood = pdVerdict(xGood,Fs,camRate,whiteCt,'Variant','v13');
warnState = warning('off','pdVerdict:noLeadIn');
vBad = pdVerdict(xBad,Fs,camRate,whiteCt,'Variant','v13');
warning(warnState);
results.leadIn = struct('withLeadIn',vGood,'withoutLeadIn',vBad);
if loud
    fprintf('\nLEAD-IN (identical 1 V trace, with and without a dark lead-in)\n');
    fprintf('   with    : %-34s pst %10.1f\n',vGood.decision,vGood.photoSignalTest);
    fprintf('   without : %-34s pst %10.1f\n',vBad.decision,vBad.photoSignalTest);
end

%% Verdict
passBW = bwFail13(fcList == 120) == 0 && bwFail13(fcList == 1000) == 0;
passAmp = snFail13(snrList == 500) == 0;
passLead = strcmp(vGood.decision,'good photodiode') &&...
    ~strcmp(vBad.decision,'good photodiode');
results.allPassed = passBW && passAmp && passLead;
if loud
    fprintf('\npdSelfTest: %s\n\n',ternary(results.allPassed,'PASS','FAIL'));
end

end

function x = makeTrace(amp,fc,noiseStd,Fs,flickerHz,stimDur,leadDur)
%makeTrace Dark lead-in, then a band-limited 50%-duty square wave.

tLead = (0:1/Fs:leadDur-1/Fs)';
tStim = (0:1/Fs:stimDur-1/Fs)';
sq = double(mod(tStim*flickerHz,1) < 0.5);%50% duty, 0/1
x = [noiseStd*randn(numel(tLead),1);...
    amp*onePole(sq,fc,Fs)+noiseStd*randn(numel(tStim),1)];

end

function y = onePole(x,fc,Fs)
%onePole Single-pole low-pass, the standard model for a sensor's roll-off.

if isinf(fc)
    y = x;
    return
end
a = exp(-2*pi*fc/Fs);
y = filter(1-a,[1 -a],x);

end

function r = achievedRatio(fc,Fs,flickerHz,stimDur)
%achievedRatio Steady-state AC/DC swing ratio a sensor of this fc produces.

tStim = (0:1/Fs:stimDur-1/Fs)';
sq = double(mod(tStim*flickerHz,1) < 0.5);
y = onePole(sq,fc,Fs);
y = y(round(end/2):end);%skip the settling transient
r = prctile(y,97.5)-prctile(y,2.5);

end

function out = ternary(cond,a,b)
if cond
    out = a;
else
    out = b;
end
end
