function projectorCalibrationGUI
%PROJECTORCALIBRATIONGUI Manual projector calibration editor.
%   Pick a pez, edit any value in any order, preview the pattern, send it to
%   the projector, then save to the rig. Values load from the rig's
%   pezNNNN_stimuliParams.mat (8 of 14) and from this GUI's own params file
%   (all 14, written on every save). Values that were never saved start blank.
%   Nothing is sent or written until you press a button and confirm.
%   Needs MATLAB R2022; uses the maths in calibGeometry/Brightness/Images,
%   which is copied from projectorCalibration3000_v3.m.
spec = calibParamSpec();
nP = numel(spec);
vd = calibRigIO('defaultDir');
v3Path = fullfile(fileparts(mfilename('fullpath')),'..','projectorCalibration3000_v3.m');
pezs = []; cur = ''; ip = ''; res = []; out = []; dirty = true; awake = false;
ed = gobjects(1,nP); sv = gobjects(1,nP);

fig = uifigure('Name','Projector calibration (manual)','Position',[40 40 1300 820]);
main = uigridlayout(fig,[3 2]);
main.RowHeight = {34,'1x',44}; main.ColumnWidth = {'1.5x','1x'};
bar = uigridlayout(main,[1 5]);
bar.Layout.Row = 1; bar.Layout.Column = [1 2]; bar.Padding = [0 0 0 0];
bar.ColumnWidth = {40,110,'1x',90,120};
uilabel(bar,'Text','Pez:');
ddPez = uidropdown(bar,'Items',{'(none)'},'ValueChangedFcn',@(~,~)loadPez());
edDir = uieditfield(bar,'text','Value',vd,'Tooltip','Rig folder (pez3000_variables)',...
    'ValueChangedFcn',@(~,~)initPezList());
uibutton(bar,'Text','Browse...','ButtonPushedFcn',@(~,~)browse());
uibutton(bar,'Text','Reload from rig','ButtonPushedFcn',@(~,~)loadPez());

rows = uigridlayout(main,[nP 2]);
rows.Layout.Row = 2; rows.Layout.Column = 1; rows.Scrollable = 'on';
rows.RowHeight = repmat({112},1,nP); rows.ColumnWidth = {'1x',270};
for k = 1:nP
    s = spec(k);
    tg = uigridlayout(rows,[2 1]);
    tg.Layout.Row = k; tg.Layout.Column = 1; tg.RowHeight = {20,'1x'}; tg.Padding = [4 2 4 2];
    u = ''; if ~isempty(s.units), u = ['  (' s.units ')']; end
    nm = uilabel(tg,'Text',[s.key u '    [step ' s.group ']'],'FontWeight','bold');
    nm.Layout.Row = 1; %#ok<NASGU>
    ds = uilabel(tg,'WordWrap','on','VerticalAlignment','top','Interpreter','none',...
        'Text',{s.desc,['Increase: ' s.up],['Decrease: ' s.down]});
    ds.Layout.Row = 2; %#ok<NASGU>
    c = uigridlayout(rows,[3 3]);
    c.Layout.Row = k; c.Layout.Column = 2; c.Padding = [0 2 0 2];
    c.ColumnWidth = {'1x',28,28}; c.RowHeight = {26,'1x',24};
    ed(k) = uieditfield(c,'text','ValueChangedFcn',@(~,~)edited(k));
    uibutton(c,'Text','+','ButtonPushedFcn',@(~,~)nudge(k,1));
    uibutton(c,'Text','-','ButtonPushedFcn',@(~,~)nudge(k,-1));
    sv(k) = uilabel(c,'WordWrap','on','FontSize',10,'VerticalAlignment','top');
    sv(k).Layout.Row = 2; sv(k).Layout.Column = [1 3];
    rv = uibutton(c,'Text','Revert to last saved','ButtonPushedFcn',@(~,~)revert(k));
    rv.Layout.Row = 3; rv.Layout.Column = [1 3];
end

