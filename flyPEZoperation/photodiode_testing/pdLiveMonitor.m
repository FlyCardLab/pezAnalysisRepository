function pdLiveMonitor(varargin)
%pdLiveMonitor Live photodiode readout for bench-testing a replacement sensor.
%   Opens a continuous, internally clocked acquisition on the rig's NI DAQ
%   and live-plots the photodiode channel alongside the numbers that
%   distinguish a slow sensor from a dim one from a bad acquisition path.
%   Buttons drive the stimulus computer over the existing UDP protocol so
%   you can put known light on the sensor on demand.
%
%   pdLiveMonitor
%   pdLiveMonitor('Rate',50000,'Channels',{'ai0','ai15','ai10'})
%
%Name/value arguments:
%   'Rate'      per-channel scan rate, Hz (default 50000)
%   'Channels'  cell array of AI channels (default {'ai0'}).  Pass
%               {'ai0','ai15','ai10'} to reproduce production's three-channel
%               multiplexing -- see "THE MUX TEST" below.
%   'Range'     explicit [lo hi] in volts, default [-10 10].  Deliberately
%               wide: see "THE 5 V RAIL" below.  Pass 'auto' to probe and
%               pick the narrowest fitting range instead.
%   'Repeats'   how many back-to-back presentations per Flicker press,
%               default 1.  Raise it only if the stimulus computer is
%               presenting reliably; each repeat is captured separately with
%               its own dark lead-in and the metrics become medians across
%               them, with the spread shown.
%   'InitMode'  'transforming' (default) or 'standard'.  Picks which half
%               of the measurement this session can do -- see below.
%   'SensorRail' voltage the sensor saturates at, default 5 (its supply).
%               Only used to label clipping in the readout, never to alter
%               the data.
%   'FlickerHz' expected optical square-wave rate (default 180, see below)
%   'Window'    seconds of trace on screen (default 0.5)
%   'CamRate'   camera frame rate to simulate in the verdict (default 6000)
%   'StimFile'  stimulus .mat to present for the flicker test.  Default is
%               the longest constSize_*.mat found in visual_stimuli.
%   'NoUDP'     true to never talk to the stimulus computer (default false)
%   'DevID'     override the NIDAQ device, e.g. 'Dev1'
%   'HostIP'    override the stimulus computer IP
%
%RUN THIS WITH runPezControl OPEN BUT NOT COUPLED TO THE CAMERA.
%The GUI's DAQ task takes the device when you couple; a second task on the
%same device will be refused.  Stop this monitor before coupling.
%
%WHAT THE SENSOR ACTUALLY HAS TO SEE.  The photodiode does not watch the
%looming disk.  It watches a 35x35 px reference patch in a corner of the
%projected image.  The projector runs at 120 Hz and the DLP shows R,G,B
%sequentially, so sub-frames land on a 360 Hz grid -- but the patch
%alternates on every sub-frame (initializeFramesFromFileUDP.m:228-257), so
%the optical signal is a 50% duty square wave at 180 Hz, 2.78 ms per state,
%swinging between levels 255 and 10 (never fully dark).
%
%READING THE NUMBERS.  In 'transforming' mode press Init then Flicker; the
%cycle-average plot and fc-from-rise answer the bandwidth question on their
%own.  In 'standard' mode press Init, White, then Dark to latch the DC
%swing.  With both halves in hand:
%   both fc estimates agree and are low (<~500 Hz) -> BANDWIDTH LIMITED
%   fc fine but dcSwing small vs a working rig      -> LIGHT LEVEL / RESPONSIVITY
%   single channel fine but the mux test much worse -> ACQUISITION CHAIN
%
%YOU CANNOT DO BOTH HALVES IN ONE SESSION.  The listener keeps two pieces
%of state and each command needs a different one:
%   command 0 ("transforming") -> stimStruct,     needed by 3/4 = Flicker
%   command 5 ("standard")     -> stimTrigStruct, needed by 9/10 = White/Dark
%They are mutually destructive: each opens its own Psychtoolbox window, and
%opening a window invalidates every texture and proxy handle from the
%previous one.  Send a 5 after a 0 and stimStruct.warpoperator is left
%dangling, so Flicker dies with "'transformProxyPtr' argument must be a
%handle to a proxy object", returns a partial struct, and everything after
%it fails with "Invalid Window (or Texture) Index".
%
%So the buttons this session cannot drive are greyed out, and the sequence
%is: run one mode, then Reset stim (86) and restart in the other.
%
%For the bandwidth question you only need the default 'transforming' mode.
%Rise time and fc-from-rise come from the flicker's own cycle average and
%do not need White/Dark at all.  'standard' is only for the DC swing, which
%feeds acPkPk/dcSwing and fc-from-attenuation.
%
%THE 5 V RAIL.  A phototransistor module run off 5 V saturates at its
%supply, and a full-screen white frame is far brighter than the 35x35 px
%reference patch, so White will peg it at a dead-flat 5.000 V while the
%patch flicker is only a few hundred mV.  That matters because dcSwing is
%measured from White: if White clipped, dcSwing is understated, and both
%acPkPk/dcSwing and fc-from-attenuation come out wrong.  The readout
%detects this and suppresses those two numbers rather than printing a
%confident wrong answer.
%
%The default range is therefore deliberately wide (+/-10 V) rather than
%auto-probed.  A narrow range makes the DAQ clip at its own ceiling, which
%is indistinguishable in the trace from the sensor railing -- and those two
%have completely different fixes.  With headroom, flat-topping at 5.000 V
%can only be the sensor.  Resolution is not the constraint: a 0.5 V flicker
%on a +/-10 V range is still ~1600 codes on a 16-bit board.
%
%THE MUX TEST.  Production acquires ai0, ai15 and ai10 at nRate*10 scans/s
%(runPezControl_v13.m:3730) -- 60000 scans/s at 6000 fps, so the ADC
%multiplexes at ~180 kS/s, about 5.5 us per channel.  A phototransistor
%with a large load resistor has a source impedance far above NI's ~10 kOhm
%guidance for multiplexed sampling, and the sample-and-hold never settles.
%That reads out as a small, ghosted signal from a sensor that is actually
%fine.  If the flicker amplitude drops sharply when you add the other two
%channels, lower the load resistor or buffer the sensor with a unity-gain
%op-amp before concluding anything about the sensor itself.
%
%TWO THINGS TO KNOW ABOUT SHARING THE RIG.
%   1. judp('receive') binds UDP port 21566 for the duration of the call.
%      Do not press the stimulus buttons while the GUI is mid-trial.
%   2. The Flicker button sends command 3, which overwrites whatever
%      stimulus the GUI has loaded on the stimulus computer.  RELOAD THE
%      GUI'S STIMULUS before resuming real experiments.
%
%See also pdVerdict

%% Arguments
p = inputParser;
addParameter(p,'Rate',50000);
addParameter(p,'Channels',{'ai0'});
addParameter(p,'Range',[-10 10]);
addParameter(p,'SensorRail',5);
addParameter(p,'InitMode','transforming');
addParameter(p,'Repeats',1);
addParameter(p,'FlickerHz',180);
addParameter(p,'Window',0.5);
addParameter(p,'CamRate',6000);
addParameter(p,'StimFile','');
addParameter(p,'NoUDP',false);
addParameter(p,'DevID','');
addParameter(p,'HostIP','');
parse(p,varargin{:});
opt = p.Results;
if ischar(opt.Channels)
    opt.Channels = {opt.Channels};
end
nCh = numel(opt.Channels);
useUDP = ~opt.NoUDP;

if isempty(which('daq.createSession'))
    error('pdLiveMonitor:noSessionAPI',...
        ['daq.createSession is not available in this MATLAB (it was removed '...
        'in R2022b).  The rig code uses the session-based interface '...
        'throughout, so run this on the rig''s MATLAB.'])
end

