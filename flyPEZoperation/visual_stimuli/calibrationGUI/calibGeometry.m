function g = calibGeometry(p)
%CALIBGEOMETRY Pixel-to-dome geometry for one calibration parameter set.
%   Lifted line-for-line from projectorCalibration3000_v3.m (L59-62, 224,
%   228-238, 247-416) so the maths matches the original script exactly.
%   p is a struct holding the 13 calibration parameters (see calibParamSpec).
%   g holds the elevation/azimuth maps and the values calibBrightness and
%   calibImages need.
optimizeOutsideView = 0;
atMirPlane2projector = p.atMirPlane2projector;
sphereCircumference = p.sphereCircumference;
zoomTheta = p.zoomTheta;
sphDropDiff = p.sphDropDiff;
whRatioAdjust = p.whRatioAdjust;
topThreshFactor = p.topThreshFactor;
stimRefROI = p.stimRefROI;
hypSkewTB = p.hypSkewTB;
hypSkewLR = p.hypSkewLR;
hypTwistA = p.hypTwistA;
hypTwistB = p.hypTwistB;
hypTwistC = p.hypTwistC;
hypTwistD = p.hypTwistD;

height = 768;
width = 1024;
hW = round(width/2);
hH = round(height/2);
stimRefROI = [stimRefROI stimRefROI+35];

stimRef = ones(height,width);
stimRef(1:stimRefROI(2),:) = 0;
stimRef(stimRefROI(4):end,:) = 0;
stimRef(:,1:stimRefROI(1)) = 0;
stimRef(:,stimRefROI(3):end) = 0;

initIm = zeros(height-2,width-2);
initIm = padarray(initIm,[1 1],1);
initIm(hH:hH+1,:) = 1;
initIm(:,hW:hW+1) = 1;
crosshairsIm = repmat(uint8((initIm+stimRef).*255),[1 1 3]);

wallFbot = .15;

%%%%% Conversion functions, anonymous
in2mm = @(x) x.*25.4;%inch to mm conversion
mm2in = @(x) x./25.4;
deg2rad = @(x) x*(pi/180);
rad2deg = @(x) x./(pi/180);

