function projectorCalibrationGUI
%PROJECTORCALIBRATIONGUI Manual projector calibration editor.
%   Pick a pez, edit any value in any order, preview the pattern, send it to
%   the projector, then save to the rig. Values load from the rig's
%   pezNNNN_stimuliParams.mat (8 of 14) and from this GUI's own params file
%   (all 14, written on every save). Values that were never saved start blank.
%   Nothing is sent or written until you press a button and confirm.
%   Written for MATLAB R2013: plain figure/uicontrol, local functions and
%   appdata only (no uifigure, nested functions or later-release calls). Uses
%   the maths in calibGeometry/Brightness/Images, which is copied from
%   projectorCalibration3000_v3.m.
S.spec = calibParamSpec();
S.nP = numel(S.spec);
S.vd = calibRigIO('defaultDir');
S.v3Path = fullfile(fileparts(mfilename('fullpath')),'..','projectorCalibration3000_v3.m');
S.pezs = []; S.cur = ''; S.ip = ''; S.res = []; S.out = [];
S.dirty = true; S.awake = false;
S.viewH = 710; S.rowH = 112; S.innerH = S.nP*S.rowH; S.scrollMax = S.innerH-S.viewH;

fig = figure('Name','Projector calibration (manual)','NumberTitle','off',...
    'MenuBar','none','Toolbar','none','Resize','off','Units','pixels',...
    'Position',[40 40 1300 820],'Color',get(0,'defaultUicontrolBackgroundColor'));
h = buildTopBar(fig,S.vd);
h = buildRows(fig,h,S);
h = buildRightColumn(fig,h);
h.status = uicontrol('Parent',fig,'Style','text','Position',[10 8 1280 44],...
    'HorizontalAlignment','left','String','');
S.h = h;
setappdata(fig,'S',S);
set(fig,'WindowScrollWheelFcn',@(~,evt)cbWheel(fig,evt));
initPezList(fig);
end

%% ---- layout ----------------------------------------------------------------

function h = buildTopBar(fig,vd)
uicontrol('Parent',fig,'Style','text','Position',[10 782 40 20],...
    'String','Pez:','HorizontalAlignment','left');
h.ddPez = uicontrol('Parent',fig,'Style','popupmenu','Position',[55 784 110 22],...
    'String',{'(none)'},'Callback',@(~,~)loadPez(fig));
h.edDir = uicontrol('Parent',fig,'Style','edit','Position',[175 784 700 22],...
    'String',vd,'HorizontalAlignment','left',...
    'TooltipString','Rig folder (pez3000_variables)','Callback',@(~,~)initPezList(fig));
uicontrol('Parent',fig,'Style','pushbutton','Position',[885 783 90 24],...
    'String','Browse...','Callback',@(~,~)cbBrowse(fig));
uicontrol('Parent',fig,'Style','pushbutton','Position',[985 783 130 24],...
    'String','Reload from rig','Callback',@(~,~)loadPez(fig));
end

function h = buildRows(fig,h,S)
% 14 rows in a tall panel that a slider (and the mouse wheel) scrolls.
vp = uipanel('Parent',fig,'Units','pixels','Position',[10 60 880 S.viewH],...
    'BorderType','line');
h.slider = uicontrol('Parent',fig,'Style','slider','Position',[892 60 18 S.viewH],...
    'Min',0,'Max',S.scrollMax,'Value',S.scrollMax,...
    'SliderStep',[60 300]/S.scrollMax,'Callback',@(~,~)cbScroll(fig));
h.inner = uipanel('Parent',vp,'Units','pixels','BorderType','none',...
    'Position',[0 S.viewH-S.innerH 878 S.innerH]);
h.ed = zeros(1,S.nP); h.sv = zeros(1,S.nP);
for k = 1:S.nP
    y = S.innerH - k*S.rowH;
    [h.ed(k),h.sv(k)] = buildRow(fig,h.inner,S.spec(k),k,y);
end
end

function [ed,sv] = buildRow(fig,par,s,k,y)
u = ''; if ~isempty(s.units), u = ['  (' s.units ')']; end
uicontrol('Parent',par,'Style','text','Position',[0 y 878 1],...
    'BackgroundColor',[0.7 0.7 0.7]);