rg = uigridlayout(main,[6 1]);
rg.Layout.Row = 2; rg.Layout.Column = 2;
rg.RowHeight = {28,'1x',32,32,32,32};
ddPat = uidropdown(rg,'Items',{'Crosshairs','10-cm lines','Transition ring',...
    'Blended ring','White background'},'ValueChangedFcn',@(~,~)preview());
ax = uiaxes(rg); axis(ax,'off');
btnCalc = uibutton(rg,'Text','Recompute preview','ButtonPushedFcn',@(~,~)recompute());
btnSend = uibutton(rg,'Text','Send shown pattern to projector','ButtonPushedFcn',@(~,~)sendPattern());
btnSave = uibutton(rg,'Text','Save to rig + reload projector','ButtonPushedFcn',@(~,~)saveReload());
btnV3 = uibutton(rg,'Text','Write values into v3 script','ButtonPushedFcn',@(~,~)writeV3());
status = uilabel(main,'Text','','WordWrap','on');
status.Layout.Row = 3; status.Layout.Column = [1 2];
initPezList();

    function initPezList
        try
            vd = edDir.Value;
            pezs = calibRigIO('pezList',vd);
            ddPez.Items = {pezs.name};
            loadPez();
        catch err
            setStatus(['Cannot read rig folder: ' err.message]);
        end
    end

    function loadPez
        cur = ddPez.Value;
        ip = pezs(strcmp({pezs.name},cur)).ip;
        res = calibRigIO('load',vd,cur);
        for j = 1:nP
            ed(j).Value = fmt(res.vals.(spec(j).key));
            showSaved(j); colorField(j);
        end
        out = []; dirty = true; awake = false; refresh();
        msg = sprintf('%s loaded. Projector computer %s.',cur,ip);
        if res.paramsNewerThanVars
            msg = [msg ' WARNING: the rig params file is newer than the applied stimuliVars,' ...
                ' so these values may be a preview, not what is applied.'];
        end
        setStatus(msg);
    end

    function browse
        d = uigetdir(vd,'Select pez3000_variables folder');
        if ~isequal(d,0), edDir.Value = d; initPezList(); end
    end

    function edited(k)
        t = strtrim(ed(k).Value);
        if ~isempty(t) && isnan(str2double(t))
            uialert(fig,'Enter a number (or leave blank).','Invalid value');
            ed(k).Value = fmt(res.saved.(spec(k).key));
        end
        colorField(k); dirty = true; refresh();
    end

    function nudge(k,dirn)
        v = value(k);
        if isnan(v), uialert(fig,'Type a starting value first.','No value'); return, end
        ed(k).Value = fmt(v + dirn*spec(k).step);
        colorField(k); dirty = true; refresh();
    end

    function revert(k)
        ed(k).Value = fmt(res.saved.(spec(k).key));
        colorField(k); dirty = true; refresh();
    end

    function v = value(k)
        v = str2double(strtrim(ed(k).Value));
    end

    function v = vals
        v = struct();
        for j = 1:nP, v.(spec(j).key) = value(j); end
    end

    function colorField(k)
        s0 = res.saved.(spec(k).key); v = value(k);
        same = (isnan(v) && isnan(s0)) || (~isnan(v) && ~isnan(s0) && abs(v-s0) < 1e-12);
        if same, ed(k).BackgroundColor = [1 1 1]; else, ed(k).BackgroundColor = [1 0.85 0.55]; end
    end

    function showSaved(k)
        s0 = res.saved.(spec(k).key);
        if isnan(s0), sv(k).Text = 'last saved: none';
        else, sv(k).Text = ['last saved: ' fmt(s0) '  (' res.source.(spec(k).key) ')']; end
    end

    function refresh
        v = vals; ready = ~any(structfun(@isnan,v));
        for b = [btnCalc btnSend btnSave btnV3]
            if ready, b.Enable = 'on'; else, b.Enable = 'off'; end
        end
        if ~ready, setStatus('Blank values must be filled in before computing, sending or saving.'); end
    end

    function recompute
        try
            v = vals; p = calibRigIO('toParams',v);
            dlg = uiprogressdlg(fig,'Title','Computing','Indeterminate','on',...
                'Message','Geometry, brightness and images - this can take a minute.');
            cl = onCleanup(@() close(dlg));
            g = calibGeometry(p);
            bb = calibBrightness(g,vd);
            im = calibImages(g,bb);
            out = struct('p',p,'g',g,'b',bb,'im',im,'vals',v); dirty = false;
            preview(); setStatus('Preview updated.');
        catch err
            uialert(fig,err.message,'Compute failed');
        end
    end

    function ok = ensureFresh
        if dirty || isempty(out), recompute(); end
        ok = ~dirty && ~isempty(out);
    end

    function img = patternImage
        switch ddPat.Value
            case 'Crosshairs',        img = out.im.crosshairsIm;
            case '10-cm lines',       img = out.im.tenCmIm;
            case 'Transition ring',   img = out.im.transitionIm;
            case 'Blended ring',      img = out.im.calibImB;
            otherwise,                img = out.b.gainMatrixBrighter;
        end
    end

    function preview
        if isempty(out), return, end
        image(ax,patternImage()); axis(ax,'image'); axis(ax,'off');
        if dirty, title(ax,'Preview is out of date'); else, title(ax,ddPat.Value); end
    end

    function tf = confirm(msg,okLabel)
        a = uiconfirm(fig,msg,'Confirm','Options',{okLabel,'Cancel'},...
            'DefaultOption',2,'CancelOption',2,'Icon','warning');
        tf = strcmp(a,okLabel);
    end

    function wakeIfNeeded
        if ~awake, calibProjectorLink('wake',ip); awake = true; end
    end

    function sendPattern
        if ~ensureFresh(), return, end
        if ~confirm(sprintf('Send "%s" to %s (%s)?\nThis overwrites %s_im2show.tif only.',...
                ddPat.Value,cur,ip,cur),'Send'), return, end
        try
            imwrite(patternImage(),fullfile(vd,[cur '_im2show.tif']));
            wakeIfNeeded(); calibProjectorLink('show',ip);
            setStatus(['Sent "' ddPat.Value '" to ' cur '. Rig calibration files unchanged.']);
        catch err
            uialert(fig,err.message,'Send failed');
        end
    end

    function saveReload
        if ~ensureFresh(), return, end
        if ~confirm(sprintf(['Save to the rig for %s?\nOverwrites %s_stimuliVars.mat, _stimuliParams.mat and _im2show.tif ' ...
                '(old copies go to calibGUI_backups), writes %s_calibGUIparams.mat, then tells the projector to reload.'],...
                cur,cur,cur),'Save'), return, end
        try
            calibRigIO('saveRig',vd,cur,out.p,out.g,out.b,out.im);
            calibRigIO('saveGui',vd,cur,out.vals);
            res = calibRigIO('load',vd,cur);
            for j = 1:nP, showSaved(j); colorField(j); end
        catch err
            uialert(fig,err.message,'Save failed'); return
        end
        try
            wakeIfNeeded(); calibProjectorLink('reload',ip); calibProjectorLink('show',ip);
            setStatus(['Saved all 14 values for ' cur ' and sent reload + display.']);
        catch err
            setStatus(['Saved, but the projector reload failed: ' err.message]);
        end
    end

    function writeV3
        if ~confirm(sprintf(['Write these 14 values into case ''%s'' of projectorCalibration3000_v3.m?\n' ...
                'A timestamped backup of the script is made first.'],cur),'Write'), return, end
        try
            r = calibPatchV3(v3Path,cur,vals());
            if r.ok
                setStatus(sprintf(['v3 updated and read back OK (backup: %s). To finish, run v3 with calibrateOp = 5 on %s''s ' ...
                    'control computer, then testCalibEquivalence(''%s'').'],r.backup,cur,cur));
            else
                uialert(fig,sprintf('Missing: %s\nMismatch: %s\nRestore from %s',...
                    strjoin(r.missing,', '),strjoin(r.mismatch,', '),r.backup),'v3 update incomplete');
            end
        catch err
            uialert(fig,err.message,'v3 update failed');
        end
    end

    function setStatus(msg)
        status.Text = msg;
    end
end

function s = fmt(x)
if isnan(x), s = ''; else, s = sprintf('%.10g',x); end
end
