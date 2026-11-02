function im = calibImages(g,b)
%CALIBIMAGES Test patterns and final images for the projector.
%   Lifted from projectorCalibration3000_v3.m (L426-483, 631-745). The op 2/3
%   patterns (10-cm lines, transition ring) are generated here in a loop
%   instead of the original early-return branch. g from calibGeometry, b from
%   calibBrightness. im has one field per image, named by what it shows.
height = g.height; width = g.width; stimRef = g.stimRef; initIm = g.initIm;
sphR = g.sphR; mirMaxEle = g.mirMaxEle; topThresh = g.topThresh;
eleFrmMir = g.eleFrmMir; eleFrmTop = g.eleFrmTop; aziPlane = g.aziPlane;
shaderMasterBrighter = b.shaderMasterBrighter;
gainMatrixBrighter = b.gainMatrixBrighter;
deg2rad = @(x) x*(pi/180);
rad2deg = @(x) x./(pi/180);

hXeleVec = (-30:0.5:90);
hXaziVec = (-180:0.5:180);
hXw = numel(hXaziVec);
hXh = numel(hXeleVec);
hXele = repmat(hXeleVec(:),1,hXw);
hXazi = repmat(hXaziVec,hXh,1);

tenCmIm = [];
transitionIm = [];
for calibrateOp = [2 3]
    hVal = zeros(hXh,hXw);
    if calibrateOp == 2
        lats = (0:10:160);
    else
        lats = 0;
    end
    latsMeet = round(rad2deg([mirMaxEle topThresh]));
    latsMeet = abs(deg2rad(latsMeet)-pi/2).*sphR;
    lats = [lats latsMeet];
    latsMat = repmat(lats,hXh,1);
    latsLutMat = repmat((abs(deg2rad(hXeleVec(:))-pi/2).*sphR),1,numel(lats));
    [~,latNdx] = min(abs(latsLutMat-latsMat));
    hVal(latNdx,:) = 1;
    gapSize = 14;%must be even
    blankVals = (1:gapSize:hXw);
    hXele_mm = abs(deg2rad(hXele)-pi/2).*sphR;
    meetRef = [numel(lats)-1 numel(lats)];
    for iterGap = 1:gapSize/2
        hVal(latNdx(meetRef),blankVals(1:end-1)+iterGap-1) = 0;
    end
    VqA = griddata(deg2rad(hXazi),hXele_mm,hVal,aziPlane,abs(eleFrmMir-pi/2).*sphR);
    hVal = zeros(hXh,hXw);
    hVal(latNdx,:) = 1;
    blankVals = (1:gapSize:hXw);
    for iterGap = (gapSize/2+1):gapSize
        hVal(latNdx(meetRef),blankVals(1:end-1)+iterGap-1) = 0;
    end
    VqB = griddata(deg2rad(hXazi),hXele_mm,hVal,aziPlane,abs(eleFrmTop-pi/2).*sphR);
    Vq = max(VqA,VqB);
    Vq(isnan(Vq)) = 0;
    Vq = Vq+stimRef+initIm;
    calibIm = repmat(uint8(Vq.*255),[1 1 3]);
    if calibrateOp == 2
        tenCmIm = calibIm;
    else
        transitionIm = calibIm;
    end
end

%%%%%%%%%%%%%generating a lat line only image
lats = (-30:10:90);
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxA] = min(abs(latsLutMat-latsMat));
hVal = zeros(hXh,hXw);
hVal(latNdxA,:) = 1;
hVal(end-2:end,:) = 1;
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
latsOnlyIm = Vq;

hVal = zeros(hXh,hXw);
lats = round(rad2deg((mirMaxEle+topThresh)/2));
lats = [lats -30 0];
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdx] = min(abs(latsLutMat-latsMat));
hVal(latNdx,:) = 1;
gapSize = 14;%must be even
blankVals = (1:gapSize:hXw);
for iterGap = 1:gapSize/2
    hVal(:,blankVals(1:end-1)+iterGap-1) = 0;
end
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
hVal = zeros(hXh,hXw);
hVal(latNdx,:) = 1;
blankVals = (1:gapSize:hXw);
for iterGap = (gapSize/2+1):gapSize
    hVal(:,blankVals(1:end-1)+iterGap-1) = 0;
end
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
Vq = Vq+stimRef+initIm;
calibImB = repmat(uint8(shaderMasterBrighter.*Vq.*255),[1 1 3]);



% figure,imshow(shaderMaster)
%%%%%%%%%   end making of old shaderMaster

% hXeleVec = (-30:90);
% hXaziVec = (-180:180);
% hXw = numel(hXaziVec);
% hXh = numel(hXeleVec);
% hXele = repmat(hXeleVec(:),1,hXw);
% hXazi = repmat(hXaziVec,hXh,1);
lats = (-30:10:90);
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxA] = min(abs(latsLutMat-latsMat));
longs = (-180:10:180);
longsMat = repmat(longs,hXw,1);
longsLutMat = repmat(hXaziVec(:),1,numel(longs));
[~,longNdxA] = min(abs(longsLutMat-longsMat));

lats = [-2 2];
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxB] = min(abs(latsLutMat-latsMat));
longs = [-180 -90 0 90 180];
longs = [longs-2 longs+2];
longsMat = repmat(longs,hXw,1);
longsLutMat = repmat(hXaziVec(:),1,numel(longs));
[~,longNdxB] = min(abs(longsLutMat-longsMat));

hVal = zeros(hXh,hXw);
hVal(latNdxA,:) = 1;
hVal(:,longNdxA) = 1;
hVal(latNdxB,:) = 0.5;
hVal(:,longNdxB) = 0.5;
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
Vq = Vq+stimRef;
gridIm = repmat(uint8(shaderMasterBrighter.*Vq.*255),[1 1 3]);


%%%%%%%%%%%%%%generating a gridded background
lats = 0;
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxA] = min(abs(latsLutMat-latsMat));

lats = [-2 2];
latsMat = repmat(lats,hXh,1);
latsLutMat = repmat(hXeleVec(:),1,numel(lats));
[~,latNdxB] = min(abs(latsLutMat-latsMat));

hVal = zeros(hXh,hXw);
hVal(latNdxA,:) = 1;
hVal(latNdxB,:) = 0.5;
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
Vq = Vq+stimRef;
gridBackground = shaderMasterBrighter.*abs(Vq-1);
gridBackground = max(gridBackground,stimRef);

%%%%%%%%%%%%%% vertical lines
longs = (-180:10:180);
longsMat = repmat(longs,hXw,1);
longsLutMat = repmat(hXaziVec(:),1,numel(longs));
[~,longNdx] = min(abs(longsLutMat-longsMat));
hVal = zeros(hXh,hXw);
hVal(:,longNdx) = 1;
VqA = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmMir);
VqB = griddata(deg2rad(hXazi),deg2rad(hXele),hVal,aziPlane,eleFrmTop);
Vq = max(VqA,VqB);
Vq(isnan(Vq)) = 0;
vertLinesIm = im2bw(Vq);
vertLinesIm = repmat(uint8(vertLinesIm.*255),[1 1 3]);

im = struct('crosshairsIm',g.crosshairsIm,'tenCmIm',tenCmIm,...
    'transitionIm',transitionIm,'calibImB',calibImB,'gridIm',gridIm,...
    'gridBackground',gridBackground,'vertLinesIm',vertLinesIm,...
    'latsOnlyIm',latsOnlyIm);
end
