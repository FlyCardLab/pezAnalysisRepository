function b = calibBrightness(g,variablesDir)
%CALIBBRIGHTNESS Photodiode-scan brightness correction (shaders, gain).
%   Lifted from projectorCalibration3000_v3.m (L490-622). Like v3, it uses the
%   pez3001 scan file for every rig. g comes from calibGeometry.
height = g.height; width = g.width; stimRef = g.stimRef;
optimizeOutsideView = g.optimizeOutsideView; fadeSpan = g.fadeSpan;
eleFrmTop = g.eleFrmTop; aziFrmTop = g.aziFrmTop;
eleFrmMir = g.eleFrmMir; aziFrmMir = g.aziFrmMir;
topThresh = g.topThresh; mirMaxEle = g.mirMaxEle; minTheta = g.minTheta;
deg2rad = @(x) x*(pi/180);
rad2deg = @(x) x./(pi/180);

useOldStyle = true;
pezNameScan = 'pez3001';
if ~useOldStyle
    scanStatsName = ['photoScanResults_' pezNameScan,...
        '_whiteLED_10AzimuthalSteps_white_pt007_41.mat'];
    % scanStatsName = ['photoScanResults_' pezName,...
    %     '_whiteLED_10AzimuthalSteps.mat'];
else
    scanStatsName = ['photoScanResults_' pezNameScan,...
        '_greenLED_15degLatitudinalSteps.mat'];
end
scanStatsDest = fullfile(variablesDir,'scanningVariables',scanStatsName);
if ~exist(scanStatsDest,'file')
    error('no scan stats file')
end
scanStats = load(scanStatsDest);
scanStats = scanStats.scanStats;
scanmean = @(x) mean(cell2mat(cellfun(@(y) permute(y,[3 2 1]),x,'uniformoutput',false)),3);

fadeSeqVec = linspace(0,1,rad2deg(fadeSpan)+2);
if optimizeOutsideView == 1
    fadeSeqVec = linspace(-0.05,1,rad2deg(fadeSpan)+2);
    fadeSeqVec(fadeSeqVec < 0) = 0;
    fadeSeqVec = fadeSeqVec.^0.85;
    %     fadeSeqVec = fadeSeqVec*0.8;