%% Rig identity
cfg = resolveRig(opt);
fprintf('pdLiveMonitor: %s, device %s',cfg.pezName,cfg.devID);
if useUDP
    fprintf(', stimulus computer %s\n',cfg.hostIP);
else
    fprintf(' (UDP disabled)\n');
end

%% State shared with the nested functions
sIn = [];
lh = [];
hTimer = [];
bufData = [];
bufFilled = 0;
capBuf = [];
capFilled = 0;
capTarget = 0;
capturing = false;
latched = emptyLatched();
stimInitMode = 'none';
stopFlag = false;
hFig = [];
hTrace = [];
hCycle = [];
hCycleLo = [];
hCycleHi = [];
hText = [];
hStatus = [];
axTrace = [];
axCycle = [];
info = struct;

%Cleanup is called explicitly rather than through onCleanup: onCleanup runs
%its callback as the workspace is being torn down, and a nested function
%that touches uplevel variables (the session, the timer) is not valid there.
try
    openSession();
    bufLen = max(round(opt.Window*info.actualRate),100);
    bufData = zeros(bufLen,nCh);

    buildFigure();
    lh = sIn.addlistener('DataAvailable',@ingest);
    sIn.startBackground();

    hTimer = timer('ExecutionMode','fixedSpacing','Period',0.2,...
        'TimerFcn',@(~,~) safeRefresh(),'BusyMode','drop');
    start(hTimer)

    while ~stopFlag && ishandle(hFig)
        pause(0.1)
    end
catch ME
    cleanupAll();
    rethrow(ME)
end
cleanupAll();