%%%%% Variables from specs (these values shouldn't change)
% adds distance from lens to theoretical point source %
atMirPlane2projector = atMirPlane2projector+((0.25)/tan(deg2rad(zoomTheta/2)))*2;
% accounts for distance of dome center below mirror plane %
distOfSphereBelow = 0.710+sphDropDiff;
atMid_proj2wall = in2mm(atMirPlane2projector+distOfSphereBelow);
% Radii %
mirTheta = deg2rad(42.7);%angle of the mirror
minTheta = deg2rad(-21);%minimum elevation to be projected onto the dome
mirRtop = in2mm(11.955/2-0.09);%radius from center axis to top of mirror
% radius from center axis at sphere center to mirror %
mirRcntr = mirRtop-in2mm(tan(mirTheta)*(distOfSphereBelow-0.083));
sphR = (sphereCircumference/pi)/2;%radius of sphere in mm

%%%%% Variables derived from measurements
onWall_bot2top = tan(deg2rad(zoomTheta/2))*atMid_proj2wall*2;
onWall_floor2bot = wallFbot*onWall_bot2top;
onWall_floor2top = (onWall_bot2top+onWall_floor2bot);
onWall_floor2mid = (onWall_floor2bot+0.5*(onWall_floor2top-onWall_floor2bot))*1;%%%%%had been reducing this
onFloor_proj2wall = sqrt(atMid_proj2wall^2-onWall_floor2mid^2)*1.0;%%%%%



%%%%% Minor adjustments only!!! %%%%%
segTopFactor = 0;%skews the top half of the screen
segBotFactor = -0;%skews the bottom half of the screen
segShiftFactor = -0;
segStretchFactor = 1.0;
segSkewFactor = 1.0;
segSkewVector = (linspace(0,1,height+1).^segSkewFactor-linspace(0,1,height+1)).*(-1)+1;
thetaMidFactor = 1.0;%rocks top v bottom elevation lines and shifts

onWallSegments = (linspace(onWall_floor2top+segTopFactor,...
    onWall_floor2bot+segBotFactor,...
    height+1)+segShiftFactor).*segSkewVector.*segStretchFactor;%%
onWallThetas = atan(onWallSegments./onFloor_proj2wall);
thetaF2M = atan(onWall_floor2mid/onFloor_proj2wall)*thetaMidFactor;
axisThetas = (onWallThetas-thetaF2M).*1;
axisSegments = tan(axisThetas).*atMid_proj2wall;
pixY = axisSegments(1:end-1)+diff(axisSegments)./2;
pixYplane = repmat(pixY(:),1,width).*1;
% pixY(1)+pixY(end)

onWall_mid2side = onWall_bot2top*(width/height)/2*whRatioAdjust;%%
atMidline_proj2wall = sqrt(onFloor_proj2wall^2+onWallSegments.^2);
thetas_mid2sides = atan(onWall_mid2side./atMidline_proj2wall);
atPlane_proj2mids = sqrt(atMid_proj2wall^2+axisSegments.^2);
mid2sides_top2bot = tan(thetas_mid2sides).*atPlane_proj2mids;
mid2sides_top2bot = mid2sides_top2bot(1:end-1)+diff(mid2sides_top2bot)./2;
mid2sides_factors = repmat(linspace(0,1,hW+1),height,1);
mid2sides_hPlaneSegs = repmat(mid2sides_top2bot(:),1,hW+1).*mid2sides_factors;
pixXplaneHalf = diff(mid2sides_hPlaneSegs,[],2)./2+mid2sides_hPlaneSegs(:,1:end-1);
pixXplane = ([fliplr(pixXplaneHalf).*(-1) pixXplaneHalf]);


% The following equation calculates the hypotenuse from the center to each
% pixel of the array, given cumulative sums in x and y from center
hypPlane = sqrt(pixXplane.^2+pixYplane.^2).*1.0;
% hypSkewVecTB = abs(cos(linspace(-pi/2,pi/2,height))-1).*linspace(-hypSkewTB,hypSkewTB,height);
hypSkewVecTB = linspace(-hypSkewTB,hypSkewTB,height);
hypSkewMatTB = repmat(hypSkewVecTB',1,width)+0.5;
% hypSkewVecLR = abs(cos(linspace(-pi/2,pi/2,width))-1).*linspace(-hypSkewLR,hypSkewLR,width);
hypSkewVecLR = linspace(-hypSkewLR,hypSkewLR,width);
hypSkewMatLR = repmat(hypSkewVecLR,height,1)+0.5;
hypPlane = hypPlane.*(hypSkewMatTB+hypSkewMatLR);
%
hypTwistVecA = linspace(-hypTwistA,hypTwistA,height)';
hypTwistMatA = hypTwistVecA*linspace(0,-abs(hypTwistA),width);
hypTwistVecB = linspace(-hypTwistB,hypTwistB,height)';
hypTwistMatB = fliplr(hypTwistVecB*linspace(0,-abs(hypTwistB),width));
hypTwistVecC = linspace(-hypTwistC,hypTwistC,width);
hypTwistMatC = hypTwistVecC'*linspace(0,-abs(hypTwistC),height);
hypTwistVecD = linspace(-hypTwistD,hypTwistD,width);
hypTwistMatD = fliplr(hypTwistVecD'*linspace(0,-abs(hypTwistD),height));
hypTwistPlane = hypTwistMatA+hypTwistMatB+hypTwistMatC'+hypTwistMatD'+1;
hypPlane = hypPlane.*hypTwistPlane;
% figure,imshow(hypTwistMatD',[])
% size(hypTwistMatC)
% max(hypTwistMatC(:))
% min(hypTwistMatC(:))

% figure, imshow(hypSkewMatTB,[])
% plot(hypSkewMatTB(:,1))
% %%
% plot([cos(linspace(-pi/2,0,hH)).*(-1)+2,cos(linspace(0,pi/2,hH))]-1)
% plot(sin(linspace(-pi/2,pi/2,height)))
% figure,plot(cos(linspace(-pi,0,height)))


% The following then subtracts the hypotenuse of the lens from that of the
% plane at the top of the mirror ('opposite' leg) and calculates the theta
% from origin for each pixel, knowing the distance lens is above plane
origTheta = atan(hypPlane./atMid_proj2wall);
% thSkewVecTB = repmat(linspace(0.5-thSkewTB,0.5+thSkewTB,height)',1,width);
% thSkewVecLR = repmat(linspace(0.5-thSkewLR,0.5+thSkewLR,width),height,1);
% origTheta = origTheta.*(thSkewVecTB+thSkewVecLR).*1.0;


%%%%% Determine the elevation at which the reflected rays intercept the
%%%%% dome, in degrees above (+) or below (-) the equator
mirPlane = hypPlane;
outerRingMir = rangesearch(mirPlane(:),mirRtop*topThreshFactor,1);
mirPlane(hypPlane > mirRtop*topThreshFactor*1.1) = NaN; %test: set ring of dots at max hyps around center
hypA = (mirPlane-mirRcntr);
oppA = sin(mirTheta).*hypA;
hypB = oppA./cos(mirTheta-origTheta);
adjB = sin(origTheta).*hypB;
oppC = cos(origTheta).*hypB;
thetaDepart = pi/2-2*mirTheta+origTheta;

mirPlane = mirPlane-adjB;
oppD = tan(thetaDepart).*mirPlane;
oppE = cos(thetaDepart).*(oppD+oppC);
oppE(abs(oppE) >= sphR) = NaN;
thetaE = asin(oppE./sphR);
eleFrmMir = thetaE-thetaDepart;

stimEleFrmMir = eleFrmMir;
eleFrmMir(eleFrmMir < minTheta) = NaN;
stimEleFrmMir(stimEleFrmMir < deg2rad(-25)) = 0;
stimEleFrmMir(isnan(stimEleFrmMir)) = 0;

%%%%% Determine the elevation at which the central rays intercept the dome,
%%%%% in degrees above the equator.  90 degrees is special, Inf using this
%%%%% method.  Set the center pixel manually (where origTheta=0, oppF=0)

adjT = cos(origTheta).*hypPlane;
adjT(abs(adjT) >= sphR) = NaN;
eleFrmTop = acos(adjT./sphR)+origTheta;

stimEleFrmTop = eleFrmTop;
stimEleFrmTop(stimEleFrmTop < deg2rad(0)) = 0;
stimEleFrmTop(isnan(stimEleFrmTop)) = 0;
stimEleForProc = stimEleFrmTop+stimEleFrmMir;

if optimizeOutsideView == 1
    fadeSpan = deg2rad(10);
else
    fadeSpan = deg2rad(5);
end
mirMaxEle = min(eleFrmMir(outerRingMir{:}));
topThresh = mirMaxEle-fadeSpan;
eleFrmTop(eleFrmTop < topThresh*0.99) = NaN;
topMask = false(height,width);
topMask(eleFrmTop > topThresh*0.99) = true;

elePlane = eleFrmMir;
elePlane(topMask) = eleFrmTop(topMask);

aziFull = atan2(pixYplane,pixXplane);

aziFrmTop = aziFull;
aziFrmMir = aziFull;
aziFull = aziFrmMir;
aziFull(topMask) = aziFrmTop(topMask);
stimAziForProc = aziFull;

aziFrmTop(~topMask) = NaN;
aziFrmMir(isnan(eleFrmMir)) = NaN;

aziPlane = aziFull;
aziPlane(isnan(elePlane)) = NaN;

g = struct('height',height,'width',width,'hW',hW,'hH',hH,...
    'stimRefROI',stimRefROI,'stimRef',stimRef,'initIm',initIm,...
    'crosshairsIm',crosshairsIm,'sphR',sphR,'minTheta',minTheta,...
    'fadeSpan',fadeSpan,'mirMaxEle',mirMaxEle,'topThresh',topThresh,...
    'eleFrmMir',eleFrmMir,'eleFrmTop',eleFrmTop,'aziPlane',aziPlane,...
    'aziFrmTop',aziFrmTop,'aziFrmMir',aziFrmMir,...
    'stimEleForProc',stimEleForProc,'stimAziForProc',stimAziForProc,...
    'optimizeOutsideView',optimizeOutsideView);
end
