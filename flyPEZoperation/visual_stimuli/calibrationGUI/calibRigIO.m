function varargout = calibRigIO(action,varargin)
%CALIBRIGIO Read and write the files the calibration GUI shares with the rig.
%   dir  = calibRigIO('defaultDir')            shared pez3000_variables folder
%   pezs = calibRigIO('pezList',dir)           struct array: name, ip, controlName
%   r    = calibRigIO('load',dir,pezName)      values + where each came from
%   calibRigIO('saveGui',dir,pezName,vals)     GUI params file (all 14 values)
%   p    = calibRigIO('toParams',vals)         vals struct -> struct for calibGeometry
%   calibRigIO('saveRig',dir,pezName,p,g,b,im) write the files v3 op 5 writes
%   File names match projectorCalibration3000_v3.m (pezNNNN_stimuliVars.mat, ...).
switch action
    case 'defaultDir'
        here = fileparts(mfilename('fullpath'));
        pathFile = fullfile(here,'..','..','flyPEZanalysis','pezFilePath.TXT');
        fid = fopen(pathFile);
        if fid < 0, varargout{1} = ''; return, end
        root = fscanf(fid,'%s'); fclose(fid);
        varargout{1} = fullfile(root,'pez3000_variables');
    case 'pezList'
        t = readtable(fullfile(varargin{1},'computer_info.xlsx'));
        n = height(t);
        pezs = struct('name',cell(n,1),'ip',[],'controlName',[]);
        for k = 1:n
            pezs(k).name = ['pez' num2str(t.pez_reference(k))];
            pezs(k).ip = char(t.stimulus_computer_IP(k));
            pezs(k).controlName = char(t.control_computer_name(k));
        end
        varargout{1} = pezs;
    case 'load'
        varargout{1} = loadValues(varargin{1},varargin{2});
    case 'saveGui'
        saveGui(varargin{:});
    case 'toParams'
        varargout{1} = toParams(varargin{1});
    case 'saveRig'
        saveRig(varargin{:});
    otherwise
        error('calibRigIO:action','Unknown action %s',action);
end
end

function r = loadValues(vd,pezName)
% Values come from, in order of preference: the GUI params file (all 14), then
% the rig's stimuliParams.mat (8 of them). Anything else stays NaN (blank).
spec = calibParamSpec();
keys = {spec.key};
r.vals = cell2struct(num2cell(nan(numel(keys),1)),keys,1);
r.source = cell2struct(repmat({'not set'},numel(keys),1),keys,1);
r.saved = r.vals;                 % "last saved" reference values
r.paramsNewerThanVars = false;
rigP = fullfile(vd,[pezName '_stimuliParams.mat']);
rigV = fullfile(vd,[pezName '_stimuliVars.mat']);
guiP = fullfile(vd,[pezName '_calibGUIparams.mat']);
if exist(rigP,'file')
    s = load(rigP);
    d = dir(rigP);
    tag = ['rig params file ' datestr(d.datenum,'yyyy-mm-dd HH:MM')];
    for k = fieldnames(s)'
        f = k{1};
        if strcmp(f,'stimRefROI')
            r = setVal(r,'stimRefX',double(s.stimRefROI(1)),tag);
            r = setVal(r,'stimRefY',double(s.stimRefROI(2)),tag);
        elseif isfield(r.vals,f)
            r = setVal(r,f,double(s.(f)),tag);
        end
    end
    if exist(rigV,'file')
        v = dir(rigV);
        r.paramsNewerThanVars = d.datenum > v.datenum + 1/1440;
    end
end
if exist(guiP,'file')
    s = load(guiP);
    tag = ['GUI save ' datestr(s.savedAt,'yyyy-mm-dd HH:MM')];
    for f = keys
        if ~isnan(s.vals.(f{1})), r = setVal(r,f{1},s.vals.(f{1}),tag); end
    end
end
end

function r = setVal(r,f,x,tag)
r.vals.(f) = x; r.saved.(f) = x; r.source.(f) = tag;
end

function saveGui(vd,pezName,vals)
savedAt = now; %#ok<TNOW1>
user = getenv('USERNAME'); %#ok<NASGU>
save(fullfile(vd,[pezName '_calibGUIparams.mat']),'vals','savedAt','user');
end

function p = toParams(vals)
p = vals;
p.stimRefROI = [vals.stimRefX vals.stimRefY];
p = rmfield(p,{'stimRefX','stimRefY'});
end

function saveRig(vd,pezName,p,g,b,im)
% Same files and variables as v3 op 5 (L225-226, 747-750, 754). The previous
% rig files are copied to calibGUI_backups first so there is a way back.
bk = fullfile(vd,'calibGUI_backups',[pezName '_' datestr(now,'yyyymmdd_HHMMSS')]);
mkdir(bk);
for suffix = {'_stimuliVars.mat','_stimuliParams.mat','_im2show.tif'}
    f = fullfile(vd,[pezName suffix{1}]);
    if exist(f,'file'), copyfile(f,bk); end
end
atMirPlane2projector = p.atMirPlane2projector; zoomTheta = p.zoomTheta; %#ok<NASGU>
sphDropDiff = p.sphDropDiff; sphereCircumference = p.sphereCircumference; %#ok<NASGU>
hypSkewTB = p.hypSkewTB; hypSkewLR = p.hypSkewLR; %#ok<NASGU>
whRatioAdjust = p.whRatioAdjust; stimRefROI = g.stimRefROI; %#ok<NASGU>
save(fullfile(vd,[pezName '_stimuliParams.mat']),'atMirPlane2projector','zoomTheta',...
    'sphDropDiff','sphereCircumference','hypSkewTB','hypSkewLR','whRatioAdjust','stimRefROI')
stimEleForProc = g.stimEleForProc; stimAziForProc = g.stimAziForProc; %#ok<NASGU>
minTheta = g.minTheta; mirMaxEle = g.mirMaxEle; topThresh = g.topThresh; %#ok<NASGU>
crosshairsIm = im.crosshairsIm; calibImB = im.calibImB; gridIm = im.gridIm; %#ok<NASGU>
vertLinesIm = im.vertLinesIm; gridBackground = im.gridBackground; %#ok<NASGU>
latsOnlyIm = im.latsOnlyIm; shaderTop = b.shaderTop; shaderBot = b.shaderBot; %#ok<NASGU>
gainMatrixBrighter = b.gainMatrixBrighter; gainMatrix = gainMatrixBrighter; %#ok<NASGU>
save(fullfile(vd,[pezName '_stimuliVars.mat']),'gainMatrix','stimEleForProc',...
    'stimAziForProc','stimRefROI','crosshairsIm','calibImB','gridIm','vertLinesIm',...
    'gridBackground','shaderTop','shaderBot','latsOnlyIm','minTheta','mirMaxEle',...
    'topThresh','gainMatrixBrighter')
imwrite(gainMatrixBrighter,fullfile(vd,[pezName '_im2show.tif']))
end