uicontrol('Parent',par,'Style','text','Position',[6 y+90 560 18],...
    'HorizontalAlignment','left','FontWeight','bold',...
    'String',[s.key u '    [step ' s.group ']']);
uicontrol('Parent',par,'Style','text','Position',[6 y+4 565 84],...
    'HorizontalAlignment','left',...
    'String',{s.desc,['Increase: ' s.up],['Decrease: ' s.down]});
ed = uicontrol('Parent',par,'Style','edit','Position',[580 y+82 150 24],...
    'BackgroundColor',[1 1 1],'Callback',@(~,~)cbEdited(fig,k));
uicontrol('Parent',par,'Style','pushbutton','Position',[735 y+82 28 24],...
    'String','+','Callback',@(~,~)cbNudge(fig,k,1));
uicontrol('Parent',par,'Style','pushbutton','Position',[767 y+82 28 24],...
    'String','-','Callback',@(~,~)cbNudge(fig,k,-1));
sv = uicontrol('Parent',par,'Style','text','Position',[580 y+38 285 40],...
    'HorizontalAlignment','left','FontSize',8,'String','');
uicontrol('Parent',par,'Style','pushbutton','Position',[580 y+8 285 24],...
    'String','Revert to last saved','Callback',@(~,~)cbRevert(fig,k));
end

function h = buildRightColumn(fig,h)
h.ddPat = uicontrol('Parent',fig,'Style','popupmenu','Position',[920 746 370 24],...
    'String',{'Crosshairs','10-cm lines','Transition ring','Blended ring',...
    'White background'},'Callback',@(~,~)showPreview(fig));
h.ax = axes('Parent',fig,'Units','pixels','Position',[930 440 350 285],'Visible','off');
h.btnCalc = uicontrol('Parent',fig,'Style','pushbutton','Position',[920 390 370 32],...
    'String','Recompute preview','Callback',@(~,~)cbRecompute(fig));
h.btnSend = uicontrol('Parent',fig,'Style','pushbutton','Position',[920 350 370 32],...
    'String','Send shown pattern to projector','Callback',@(~,~)cbSend(fig));
h.btnSave = uicontrol('Parent',fig,'Style','pushbutton','Position',[920 310 370 32],...
    'String','Save to rig + reload projector','Callback',@(~,~)cbSave(fig));
h.btnV3 = uicontrol('Parent',fig,'Style','pushbutton','Position',[920 270 370 32],...
    'String','Write values into v3 script','Callback',@(~,~)cbWriteV3(fig));
end

%% ---- state and small helpers -----------------------------------------------

function S = getS(fig)
S = getappdata(fig,'S');
end

function putS(fig,S)
setappdata(fig,'S',S);
end

function setStatus(fig,msg)
S = getS(fig);
set(S.h.status,'String',msg);
end

function s = fmt(x)
if isnan(x), s = ''; else s = sprintf('%.10g',x); end
end

function v = value(S,k)
v = str2double(strtrim(get(S.h.ed(k),'String')));
end

function v = allVals(S)
v = struct();
for j = 1:S.nP, v.(S.spec(j).key) = value(S,j); end
end

function name = patName(S)
pats = get(S.h.ddPat,'String');
name = pats{get(S.h.ddPat,'Value')};
end

function colorField(S,k)
s0 = S.res.saved.(S.spec(k).key); v = value(S,k);
same = (isnan(v) && isnan(s0)) || (~isnan(v) && ~isnan(s0) && abs(v-s0) < 1e-12);
if same, c = [1 1 1]; else c = [1 0.85 0.55]; end
set(S.h.ed(k),'BackgroundColor',c);
end

function showSaved(S,k)
s0 = S.res.saved.(S.spec(k).key);
if isnan(s0)
    t = 'last saved: none';
else
    t = ['last saved: ' fmt(s0) '  (' S.res.source.(S.spec(k).key) ')'];
end
set(S.h.sv(k),'String',t);
end

function markDirty(fig)
S = getS(fig);
S.dirty = true; putS(fig,S);
updateEnable(fig);
end