%% ---------------------------------------------------------------- nested

    function openSession()
        try
            sIn = daq.createSession('ni');
        catch ME
            error('pdLiveMonitor:noSession',...
                'Could not create a DAQ session: %s',ME.message)
        end
        for iterC = 1:nCh
            ch = sIn.addAnalogInputChannel(cfg.devID,opt.Channels{iterC},'Voltage');
            ch.InputType = 'SingleEnded';
        end
        %Deliberately NO addClockConnection here.  initializeDiodeNidaq.m
        %clocks the production session off the camera's SYNC on PFI2, which
        %means it will not sample at all unless the Photron is running --
        %exactly what makes it useless on the bench.
        sIn.IsContinuous = true;

        info.rangesAvailable = availableRanges(cfg.devID);
        setRange(opt.Range);
        negotiateRate(opt.Rate);

        sIn.NotifyWhenDataAvailableExceeds = max(round(info.actualRate/20),10);
        try
            prepare(sIn)
        catch ME
            if ~isempty(strfind(lower(ME.message),'reserv')) ||...
                    ~isempty(strfind(lower(ME.message),'in use'))
                error('pdLiveMonitor:deviceReserved',...
                    ['Device %s is reserved by another task.  Uncouple '...
                    'runPezControl from the camera (or close it) and try '...
                    'again.\nOriginal error: %s'],cfg.devID,ME.message)
            end
            rethrow(ME)
        end
    end

    function setRange(wanted)
        if ischar(wanted) && strcmpi(wanted,'auto')
            %Probe with the projector at full white.  Auto-ranging on a dark
            %trace picks a range that the white condition then clips.
            if useUDP && strcmp(opt.InitMode,'standard')
                ensureStimInit('standard');
                sendUDP(9);
                pause(0.3)
            end
            widest = widestRange();
            applyRange(widest);
            probe = quickRead(0.25);
            lo = min(probe(:,1));
            hi = max(probe(:,1));
            pad = max(0.25*(hi-lo),0.01);
            applyRange(narrowestContaining([lo-pad hi+pad]));
            if useUDP
                sendUDP(10);
            end
        else
            applyRange(narrowestContaining(wanted));
        end
        %Reading Range back gives a daq.Range OBJECT, not the [lo hi] pair
        %that was assigned.  Indexing it as a vector throws "Index exceeds
        %matrix dimensions" from whichever callback touches it first.
        info.actualRange = rangeToVector(sIn.Channels(1).Range);
    end

    function applyRange(r)
        for iterC = 1:nCh
            try
                sIn.Channels(iterC).Range = r;
            catch
                %NI coerces or refuses; leave the channel at its default and
                %report whatever it actually ended up with.
            end
        end
    end

    function r = widestRange()
        allR = info.rangesAvailable;
        if isempty(allR)
            r = [];
            return
        end
        spans = arrayfun(@(x) x.Max-x.Min,allR);
        [~,ndx] = max(spans);
        r = [allR(ndx).Min allR(ndx).Max];
    end

    function r = narrowestContaining(want)
        allR = info.rangesAvailable;
        if isempty(allR) || isempty(want)
            r = want;
            return
        end
        spans = arrayfun(@(x) x.Max-x.Min,allR);
        [spans,order] = sort(spans);
        allR = allR(order);
        for iterR = 1:numel(allR)
            if allR(iterR).Min <= want(1) && allR(iterR).Max >= want(2)
                r = [allR(iterR).Min allR(iterR).Max];
                return
            end
        end
        r = [allR(end).Min allR(end).Max];%nothing fits; take the widest
        warning('pdLiveMonitor:rangeClip',...
            ['Signal spans %.3f to %.3f V, wider than any available input '...
            'range.  Using +/-%.3f V; expect clipping.'],want(1),want(2),spans(end)/2)
    end

    function negotiateRate(wanted)
        info.requestedRate = wanted;
        candidates = [wanted,200e3/nCh,100e3/nCh,50e3/nCh,20e3/nCh,10e3/nCh,5e3/nCh];
        for iterR = 1:numel(candidates)
            try
                sIn.Rate = candidates(iterR);
                info.actualRate = sIn.Rate;%NI coerces to a timebase divisor
                if iterR > 1
                    warning('pdLiveMonitor:rateReduced',...
                        ['Board would not accept %g scans/s on %d channel(s); '...
                        'running at %g instead.'],wanted,nCh,info.actualRate)
                end
                return
            catch
                continue
            end
        end
        error('pdLiveMonitor:noRate',...
            'Board accepted none of the candidate scan rates on %d channel(s).',nCh)
    end

    function d = quickRead(durSec)
        %Short blocking read used only during auto-ranging, before the
        %continuous session and its listener are running.
        wasCont = sIn.IsContinuous;
        sIn.IsContinuous = false;
        sIn.DurationInSeconds = durSec;
        d = sIn.startForeground();
        sIn.IsContinuous = wasCont;
    end

    function ingest(~,event)
        newData = event.Data;
        n = size(newData,1);
        if n >= size(bufData,1)
            bufData = newData(end-size(bufData,1)+1:end,:);
            bufFilled = size(bufData,1);
        else
            bufData = [bufData(n+1:end,:);newData];
            bufFilled = min(bufFilled+n,size(bufData,1));
        end
        if capturing
            room = capTarget-capFilled;
            take = min(n,room);
            capBuf(capFilled+1:capFilled+take,:) = newData(1:take,:);
            capFilled = capFilled+take;
            if capFilled >= capTarget
                capturing = false;
            end
        end
    end

    function d = capture(durSec)
        %Collect durSec of data while keeping the listener alive.
        capTarget = max(round(durSec*info.actualRate),1);
        capBuf = zeros(capTarget,nCh);
        capFilled = 0;
        capturing = true;
        t0 = tic;
        while capturing && toc(t0) < durSec+5 && ishandle(hFig)
            pause(0.02)
        end
        capturing = false;
        d = capBuf(1:capFilled,:);
    end

    function buildFigure()
        hFig = figure('Name',sprintf('pdLiveMonitor - %s (%s) - %s init',...
            cfg.pezName,cfg.devID,opt.InitMode),...
            'NumberTitle','off','Position',[80 80 1150 760],'Color',[1 1 1],...
            'CloseRequestFcn',@(~,~) requestStop());

        axTrace = axes('Parent',hFig,'Position',[0.06 0.60 0.90 0.32]);
        hTrace = plot(axTrace,NaN,NaN,'Color',[0 0.35 0.7]);
        xlabel(axTrace,'Time (ms)')
        ylabel(axTrace,'Photodiode (V)')
        title(axTrace,'Live trace (ai0)')
        grid(axTrace,'on')

        axCycle = axes('Parent',hFig,'Position',[0.06 0.09 0.34 0.40]);
        hCycle = plot(axCycle,NaN,NaN,'Color',[0.7 0.2 0],'LineWidth',1.5);
        hold(axCycle,'on')
        hCycleLo = plot(axCycle,NaN,NaN,'k:');
        hCycleHi = plot(axCycle,NaN,NaN,'k:');
        hold(axCycle,'off')
        xlabel(axCycle,'Time within one cycle (ms)')
        ylabel(axCycle,'Volts')
        title(axCycle,sprintf('Cycle average @ %g Hz (press Flicker)',opt.FlickerHz))
        grid(axCycle,'on')

        %A 'text' uicontrol clips silently -- anything past the bottom of the
        %box cannot be reached at all.  A listbox scrolls.  Min/Max and an
        %empty Value make it read-only in effect (nothing stays selected).
        hText = uicontrol('Parent',hFig,'Style','listbox','Units','normalized',...
            'Position',[0.44 0.07 0.52 0.44],'HorizontalAlignment','left',...
            'BackgroundColor',[1 1 1],'FontName','Courier New','FontSize',9,...
            'Min',0,'Max',2,'Value',[],'String',{''});

        btnW = 0.092;
        btnY = 0.955;
        mkButton(0.06,btnY,btnW,'Init',@(~,~) guardedUDP(@() doInit()),'udp');
        mkButton(0.160,btnY,btnW,'Dark (10)',@(~,~) guardedUDP(@() doDC(10,'dark')),'standard');
        mkButton(0.260,btnY,btnW,'White (9)',@(~,~) guardedUDP(@() doDC(9,'white')),'standard');
        mkButton(0.360,btnY,btnW,'Flicker',@(~,~) guardedUDP(@() doFlicker()),'transforming');
        mkButton(0.460,btnY,btnW,'Reset stim',@(~,~) guardedUDP(@() doReset()),'udp');
        mkButton(0.560,btnY,btnW,'Snapshot',@(~,~) doSnapshot(),'local');
        mkButton(0.660,btnY,btnW,'Clear nums',@(~,~) resetLatched(),'local');

        %Grey out whatever this session's init mode cannot drive, rather than
        %letting a press corrupt the stimulus computer's window state.
        if strcmp(opt.InitMode,'transforming')
            set(findobj(hFig,'Tag','standard'),'Enable','off')
        else
            set(findobj(hFig,'Tag','transforming'),'Enable','off')
        end

        hStatus = uicontrol('Parent',hFig,'Style','text','Units','normalized',...
            'Position',[0.755 btnY-0.004 0.20 0.030],'HorizontalAlignment','right',...
            'BackgroundColor',[1 1 1],'ForegroundColor',[0.3 0.3 0.3],'String','ready');

        if ~useUDP
            set(findobj(hFig,'Tag','udp'),'Enable','off')
            set(findobj(hFig,'Tag','standard'),'Enable','off')
            set(findobj(hFig,'Tag','transforming'),'Enable','off')
        end
    end

    function mkButton(x,y,w,str,cb,tag)
        %Interruptible off / BusyAction cancel: these handlers busy-wait on
        %pause() for seconds, and pause() runs the event queue.  Without this
        %a second button press re-enters a handler that is mid-capture.
        uicontrol('Parent',hFig,'Style','pushbutton','Units','normalized',...
            'Position',[x y w 0.033],'String',str,'Callback',cb,'Tag',tag,...
            'Interruptible','off','BusyAction','cancel');
    end

    function status(str)
        if ishandle(hStatus)
            set(hStatus,'String',str)
            drawnow
        end
    end

    function guardedUDP(fcn)
        %Take the refresh timer out of play for the duration.  These handlers
        %busy-wait on pause() for seconds at a time, and pause() lets the
        %event queue run -- so without this the timer re-enters refresh() and
        %reads latched/capBuf while they are mid-write, which surfaces as a
        %bare "Error using pause / Error while evaluating uicontrol Callback".
        timerWasOn = ~isempty(hTimer) && isvalid(hTimer) &&...
            strcmp(get(hTimer,'Running'),'on');
        if timerWasOn
            stop(hTimer)
        end
        setButtons('off')
        try
            fcn();
        catch ME
            capturing = false;%never leave ingest writing into a dead capture
            status('failed -- see command window')
            %The dialog truncates and drops the identifier, which is usually
            %the informative part, so print the full report as well.
            fprintf(2,'\npdLiveMonitor error:\n%s\n',...
                getReport(ME,'extended','hyperlinks','off'));
            warndlg(sprintf(['%s\n\n%s\n\nFull detail is in the command '...
                'window.  If the stimulus computer is at fault, check that '...
                'udpInitializationListener_v2 is running on %s.'],...
                ME.identifier,ME.message,cfg.hostIP),'pdLiveMonitor');
        end
        setButtons('on')
        if timerWasOn && ~isempty(hTimer) && isvalid(hTimer)
            start(hTimer)
        end
        safeRefresh();%never let a redraw failure escape as a raw callback error
    end

    function setButtons(state)
        if isempty(hFig) || ~ishandle(hFig)
            return
        end
        set(findobj(hFig,'Style','pushbutton'),'Enable',state)
        if strcmp(state,'off')
            return
        end
        %Re-enabling must not resurrect buttons this session cannot use.
        if strcmp(opt.InitMode,'transforming')
            set(findobj(hFig,'Tag','standard'),'Enable','off')
        else
            set(findobj(hFig,'Tag','transforming'),'Enable','off')
        end
        if ~useUDP
            set(findobj(hFig,'Tag','udp'),'Enable','off')
            set(findobj(hFig,'Tag','standard'),'Enable','off')
            set(findobj(hFig,'Tag','transforming'),'Enable','off')
        end
    end

    function ensureStimInit(mode)
        %ONE init mode per session, chosen by 'InitMode'.  Never switch.
        %
        %The listener holds two separate pieces of state:
        %   command 0 -> stimStruct     (warpmap, warpoperator, stimRefROI)
        %                needed by 3/4, the file-based stimuli
        %   command 5 -> stimTrigStruct (gainMatrix, window)
        %                needed by 9/10, the full-field frames
        %
        %They are not merely different, they destroy each other.  Each opens
        %its own Psychtoolbox window, and opening a window invalidates every
        %texture and proxy handle from the previous one.  So a 5 after a 0
        %leaves stimStruct.warpoperator dangling, and command 3 then dies with
        %"'transformProxyPtr' argument must be a handle to a proxy object",
        %returns a partial struct, and everything after it fails too.
        %
        %Hence: pick a mode, do that half of the measurement, and restart with
        %a reset in between if you need the other half.
        if ~strcmp(mode,opt.InitMode)
            error('pdLiveMonitor:wrongInitMode',...
                ['This action needs the "%s" init but the session was started '...
                'in "%s".\n\nThey cannot coexist: each opens its own PTB '...
                'window and invalidates the other''s texture handles.\n\n'...
                'Close this window, press Reset on the stimulus computer (or '...
                'send command 86), then run:\n'...
                '    pdLiveMonitor(''InitMode'',''%s'')'],...
                mode,opt.InitMode,mode)
        end
        if strcmp(stimInitMode,mode)
            return
        end
        switch mode
            case 'standard'
                code = 5;%full-field frames: 9, 10
            case 'transforming'
                code = 0;%file-based stimuli: 3 then 4
            otherwise
                error('pdLiveMonitor:badInitMode',...
                    'InitMode must be ''transforming'' or ''standard''.')
        end
        status(sprintf('initialising stimulus computer (%d)...',code))
        stimInitMode = 'none';
        sendUDP(code);
        reply = recvUDP(25000);
        if isempty(reply)
            error('pdLiveMonitor:initNoReply',...
                ['No reply to command %d after 25 s.  Is '...
                'udpInitializationListener_v2 running on %s?'],code,cfg.hostIP)
        end
        if strcmpi(reply,'error')
            error('pdLiveMonitor:initFailed',...
                ['Stimulus computer could not complete command %d.  It only '...
                'ever replies a bare "error"; THE REAL EXCEPTION IS PRINTED '...
                'ON ITS OWN COMMAND WINDOW -- look there.\n\nIf it says '...
                '"Unrecognized function or variable ''screenid''", the '...
                'projector is not being seen as a second display: '...
                'Screen(''Screens'') is returning one screen, so '...
                'initializeVisualStimulusGeneralUDP_brighter never finds a '...
                '1024- or 1280-wide one to draw on.  That is a display '...
                'problem on the stimulus computer, not something this tool '...
                'can fix -- check the projector is powered and that Windows '...
                'is extending rather than duplicating.'],code)
        end
        stimInitMode = mode;
    end

    function goDark()
        %Command 10 needs stimTrigStruct.gainMatrix, which only a standard
        %init creates.  Sending it under a transforming init throws "Dot
        %indexing is not supported" on the stimulus computer.
        %
        %Not sending it is fine: the sensor watches the 35x35 px reference
        %patch, not the dome, and that patch is already black at idle
        %(stimRefImageB in initializeFramesFromFileUDP).  So the lead-in is
        %dark where it matters either way.
        if strcmp(stimInitMode,'standard')
            sendUDP(10);
        end
    end

    function doReset()
        %Command 86 is sca + PsychStartup on the stimulus computer.  This is
        %the way out of a mangled window/texture state, and the log fills with
        %"Invalid Window (or Texture) Index" when you are in one.
        status('resetting stimulus computer...')
        sendUDP(86);
        pause(3)
        stimInitMode = 'none';
        status('stimulus computer reset -- press Init')
    end

    function doInit()
        stimInitMode = 'none';%force a fresh init, so this doubles as a comms check
        ensureStimInit(opt.InitMode);
        status(sprintf('stimulus computer ready (%s init)',opt.InitMode))
    end

    function doDC(code,which)
        ensureStimInit('standard');%9 and 10 need stimTrigStruct.gainMatrix
        status([which '...'])
        sendUDP(code);
        pause(0.4)%let the projector settle before measuring
        d = capture(0.5);
        if isempty(d)
            status('no data')
            return
        end
        lvl = mean(d(:,1));
        railFrac = mean(d(:,1) >= opt.SensorRail-0.005);
        daqFrac = clipFraction(d(:,1),info.actualRange);
        if strcmp(which,'dark')
            latched.dcDark = lvl;
            %A dark trace is the only place the noise floor can be measured
            %without the signal in it.
            latched.noiseFloor = chunkNoise(d(:,1),30);
            latched.darkTrace = d(:,1);
        else
            latched.dcWhite = lvl;
            latched.whiteTrace = d(:,1);
            %If White saturated, dcSwing is a lower bound, not a measurement.
            latched.whiteRailFrac = railFrac;
            latched.whiteDaqClipFrac = daqFrac;
            latched.whiteClipped = railFrac > 0.02 || daqFrac > 0.02;
        end
        if ~isnan(latched.dcDark) && ~isnan(latched.dcWhite)
            latched.dcSwing = latched.dcWhite-latched.dcDark;
        end
        status([which ' latched'])
    end

    function doFlicker()
        ensureStimInit('transforming');%3 and 4 need stimStruct
        stimFile = resolveStimFile();
        status('loading stimulus...')
        sendUDP([3 double(stimFile)]);
        reply = recvUDP(20000);
        durMs = str2double(reply);
        if isnan(durMs) || durMs <= 0
            if isempty(reply)
                %Polling can drop the reply.  Guess long rather than give up:
                %over-running the capture costs nothing but a few samples.
                durMs = 3000;
                status('no duration reply; assuming 3000 ms')
            else
                error('pdLiveMonitor:badDuration',...
                    ['Stimulus computer returned "%s" instead of a duration '...
                    'for %s.\n\nThe listener catches every exception and '...
                    'replies a bare "error", so THE REAL CAUSE IS PRINTED ON '...
                    'THE STIMULUS COMPUTER''S COMMAND WINDOW -- look there '...
                    'first.\n\nCommon causes: the file was built for a '...
                    'different rig (check pez5 = 0), or it is too large to '...
                    'hold in memory.'],reply,stimFile)
            end
        end
        latched.stimFile = stimFile;
        latched.stimDurationMs = durMs;

        %Load once, present Repeats times.  Each repeat is captured
        %separately with its own dark lead-in rather than as one long
        %recording, so every trace is independently valid for pdVerdict --
        %its baseline is median(first 300 frames) and needs real dark there.
        traces = cell(opt.Repeats,1);
        whiteCts = nan(opt.Repeats,1);
        missed = nan(opt.Repeats,1);
        for iterR = 1:opt.Repeats
            if ~ishandle(hFig)
                break
            end
            status(sprintf('repeat %d of %d: dark lead-in...',iterR,opt.Repeats))
            [d,wc,mf] = presentOnce(durMs);
            traces{iterR} = d;
            whiteCts(iterR) = wc;
            missed(iterR) = mf;
        end

        keep = ~cellfun(@isempty,traces);
        traces = traces(keep);
        whiteCts = whiteCts(keep);
        missed = missed(keep);
        if isempty(traces)
            status('no data captured')
            return
        end

        latched.repeatTraces = traces;
        latched.repeatWhiteCts = whiteCts;
        latched.flickerTrace = traces{1};
        latched.whiteCt = median(whiteCts(~isnan(whiteCts)));
        if isempty(latched.whiteCt)
            latched.whiteCt = NaN;
        end
        latched.missedFrames = max(missed);

        %Analyse whatever was captured, even if something downstream fails --
        %a populated panel from a partial capture beats an empty one.
        try
            analyseFlicker(traces);
            status(sprintf('flicker latched (%d repeats)',numel(traces)))
        catch ME
            latched.verdictError = ME.message;
            fprintf(2,'\npdLiveMonitor: flicker analysis failed:\n%s\n',...
                getReport(ME,'extended','hyperlinks','off'));
            status('captured, but analysis failed')
        end
    end

    function [d,whiteCt,missedFrames] = presentOnce(durMs)
        %One dark lead-in plus one presentation, captured as a single trace.
        whiteCt = NaN;
        missedFrames = NaN;
        leadSec = 0.2;%~1200 camera frames at 6000 fps, well over the 300 needed
        goDark();
        pause(0.3)%let the projector settle before the lead-in
        capTarget = max(round((leadSec+durMs/1000+0.5)*info.actualRate),1);
        capBuf = zeros(capTarget,nCh);
        capFilled = 0;
        capturing = true;
        t0 = tic;
        while toc(t0) < leadSec && ishandle(hFig)
            pause(0.02)
        end
        latched.leadInSec = leadSec;
        sendUDP([4 double('0;45')]);

        %Keep the listener alive for most of the presentation, then listen
        %for the reply -- it only arrives at the end, and UDP packets that
        %land with nothing bound are simply lost.
        t0 = tic;
        while capturing && toc(t0) < max(durMs/1000-0.3,0) && ishandle(hFig)
            pause(0.02)
        end
        reply = recvUDP(6000);
        drawnow
        pause(0.2)
        capturing = false;
        d = capBuf(1:capFilled,:);
        if ~isempty(d)
            d = d(:,1);
        end

        parts = strsplit(reply,';');
        if numel(parts) >= 2
            missedFrames = str2double(parts{1});
            whiteCt = str2double(parts{2});
        end
    end

    function analyseFlicker(traces)
        %traces is a cell array, one entry per repeat.  Every per-repeat
        %metric is computed independently and then reduced with a median, so
        %one bad presentation (a dropped frame, a stray light event) cannot
        %drag the answer around the way averaging would.  The spread across
        %repeats is kept too -- if it is large, the measurement is not
        %trustworthy however good the median looks.
        Fs = info.actualRate;
        lead = latched.leadInSec;
        if isnan(lead)
            lead = 0;
        end
        n = numel(traces);
        latched.nRepeats = n;

        pk = nan(n,1);
        rise = nan(n,1);
        fall = nan(n,1);
        tpls = [];
        verdicts = [];
        for iterT = 1:n
            x = traces{iterT};
            %AC metrics must see only the stimulus; the dark lead-in is there
            %for pdVerdict's baseline and would dilute them.
            firstStim = min(round(lead*Fs)+1,numel(x));
            xs = x(firstStim:end);

            pk(iterT) = robustPkPk(xs,Fs,opt.FlickerHz);
            [tpl,tplT] = cycleAverage(xs,Fs,opt.FlickerHz);
            if ~isempty(tpl)
                if isempty(tpls)
                    tpls = tpl(:);
                    latched.cycleTime = tplT;
                elseif numel(tpl) == size(tpls,1)
                    tpls = [tpls,tpl(:)]; %#ok<AGROW>
                end
                [rise(iterT),fall(iterT)] = edgeTimes(tpl,tplT);
            end

            wc = latched.whiteCt;
            if isnan(wc)
                wc = numel(x)/Fs*opt.FlickerHz;
                latched.whiteCtEstimated = true;
            else
                latched.whiteCtEstimated = false;
            end
            try
                v = pdVerdict(x,Fs,opt.CamRate,wc,'Variant','both');
                if isempty(verdicts)
                    verdicts = v;
                else
                    verdicts(end+1,:) = v; %#ok<AGROW>
                end
            catch ME
                latched.verdictError = ME.message;
            end
        end

        latched.acPkPk = nanmedianLocal(pk);
        latched.acPkPkSpread = localRange(pk);
        latched.riseTime = nanmedianLocal(rise);
        latched.riseSpread = localRange(rise);
        latched.fallTime = nanmedianLocal(fall);
        latched.verdict = verdicts;

        %Median across repeats of the folded waveform, so the displayed
        %template matches the numbers rather than being one arbitrary repeat.
        if ~isempty(tpls)
            latched.cycleTemplate = median(tpls,2);
            [~,~,lo,hi] = edgeTimes(latched.cycleTemplate,latched.cycleTime);
            latched.cycleLo = lo;
            latched.cycleHi = hi;
        end

        if ~isnan(latched.riseTime) && latched.riseTime > 0
            latched.fcFromRise = 0.35/latched.riseTime;
        end
        if ~isnan(latched.dcSwing) && latched.dcSwing ~= 0 && ~latched.whiteClipped
            r = abs(latched.acPkPk/latched.dcSwing);
            latched.acOverDc = r;
            %Single-pole steady-state response to a square wave of period T:
            %pkpk = A*tanh(T/(4*tau)).  Inverting this only resolves fc while
            %the ratio is still meaningfully below 1 -- tanh saturates, and in
            %testing the inversion tracked the true fc to within ~5% up to
            %300 Hz and then flattened out around 830 Hz no matter how fast
            %the sensor really was.  Report nothing rather than a number that
            %is really just "faster than this test can tell".
            if r < 0.99
                T = 1/opt.FlickerHz;
                tau = T/(4*atanh(r));
                latched.fcFromAtten = 1/(2*pi*tau);
            else
                latched.fcAttenSaturated = true;
            end
        end
        if ~isnan(latched.noiseFloor) && latched.noiseFloor > 0
            latched.snr = latched.acPkPk/latched.noiseFloor;
        end
    end

    function name = resolveStimFile()
        if ~isempty(opt.StimFile)
            name = opt.StimFile;
            return
        end
        if ~isempty(latched.stimFile)
            name = latched.stimFile;
            return
        end
        %A constSize stimulus holds the dome static and flickers only the
        %reference patch, so stray dome light cannot confound the reading.
        %A looming stimulus also works but sweeps dome luminance throughout.
        hits = dir(fullfile(cfg.stimuliDir,'constSize_*.mat'));
        if isempty(hits)
            error('pdLiveMonitor:noConstSize',...
                ['No constSize_*.mat in %s.\nGenerate one with '...
                'flyPEZguis/stimulusFunctions/loomingStimulusMaker_withReference.m '...
                '(pez5 = 0, stimChoice = 4, '...
                'duration = 3000), or pass ''StimFile'' explicitly.'],...
                cfg.stimuliDir)
        end
        %Pick by declared duration, not by file size.  Biggest-file was a bad
        %heuristic: it selected a 20 s, 90 deg stimulus, which is thousands of
        %full-screen frames and made the stimulus computer reply "error".
        %A few seconds is all this needs -- long enough for stable statistics,
        %short enough to build and hold in memory.
        targetMs = 3000;
        durs = nan(numel(hits),1);
        for iterH = 1:numel(hits)
            tok = regexp(hits(iterH).name,'_for(\d+)ms_','tokens','once');
            if ~isempty(tok)
                durs(iterH) = str2double(tok{1});
            end
        end
        usable = find(durs >= 500 & durs <= 6000);
        if isempty(usable)
            list = sprintf('\n  %s',hits.name);
            error('pdLiveMonitor:noUsableConstSize',...
                ['None of the constSize files in %s has a usable duration '...
                '(want 500-6000 ms).  Found:%s\n\nA very long or very large '...
                'stimulus makes the stimulus computer reply "error" rather '...
                'than a duration.  Generate a short one with '...
                'flyPEZguis/stimulusFunctions/loomingStimulusMaker_withReference.m '...
                '(pez5 = 0, stimChoice = 4, initStimSize = 5, duration = 3000), '...
                'or pass ''StimFile'' explicitly.'],cfg.stimuliDir,list)
        end
        [~,best] = min(abs(durs(usable)-targetMs));
        name = hits(usable(best)).name;
    end

    function doSnapshot()
        snap = struct;
        snap.meta = struct('pez',cfg.pezName,'devID',cfg.devID,...
            'controlHost',cfg.compName,'hostIP',cfg.hostIP,...
            'channels',{opt.Channels},'requestedRate',info.requestedRate,...
            'actualRate',info.actualRate,'actualRange',info.actualRange,...
            'flickerHz',opt.FlickerHz,'camRate',opt.CamRate,...
            'when',datestr(now,31),'matlab',version); %#ok<TNOW1,DATST>
        snap.ring = bufData;
        snap.latched = latched;
        fname = sprintf('pdSnapshot_%s_%s.mat',cfg.pezName,datestr(now,30)); %#ok<TNOW1,DATST>
        save(fname,'-struct','snap')
        status(['saved ' fname])
        fprintf('pdLiveMonitor: wrote %s\n',fullfile(pwd,fname));
    end

    function resetLatched()
        latched = emptyLatched();
        status('numbers cleared')
        refresh();
    end

    function safeRefresh()
        %A throwing TimerFcn only prints "Error while evaluating TimerFcn"
        %with no stack, and then repeats every period.  Report it properly,
        %once, and stop -- acquisition keeps running, so the buttons and
        %Snapshot still work with the display frozen.
        try
            refresh();
        catch ME
            if ~isempty(hTimer) && isvalid(hTimer)
                stop(hTimer)
            end
            fprintf(2,['\npdLiveMonitor: live display stopped after an '...
                'error.  Acquisition is still running and the buttons still '...
                'work.\n%s\n'],getReport(ME,'extended','hyperlinks','off'));
            status('display stopped -- see command window')
        end
    end

    function refresh()
        if ~ishandle(hFig)
            return
        end
        x = bufData(:,1);
        t = (0:numel(x)-1)'/info.actualRate*1000;
        set(hTrace,'XData',t,'YData',x)
        if bufFilled > 1
            ylo = min(x);
            yhi = max(x);
            if yhi-ylo < 1e-6
                ylo = ylo-0.01;
                yhi = yhi+0.01;
            end
            set(axTrace,'XLim',[0 max(t)],'YLim',[ylo yhi]+[-1 1]*0.05*(yhi-ylo))
        end

        if ~isempty(latched.cycleTemplate)
            set(hCycle,'XData',latched.cycleTime*1000,'YData',latched.cycleTemplate)
            xl = [0 max(latched.cycleTime)*1000];
            set(hCycleLo,'XData',xl,'YData',[1 1]*latched.cycleLo)
            set(hCycleHi,'XData',xl,'YData',[1 1]*latched.cycleHi)
            set(axCycle,'XLim',xl)
        end

        %Preserve the scroll position: this redraws five times a second, and
        %resetting ListboxTop each time would make the panel impossible to
        %read anywhere but the top.
        lines = reportText(x);
        oldTop = get(hText,'ListboxTop');
        set(hText,'String',lines,'Value',[])
        set(hText,'ListboxTop',max(1,min(oldTop,numel(lines))))
        %Plain drawnow: 'limitrate' arrived in R2015a and the rig's MATLAB
        %is older, where it fails with "Unknown command option".  Because
        %refresh() runs from the 200 ms timer AND from guardedUDP, that one
        %bad option produced an error storm on every button press.
        drawnow
    end

    function L = bottomLine()
        %The go/no-go, stated plainly.  Two independent questions: is the
        %sensor physically fast enough, and would the rig's own gate accept
        %the trace.  They can disagree -- a fast sensor can still fail the
        %gate on peak timing -- so report both.
        want = 120;%Hz, the corner frequency the rig's gate needs (pdSelfTest)
        L = {};
        L{end+1} = '===== CAN THIS SENSOR DO 120 Hz? =====';
        if isnan(latched.fcFromRise)
            L{end+1} = '  not measured yet -- press Flicker';
        elseif latched.fcFromRise >= want
            L{end+1} = sprintf('  YES.  fc %.0f Hz  (%.1fx the %d Hz needed)',...
                latched.fcFromRise,latched.fcFromRise/want,want);
            L{end+1} = sprintf('        rise %.3f ms, needs to be under 2.9 ms',...
                latched.riseTime*1000);
        else
            L{end+1} = sprintf('  NO.  fc %.0f Hz, needs to be over %d Hz',...
                latched.fcFromRise,want);
            L{end+1} = sprintf('        rise %.3f ms, needs to be under 2.9 ms',...
                latched.riseTime*1000);
        end
        if ~isnan(latched.riseSpread) && ~isnan(latched.riseTime) &&...
                latched.riseTime > 0 && latched.riseSpread > 0.25*latched.riseTime
            L{end+1} = '  CAUTION: rise time varies a lot between repeats --';
            L{end+1} = '           treat the number above as unreliable.';
        end

        if isempty(latched.verdict)
            L{end+1} = '  rig gate:  press Flicker to score a trace';
        else
            nRep = size(latched.verdict,1);
            for iterCol = 1:size(latched.verdict,2)
                col = latched.verdict(:,iterCol);
                nGood = sum(strcmp({col.decision},'good photodiode'));
                if nGood == nRep
                    word = 'PASS';
                else
                    word = 'FAIL';
                end
                L{end+1} = sprintf('  rig gate:  %s  %s (%d of %d) - %s',...
                    word,col(1).variant,nGood,nRep,col(1).decision); %#ok<AGROW>
            end
        end
    end

    function lines = reportText(x)
        Fs = info.actualRate;
        L = {};
        %The answer first.  The panel is taller than its box, so whatever
        %matters most has to be readable without scrolling.
        L = [L,bottomLine()];
        L{end+1} = '';

        L{end+1} = sprintf('ACQUISITION   %d ch @ %.0f S/s/ch  (%.0f kS/s aggregate)',...
            nCh,Fs,Fs*nCh/1000);
        if isempty(info.actualRange)
            L{end+1} = '  range        board default (NOT SET)';
        else
            L{end+1} = sprintf('  range        %+.3f to %+.3f V',...
                info.actualRange(1),info.actualRange(2));
        end
        L{end+1} = sprintf('  live min/max %+.4f / %+.4f V   mean %+.4f V',...
            min(x),max(x),mean(x));
        L{end+1} = sprintf('  at DAQ rails %.2f %% of samples',...
            100*clipFraction(x,info.actualRange));
        L{end+1} = sprintf('  at %.1f V rail %.2f %% of samples',...
            opt.SensorRail,100*mean(x >= opt.SensorRail-0.005));
        L{end+1} = sprintf('  live pk-pk   %.4f V (robust, @%g Hz)',...
            robustPkPk(x,Fs,opt.FlickerHz),opt.FlickerHz);
        L{end+1} = '';

        L{end+1} = 'LIGHT LEVEL';
        L{end+1} = sprintf('  dcDark       %s',fmtV(latched.dcDark));
        L{end+1} = sprintf('  dcWhite      %s',fmtV(latched.dcWhite));
        L{end+1} = sprintf('  dcSwing      %s',fmtV(latched.dcSwing));
        if latched.whiteClipped
            if latched.whiteDaqClipFrac > 0.02
                L{end+1} = '  !! White hit the DAQ RANGE ceiling. Widen ''Range''.';
            else
                L{end+1} = sprintf(...
                    '  !! White saturated the SENSOR at its %.1f V rail (%.0f%% of',...
                    opt.SensorRail,100*latched.whiteRailFrac);
                L{end+1} = '     samples). Too much light or too much gain: use a';
                L{end+1} = '     smaller load resistor, or stop down the sensor.';
            end
            L{end+1} = '     dcSwing is a LOWER BOUND, so the two numbers below';
            L{end+1} = '     that depend on it are withheld.';
        end
        L{end+1} = '';

        L{end+1} = 'BANDWIDTH';
        if latched.nRepeats > 0
            L{end+1} = sprintf('  repeats      %d',latched.nRepeats);
        end
        L{end+1} = sprintf('  AC pk-pk     %s%s',fmtV(latched.acPkPk),...
            fmtSpread(latched.acPkPkSpread,'V'));
        if latched.whiteClipped
            L{end+1} = '  acPkPk/dcSwing withheld -- White clipped (see above)';
        else
            L{end+1} = sprintf('  acPkPk/dcSwing %s   <- the discriminator  [want >0.75]',...
                fmtN(latched.acOverDc));
        end
        L{end+1} = '     (ceiling is below 1 even for an ideal sensor: White drives';
        L{end+1} = '      all three sub-frames at 255, the flicker is 255<->10 at 50%)';
        L{end+1} = sprintf('  rise 10-90   %s%s  [want <2.9 ms]',...
            fmtMs(latched.riseTime),fmtSpread(latched.riseSpread*1000,'ms'));
        L{end+1} = sprintf('  fall 90-10   %s',fmtMs(latched.fallTime));
        L{end+1} = sprintf('  fc from rise %s  [want >120 Hz]',fmtHz(latched.fcFromRise));
        if latched.whiteClipped
            L{end+1} = '  fc from atten withheld -- needs an unclipped dcSwing';
        elseif latched.fcAttenSaturated
            L{end+1} = '  fc from atten >300 Hz (ratio saturated: too fast to resolve';
            L{end+1} = '                         this way, which is good news)';
        else
            L{end+1} = sprintf('  fc from atten%s',fmtHz(latched.fcFromAtten));
        end
        L{end+1} = '     (agreement between the two is the confirmation; the';
        L{end+1} = '      attenuation estimate only resolves fc below ~300 Hz)';
        L{end+1} = '';

        L{end+1} = 'AGAINST THE RIG''S OWN GATE';
        L{end+1} = sprintf('  noise floor  %s (median IQR, dark trace)',fmtV(latched.noiseFloor));
        L{end+1} = sprintf('  SNR          %s  [want >5]',fmtN(latched.snr));
        if ~isempty(latched.verdict)
            nRep = size(latched.verdict,1);
            for iterCol = 1:size(latched.verdict,2)
                col = latched.verdict(:,iterCol);
                nGood = sum(strcmp({col.decision},'good photodiode'));
                L{end+1} = sprintf('  [%-11s] good photodiode %d of %d repeats',...
                    col(1).variant,nGood,nRep); %#ok<AGROW>
                if nGood < nRep
                    %Name every distinct failure, not just the first -- the
                    %mode of failure is what points at the cause.
                    other = unique({col(~strcmp({col.decision},'good photodiode')).decision});
                    for iterF = 1:numel(other)
                        L{end+1} = sprintf('     also: %s',other{iterF}); %#ok<AGROW>
                    end
                end
                pst = [col.photoSignalTest];
                L{end+1} = sprintf('     photoSignalTest %.2f-%.2f vs threshold %d',...
                    min(pst),max(pst),col(1).threshold); %#ok<AGROW>
                L{end+1} = sprintf('     peaks %s of whiteCt %g   spacing spread %s',...
                    fmtIntRange([col.nPeaks]),col(1).whiteCt,...
                    fmtIntRange([col.rangeDiffPeaks])); %#ok<AGROW>
            end
            if latched.whiteCtEstimated
                L{end+1} = '     (whiteCt estimated from duration, not reported by the stim PC)';
            end
        elseif ~isempty(latched.verdictError)
            L{end+1} = ['  verdict failed: ' latched.verdictError];
        else
            L{end+1} = '  press Flicker to score a trace';
        end
        lines = L;
    end

    function requestStop()
        stopFlag = true;
    end

    function sendUDP(code)
        if ~useUDP
            return
        end
        judp('send',cfg.portNum,cfg.hostIP,int8(code));
    end

    function reply = recvUDP(totalMs)
        %Wait up to totalMs for a reply, in short polling windows.
        %
        %Never use one long blocking judp call here.  It sits inside Java and
        %no DataAvailable event can be dispatched while it does, so at
        %60 kS/s across three channels a multi-second block will overrun the
        %session buffer and abort the acquisition.  The cost of polling is
        %that the reply can land in the gap between closing one socket and
        %opening the next; every caller treats a missing reply as non-fatal.
        reply = '';
        if ~useUDP
            return
        end
        windowMs = 250;
        t0 = tic;
        while isempty(reply) && toc(t0)*1000 < totalMs &&...
                (isempty(hFig) || ishandle(hFig))
            try
                raw = judp('receive',cfg.portNum,200,windowMs);
                reply = strtrim(char(raw'));
            catch
                %judp throws on timeout rather than returning empty.
                reply = '';
            end
            pause(0.01)%let queued DataAvailable events through
        end
    end

    function cleanupAll()
        if ~isempty(hTimer) && isvalid(hTimer)
            stop(hTimer)
            delete(hTimer)
        end
        if ~isempty(lh)
            delete(lh)
        end
        if ~isempty(sIn)
            try
                if sIn.IsRunning
                    stop(sIn)
                end
                release(sIn)
            catch
            end
            delete(sIn)
        end
        if useUDP
            try
                %Only valid after a standard init -- see goDark.
                if strcmp(stimInitMode,'standard')
                    judp('send',cfg.portNum,cfg.hostIP,int8(10))%leave the dome dark
                end
            catch
            end
            if ~isempty(latched.stimFile)
                fprintf(['pdLiveMonitor: the stimulus computer now holds "%s".  '...
                    'Reload the GUI''s stimulus before running experiments.\n'],...
                    latched.stimFile);
            end
        end
        if ~isempty(hFig) && ishandle(hFig)
            delete(hFig)
        end
    end

end

%% -------------------------------------------------------------- helpers

function cfg = resolveRig(opt)
%resolveRig Identify this rig from computer_info.xlsx on the share.

cfg = struct('pezName','unknown','devID',opt.DevID,'hostIP',opt.HostIP,...
    'portNum',21566,'compName','','variablesDir','','stimuliDir','','compRef',NaN);

[~,compName] = system('hostname');
cfg.compName = strtrim(compName);

%The share path lives in pezFilePath.TXT, as everywhere else in the repo --
%it has moved before, so do not hardcode it.
%<repo>/flyPEZoperation/photodiode_testing -> <repo>
here = fileparts(mfilename('fullpath'));
repoDir = fileparts(fileparts(here));
%The file is pezFilePath.TXT in this tree but pezFilePath.txt in others.
%Case only matters on a case-sensitive filesystem, but try both so this
%keeps working if the folder is copied somewhere that cares.
pathFile = fullfile(repoDir,'flyPEZanalysis','pezFilePath.TXT');
if ~exist(pathFile,'file')
    pathFile = fullfile(repoDir,'flyPEZanalysis','pezFilePath.txt');
end
fileDir = '';
if exist(pathFile,'file')
    fid = fopen(pathFile);
    fileDir = fscanf(fid,'%s');
    fclose(fid);
end
if isempty(fileDir)
    warning('pdLiveMonitor:noPathFile',...
        'Could not read pezFilePath.TXT; falling back to \\\\dm11\\cardlab.')
    fileDir = [filesep filesep 'dm11' filesep 'cardlab'];
end
cfg.variablesDir = fullfile(fileDir,'pez3000_variables');
cfg.stimuliDir = fullfile(cfg.variablesDir,'visual_stimuli');

if ~isempty(cfg.devID) && ~isempty(cfg.hostIP)
    return%fully overridden; no need for the spreadsheet
end

compDataPath = fullfile(cfg.variablesDir,'computer_info.xlsx');
if ~exist(compDataPath,'file')
    error('pdLiveMonitor:noComputerInfo',...
        ['Cannot reach %s.  Either mount the share or pass both ''DevID'' '...
        'and ''HostIP''.'],compDataPath)
end
compData = dataset('XLSFile',compDataPath);
compRef = find(strcmpi(compData.control_computer_name,cfg.compName));
if isempty(compRef)
    error('pdLiveMonitor:unknownHost',...
        ['This computer (%s) is not listed as a control_computer_name in '...
        '%s.  Pass ''DevID'' and ''HostIP'' to run anyway.'],...
        cfg.compName,compDataPath)
end
compRef = compRef(1);
cfg.compRef = compRef;
if isempty(cfg.devID)
    cfg.devID = ['Dev' num2str(compData.NIDAQ_Device_ID(compRef))];
end
if isempty(cfg.hostIP)
    cfg.hostIP = compData.stimulus_computer_IP{compRef};
end
if compRef == 5
    cfg.stimuliDir = fullfile(cfg.variablesDir,'visual_stimuli_pez3005');
end
try
    %pez_reference holds the full rig number (3002), not the digit.
    pezRef = compData.pez_reference(compRef);
    if pezRef >= 1000
        cfg.pezName = sprintf('pez%d',pezRef);
    else
        cfg.pezName = sprintf('pez300%d',pezRef);
    end
catch
    cfg.pezName = sprintf('rig%d',compRef);
end

end

function m = nanmedianLocal(x)
%nanmedianLocal median ignoring NaN, without needing the Statistics Toolbox's
%nanmedian (which is deprecated) or newer median(...,'omitnan').

x = x(~isnan(x));
if isempty(x)
    m = NaN;
else
    m = median(x);
end

end

function r = localRange(x)
%localRange max-min ignoring NaN.  Reported alongside each median so a
%measurement that varies wildly between repeats is visible as such.

x = x(~isnan(x));
if numel(x) < 2
    r = NaN;
else
    r = max(x)-min(x);
end

end

function v = rangeToVector(r)
%rangeToVector Normalise a channel Range to a numeric [lo hi].
%The session API accepts [lo hi] on assignment but hands back a daq.Range
%object on read, so everything downstream has to be insulated from which
%form it got.

if isempty(r)
    v = [];
elseif isnumeric(r)
    v = double(r(:))';
else
    try
        v = [double(r(1).Min) double(r(1).Max)];
    catch
        v = [];
    end
end

end

function r = availableRanges(devID)
%availableRanges Legal analog-input ranges for this board, if discoverable.

r = [];
try
    devs = daq.getDevices;
    ndx = find(strcmpi({devs.ID},devID),1);
    if isempty(ndx)
        return
    end
    subs = devs(ndx).Subsystems;
    aiNdx = find(strcmpi({subs.SubsystemType},'AnalogInput'),1);
    if isempty(aiNdx)
        return
    end
    r = subs(aiNdx).RangesAvailable;
catch
    %Older toolbox versions name these differently; the tool still works,
    %it just cannot narrow the range automatically.
end

end

function f = clipFraction(x,rng)
%clipFraction Fraction of samples sitting against the input-range rails.

if isempty(rng) || numel(rng) < 2
    f = 0;
    return
end
tol = 0.001*(rng(2)-rng(1));
f = mean(x <= rng(1)+tol | x >= rng(2)-tol);

end

function n = chunkNoise(x,nChunk)
%chunkNoise Median IQR over nChunk equal chunks -- the same estimator family
%the rig's own gate uses, so the number is comparable to minRange.

x = x(:);
if numel(x) < nChunk*4
    n = iqr(x);
    return
end
brks = round(linspace(1,numel(x),nChunk));
vals = zeros(numel(brks)-1,1);
for iterC = 1:numel(brks)-1
    vals(iterC) = iqr(x(brks(iterC):brks(iterC+1)));
end
n = median(vals);

end

function pp = robustPkPk(x,Fs,flickerHz)
%robustPkPk Median per-cycle 2.5-97.5 percentile spread.  max-min over the
%whole buffer is noise-driven and flatters a bad sensor.

x = x(:);
L = Fs/flickerHz;
nCyc = floor(numel(x)/L);
if nCyc < 3
    pp = NaN;
    return
end
vals = zeros(nCyc,1);
for iterC = 1:nCyc
    lo = floor((iterC-1)*L)+1;
    hi = min(floor(iterC*L),numel(x));
    seg = x(lo:hi);
    vals(iterC) = prctile(seg,97.5)-prctile(seg,2.5);
end
pp = median(vals);

end

function [tpl,tplT] = cycleAverage(x,Fs,flickerHz)
%cycleAverage Fold every cycle onto one template, phase-locked to the
%flicker.  This is what a high sample rate buys: at 50 kS/s a 2.78 ms state
%is ~139 samples, enough to actually measure an edge.

x = x(:);
nPts = 200;
tplT = (0:nPts-1)'/nPts/flickerHz;
T = 1/flickerHz;
L = Fs/flickerHz;
nCyc = floor(numel(x)/L);
if nCyc < 3
    tpl = [];
    tplT = [];
    return
end

%Phase of the fundamental, so cycles are aligned before averaging.
t = (0:numel(x)-1)'/Fs;
c = mean((x-mean(x)).*exp(-1i*2*pi*flickerHz*t));
shift = mod(-angle(c)/(2*pi),1)*T;

acc = zeros(nPts,1);
used = 0;
for iterC = 1:nCyc-1
    want = shift+(iterC-1)*T+tplT;
    if want(end)*Fs+1 > numel(x)
        break
    end
    acc = acc+interp1(t,x,want,'linear',NaN);
    used = used+1;
end
if used == 0
    tpl = [];
    tplT = [];
    return
end
tpl = acc./used;

end

function [tRise,tFall,lo,hi] = edgeTimes(tpl,tplT)
%edgeTimes 10-90% rise and 90-10% fall from the cycle-averaged template.
%Levels are taken as the 10th/90th percentile of the template rather than
%min/max so ringing or overshoot does not set the reference.

tRise = NaN;
tFall = NaN;
lo = NaN;
hi = NaN;
if isempty(tpl) || numel(tpl) < 20
    return
end
lo = prctile(tpl,10);
hi = prctile(tpl,90);
if hi-lo <= 0
    return
end
thr10 = lo+0.1*(hi-lo);
thr90 = lo+0.9*(hi-lo);

%Work on a doubled template so an edge straddling the wrap is still found.
y = [tpl;tpl];
dt = tplT(2)-tplT(1);

tRise = spanBetween(y,thr10,thr90,dt,1);
tFall = spanBetween(y,thr90,thr10,dt,-1);

end

function tSpan = spanBetween(y,thrA,thrB,dt,direction)
%spanBetween Time from the first crossing of thrA to the next crossing of
%thrB, in the given direction.

tSpan = NaN;
n = numel(y);
for iterS = 2:n
    if direction > 0
        crossedA = y(iterS-1) < thrA && y(iterS) >= thrA;
    else
        crossedA = y(iterS-1) > thrA && y(iterS) <= thrA;
    end
    if ~crossedA
        continue
    end
    iA = iterS-1+(thrA-y(iterS-1))/(y(iterS)-y(iterS-1));
    for iterE = iterS:n
        if direction > 0
            crossedB = y(iterE-1) < thrB && y(iterE) >= thrB;
        else
            crossedB = y(iterE-1) > thrB && y(iterE) <= thrB;
        end
        if crossedB
            iB = iterE-1+(thrB-y(iterE-1))/(y(iterE)-y(iterE-1));
            tSpan = (iB-iA)*dt;
            return
        end
    end
    return
end

end

function L = emptyLatched()
%emptyLatched The measurement state that the buttons fill in.

L = struct('dcDark',NaN,'dcWhite',NaN,'dcSwing',NaN,'acPkPk',NaN,...
    'acOverDc',NaN,'riseTime',NaN,'fallTime',NaN,'fcFromRise',NaN,...
    'fcFromAtten',NaN,'noiseFloor',NaN,'snr',NaN,'whiteCt',NaN,...
    'whiteCtEstimated',false,'missedFrames',NaN,'stimFile','',...
    'stimDurationMs',NaN,'leadInSec',NaN,'fcAttenSaturated',false,...
    'whiteClipped',false,'whiteRailFrac',NaN,'whiteDaqClipFrac',NaN,...
    'repeatTraces',{{}},'repeatWhiteCts',[],'nRepeats',0,'acPkPkSpread',NaN,...
    'riseSpread',NaN,...
    'cycleTemplate',[],'cycleTime',[],'cycleLo',NaN,...
    'cycleHi',NaN,'darkTrace',[],'whiteTrace',[],'flickerTrace',[],...
    'verdict',[],'verdictError','');

end

function s = fmtSpread(v,unit)
%fmtSpread Show the across-repeat spread next to a median, or nothing when
%there is only one repeat to compare.

if isnan(v)
    s = '';
else
    s = sprintf(' (spread %.3f %s)',v,unit);
end
end

function s = fmtIntRange(v)
v = v(~isnan(v));
if isempty(v)
    s = '--';
elseif min(v) == max(v)
    s = sprintf('%g',v(1));
else
    s = sprintf('%g-%g',min(v),max(v));
end
end

function s = fmtV(v)
if isnan(v)
    s = '--';
else
    s = sprintf('%+.4f V',v);
end
end

function s = fmtN(v)
if isnan(v)
    s = '--';
else
    s = sprintf('%.3f',v);
end
end

function s = fmtMs(v)
if isnan(v)
    s = '--';
else
    s = sprintf('%.3f ms',v*1000);
end
end

function s = fmtHz(v)
if isnan(v)
    s = ' --';
else
    s = sprintf(' %.0f Hz',v);
end
end
