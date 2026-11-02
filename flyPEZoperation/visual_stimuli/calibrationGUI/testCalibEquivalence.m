function ok = testCalibEquivalence(pezName,vd)
%TESTCALIBEQUIVALENCE Does the GUI maths reproduce what v3 saved to the rig?
%   Run after projectorCalibration3000_v3 (calibrateOp = 5) has run on this
%   pez's control computer using the values the GUI wrote into the v3 script.
%   Recomputes everything from <pez>_calibGUIparams.mat with calibGeometry /
%   calibBrightness / calibImages and compares it with <pez>_stimuliVars.mat
%   and <pez>_stimuliParams.mat. Prints one line per variable.
if nargin < 2, vd = calibRigIO('defaultDir'); end
s = load(fullfile(vd,[pezName '_calibGUIparams.mat']));
p = calibRigIO('toParams',s.vals);
g = calibGeometry(p); b = calibBrightness(g,vd); im = calibImages(g,b);
f = load(fullfile(vd,[pezName '_stimuliVars.mat']));
mine = struct('gainMatrixBrighter',b.gainMatrixBrighter,'gainMatrix',b.gainMatrixBrighter,...
    'shaderTop',b.shaderTop,'shaderBot',b.shaderBot,'stimEleForProc',g.stimEleForProc,...
    'stimAziForProc',g.stimAziForProc,'stimRefROI',g.stimRefROI,'minTheta',g.minTheta,...
    'mirMaxEle',g.mirMaxEle,'topThresh',g.topThresh,'crosshairsIm',im.crosshairsIm,...
    'calibImB',im.calibImB,'gridIm',im.gridIm,'vertLinesIm',im.vertLinesIm,...
    'gridBackground',im.gridBackground,'latsOnlyIm',im.latsOnlyIm);
ok = true;
for n = fieldnames(mine)'
    a = double(mine.(n{1})); c = double(f.(n{1}));
    if ~isequal(size(a),size(c)), d = Inf; else, d = max(abs(a(:)-c(:)),[],'omitnan'); end
    pass = d < 1e-9; ok = ok && pass;
    fprintf('%-20s max abs diff %-12.3g %s\n',n{1},d,passText(pass));
end
r = load(fullfile(vd,[pezName '_stimuliParams.mat']));
for n = fieldnames(r)'
    want = p.(n{1}); if strcmp(n{1},'stimRefROI'), want = g.stimRefROI; end
    pass = isequal(double(r.(n{1})),want); ok = ok && pass;
    fprintf('%-20s %s\n',['params:' n{1}],passText(pass));
end
fprintf('%s: %s\n',pezName,passText(ok));
end

function t = passText(pass)
if pass, t = 'PASS'; else, t = 'FAIL'; end
end