function updateEnable(fig)
S = getS(fig);
ready = ~any(structfun(@isnan,allVals(S)));
if ready, en = 'on'; else en = 'off'; end
set([S.h.btnCalc S.h.btnSend S.h.btnSave S.h.btnV3],'Enable',en);
if ~ready
    setStatus(fig,'Blank values must be filled in before computing, sending or saving.');
end
end

function tf = confirm(msg,okLabel)
a = questdlg(regexp(msg,'\n','split'),'Confirm',okLabel,'Cancel','Cancel');
tf = strcmp(a,okLabel);
end

%% ---- loading ---------------------------------------------------------------

function initPezList(fig)
S = getS(fig);
try
    S.vd = get(S.h.edDir,'String');
    S.pezs = calibRigIO('pezList',S.vd);
    set(S.h.ddPez,'String',{S.pezs.name},'Value',1);
    putS(fig,S);
    loadPez(fig);
catch err
    setStatus(fig,['Cannot read rig folder: ' err.message]);
end
end

function loadPez(fig)
S = getS(fig);
if isempty(S.pezs), return, end
names = get(S.h.ddPez,'String');
S.cur = names{get(S.h.ddPez,'Value')};
S.ip = S.pezs(strcmp({S.pezs.name},S.cur)).ip;
S.res = calibRigIO('load',S.vd,S.cur);
S.out = []; S.dirty = true; S.awake = false;
putS(fig,S);
for j = 1:S.nP
    set(S.h.ed(j),'String',fmt(S.res.vals.(S.spec(j).key)));
    showSaved(S,j); colorField(S,j);
end
updateEnable(fig);
msg = sprintf('%s loaded. Projector computer %s.',S.cur,S.ip);
if S.res.paramsNewerThanVars
    msg = [msg ' WARNING: the rig params file is newer than the applied stimuliVars,' ...
        ' so these values may be a preview, not what is applied.'];
end
setStatus(fig,msg);
end

function cbBrowse(fig)
S = getS(fig);
d = uigetdir(S.vd,'Select pez3000_variables folder');
if ~isequal(d,0), set(S.h.edDir,'String',d); initPezList(fig); end
end

%% ---- editing and scrolling -------------------------------------------------

function cbEdited(fig,k)
S = getS(fig);
t = strtrim(get(S.h.ed(k),'String'));
if ~isempty(t) && isnan(str2double(t))
    errordlg('Enter a number (or leave blank).','Invalid value');
    set(S.h.ed(k),'String',fmt(S.res.saved.(S.spec(k).key)));
end
colorField(S,k); markDirty(fig);
end

function cbNudge(fig,k,dirn)
S = getS(fig);
v = value(S,k);
if isnan(v), errordlg('Type a starting value first.','No value'); return, end
set(S.h.ed(k),'String',fmt(v + dirn*S.spec(k).step));
colorField(S,k); markDirty(fig);
end

function cbRevert(fig,k)
S = getS(fig);
set(S.h.ed(k),'String',fmt(S.res.saved.(S.spec(k).key)));
colorField(S,k); markDirty(fig);
end

function cbScroll(fig)
S = getS(fig);
moveInner(S,get(S.h.slider,'Value'));
end

function cbWheel(fig,evt)
S = getS(fig);
v = get(S.h.slider,'Value') - 60*evt.VerticalScrollCount;
v = min(max(v,0),S.scrollMax);
set(S.h.slider,'Value',v);
moveInner(S,v);
end

function moveInner(S,v)
% Slider value S.scrollMax = top of the list, 0 = bottom.
p = get(S.h.inner,'Position');
p(2) = S.viewH - S.innerH + (S.scrollMax - v);
set(S.h.inner,'Position',p);
end

%% ---- compute, preview, send, save -----------------------------------------

function cbRecompute(fig)
recompute(fig);
end

function recompute(fig)
S = getS(fig);
set(fig,'Pointer','watch');
restore = onCleanup(@()set(fig,'Pointer','arrow')); %#ok<NASGU>
setStatus(fig,'Computing geometry, brightness and images - this can take a minute...');
drawnow;
try
    v = allVals(S); p = calibRigIO('toParams',v);
    g = calibGeometry(p);
    bb = calibBrightness(g,S.vd);
    im = calibImages(g,bb);
    S.out = struct('p',p,'g',g,'b',bb,'im',im,'vals',v); S.dirty = false;
    putS(fig,S);
    showPreview(fig); setStatus(fig,'Preview updated.');