end
fadeSeq = repmat(fadeSeqVec(2:end-1)',1,360);

rescanResults = cell2mat(scanStats.scanResults_rescan);
minD = median(rescanResults(:));% justified because more than half is black
topDensity = scanmean(scanStats.scanResults_top)';
botDensity = scanmean(scanStats.scanResults_bot)';
if ~useOldStyle
    rangeD = (max([topDensity(:);botDensity(:)])-minD);
    powerFun = 0.007;%white - 0.007%%%%%%%%%
    multiFun = 41;%white - 41 %%%%%%%%%%
else
    rangeD = (prctile([topDensity(:);botDensity(:)],99)-minD);
    powerFun = 1;%white - 0.007%%%%%%%%%
    multiFun = 1;%white - 41 %%%%%%%%%%
end
topDensity = (((topDensity-minD)./(rangeD)).^powerFun)*multiFun;
botDensity = (((botDensity-minD)./(rangeD)).^powerFun)*multiFun;
% topDensity = (topDensity)./range(topDensity(:));
% botDensity = (botDensity)./range(botDensity(:));
filtH = fspecial('average',[3 3]);
topDensity = imfilter(topDensity,filtH,'replicate');
botDensity = imfilter(botDensity,filtH,'replicate');
newMin = min([topDensity(:);botDensity(:)]);


elePos = ((cell2mat(scanStats.degX_top)-90)*(-1))';
aziPos = repmat(scanStats.Properties.RowNames',size(elePos,1),1);
aziPos = round(str2double(aziPos));
[~,sortNdx] = sort(aziPos(1,:));
for iterSort = 1:size(aziPos,1)
    topDensity(iterSort,:) = topDensity(iterSort,sortNdx);
    aziPos(iterSort,:) = aziPos(iterSort,sortNdx);
end
%
eleDestVec = linspace(rad2deg(topThresh),90,round(90-rad2deg(topThresh)))';
aziDestVec = (-179:180);
eleMat = repmat(eleDestVec,1,numel(aziDestVec));
aziMat = repmat(aziDestVec,numel(eleDestVec),1);

expand = @(x) [x x(:,1)];
aziPos = expand(aziPos);
aziPos(:,end) = aziPos(:,end)+360;
topFactor = interp2(expand(elePos)',aziPos',expand(topDensity)',eleMat',aziMat','spline')';
if ~useOldStyle
    topFactor = 1-(topFactor-newMin);
else
    topFactor = topFactor.^(-1);
    filtH = fspecial('average',[5 5]);
    topFactor = imfilter(topFactor,filtH,'replicate');
end
if optimizeOutsideView == 1
    topFactor = topFactor.^0.5;
end
topFacFadePart = topFactor(1:rad2deg(fadeSpan),:);
topFader = topFacFadePart.*fadeSeq;
topFactor(1:rad2deg(fadeSpan),:) = topFader;
Finterp = scatteredInterpolant(deg2rad(eleMat(:)),deg2rad(aziMat(:)),topFactor(:));
vX = Finterp([eleFrmTop(:),aziFrmTop(:)]);
shaderTop = reshape(vX,height,width);
shaderTop(isnan(shaderTop)) = 0;

elePos = ((cell2mat(scanStats.degX_bot)-90)*(-1))';
aziPos = repmat(scanStats.Properties.RowNames',size(elePos,1),1);
aziPos = round(str2double(aziPos));
[~,sortNdx] = sort(aziPos(1,:));
for iterSort = 1:size(aziPos,1)
    botDensity(iterSort,:) = botDensity(iterSort,sortNdx);
    aziPos(iterSort,:) = aziPos(iterSort,sortNdx);
end
eleDestVec = linspace(rad2deg(minTheta),rad2deg(mirMaxEle),...
    round(rad2deg(mirMaxEle)-rad2deg(minTheta)))';
aziDestVec = (-179:180);
eleMat = repmat(eleDestVec,1,numel(aziDestVec));
aziMat = repmat(aziDestVec,numel(eleDestVec),1);

aziPos = expand(aziPos);
aziPos(:,end) = aziPos(:,end)+360;
botFactor = interp2(expand(elePos)',aziPos',expand(botDensity)',eleMat',aziMat','spline')';
if ~useOldStyle
    botFactor = 1-(botFactor-newMin);
else
    botFactor = botFactor.^(-1);
    botFactor = imfilter(botFactor,filtH,'replicate');
end
if optimizeOutsideView == 1
    botFactor = botFactor*0.2;
end
botFacFadePart = botFactor(end-rad2deg(fadeSpan)+1:end,:);
botFader = botFacFadePart.*flipud(fadeSeq);
botFactor(end-rad2deg(fadeSpan)+1:end,:) = botFader;
Finterp = scatteredInterpolant(deg2rad(eleMat(:)),deg2rad(aziMat(:)),botFactor(:));
vX = Finterp([eleFrmMir(:),aziFrmMir(:)]);
shaderBot = reshape(vX,height,width);
shaderBot(isnan(shaderBot)) = 0;

% mesh([topFactor;botFactor])
shaderMasterBrighter = (shaderTop+shaderBot);
shaderMasterBrighter = (shaderMasterBrighter./max(shaderMasterBrighter(:)));
if useOldStyle
    shaderMasterBrighter = mean(cat(3,fliplr(shaderMasterBrighter),shaderMasterBrighter),3);
end
% shaderMasterBrighter = max(cat(3,fliplr(shaderMasterBrighter),shaderMasterBrighter),[],3);
% shaderMasterBrighter = imfilter(shaderMasterBrighter,fspecial('average',[3 3]));
shaderMasterBrighter = max(shaderMasterBrighter,stimRef);
gainMatrixBrighter = repmat(shaderMasterBrighter,[1 1 3]);
gainMatrixBrighter(gainMatrixBrighter < 0) = 0;
gainMatrixBrighter(gainMatrixBrighter > 1) = 1;

b = struct('shaderTop',shaderTop,'shaderBot',shaderBot,...
    'shaderMasterBrighter',shaderMasterBrighter,...
    'gainMatrixBrighter',gainMatrixBrighter);
end