catch err
    errordlg(err.message,'Compute failed');
end
end

function [ok,S] = ensureFresh(fig)
S = getS(fig);
if S.dirty || isempty(S.out), recompute(fig); S = getS(fig); end
ok = ~S.dirty && ~isempty(S.out);
end

function img = patternImage(S)
switch patName(S)
    case 'Crosshairs',        img = S.out.im.crosshairsIm;
    case '10-cm lines',       img = S.out.im.tenCmIm;
    case 'Transition ring',   img = S.out.im.transitionIm;
    case 'Blended ring',      img = S.out.im.calibImB;
    otherwise,                img = S.out.b.gainMatrixBrighter;
end
end

function showPreview(fig)
S = getS(fig);
if isempty(S.out), return, end
image(patternImage(S),'Parent',S.h.ax);
axis(S.h.ax,'image'); axis(S.h.ax,'off');
if S.dirty, t = 'Preview is out of date'; else t = patName(S); end
title(S.h.ax,t);
end

function wakeIfNeeded(fig)
S = getS(fig);
if ~S.awake
    calibProjectorLink('wake',S.ip);
    S.awake = true; putS(fig,S);
end
end

function cbSend(fig)
[ok,S] = ensureFresh(fig);
if ~ok, return, end
pat = patName(S);
if ~confirm(sprintf('Send "%s" to %s (%s)?\nThis overwrites %s_im2show.tif only.',...
        pat,S.cur,S.ip,S.cur),'Send'), return, end
try
    imwrite(patternImage(S),fullfile(S.vd,[S.cur '_im2show.tif']));
    wakeIfNeeded(fig); calibProjectorLink('show',S.ip);
    setStatus(fig,['Sent "' pat '" to ' S.cur '. Rig calibration files unchanged.']);
catch err
    errordlg(err.message,'Send failed');
end
end

function cbSave(fig)
[ok,S] = ensureFresh(fig);
if ~ok, return, end
if ~confirm(sprintf(['Save to the rig for %s?\nOverwrites %s_stimuliVars.mat, _stimuliParams.mat and _im2show.tif ' ...
        '(old copies go to calibGUI_backups), writes %s_calibGUIparams.mat, then tells the projector to reload.'],...
        S.cur,S.cur,S.cur),'Save'), return, end
try
    calibRigIO('saveRig',S.vd,S.cur,S.out.p,S.out.g,S.out.b,S.out.im);
    calibRigIO('saveGui',S.vd,S.cur,S.out.vals);
    S.res = calibRigIO('load',S.vd,S.cur);
    putS(fig,S);
    for j = 1:S.nP, showSaved(S,j); colorField(S,j); end
catch err
    errordlg(err.message,'Save failed'); return
end
try
    wakeIfNeeded(fig); calibProjectorLink('reload',S.ip); calibProjectorLink('show',S.ip);
    setStatus(fig,['Saved all 14 values for ' S.cur ' and sent reload + display.']);
catch err
    setStatus(fig,['Saved, but the projector reload failed: ' err.message]);
end
end

function cbWriteV3(fig)
S = getS(fig);
if ~confirm(sprintf(['Write these 14 values into case ''%s'' of projectorCalibration3000_v3.m?\n' ...
        'A timestamped backup of the script is made first.'],S.cur),'Write'), return, end
try
    r = calibPatchV3(S.v3Path,S.cur,allVals(S));
    if r.ok
        setStatus(fig,sprintf(['v3 updated and read back OK (backup: %s). To finish, run v3 with calibrateOp = 5 on %s''s ' ...
            'control computer, then testCalibEquivalence(''%s'').'],r.backup,S.cur,S.cur));
    else
        errordlg(sprintf('Missing: %s\nMismatch: %s\nRestore from %s',...
            strjoin(r.missing,', '),strjoin(r.mismatch,', '),r.backup),'v3 update incomplete');
    end
catch err
    errordlg(err.message,'v3 update failed');
end
end
