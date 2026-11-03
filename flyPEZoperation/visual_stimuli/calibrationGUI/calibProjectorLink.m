function reply = calibProjectorLink(action,ip,logFcn)
%CALIBPROJECTORLINK UDP commands to the stimulus (projector) computer.
%   Same transport as projectorCalibration3000_v3.m (judp, port 21566):
%     'wake'   command 5  - open the display window; replies success/error
%     'show'   command 54 - display im2show.tif; the listener never replies
%     'reload' command 0  - load stimuliVars.mat into the display; replies
%   logFcn (optional) is called with one text line per event so the GUI can
%   show what was sent and what the stimulus computer answered.
%
%   Why the extra handling: udpInitializationListener_v2 only has its UDP port
%   open while it sits inside judp('receive'), and it closes the port while it
%   runs a command. A datagram sent in that window is silently dropped. So
%   'wake' and 'reload' pause afterwards (the listener is still busy when it
%   sends its reply), and 'show' is sent several times (re-showing the same
%   image is harmless).
if nargin < 3, logFcn = @(~)[]; end
portNum = 21566;
showAttempts = 3;      % command 54 sends
showGap = 1;           % seconds between them
settle = 2;            % seconds to let the listener get back to receiving
replyWait = 15000;     % ms, same as v3 and runPezControl
switch action
    case 'wake',   cmd = 5;
    case 'show',   cmd = 54;
    case 'reload', cmd = 0;
    otherwise, error('calibProjectorLink:action','Unknown action %s',action);
end
if exist('judp','file') == 0
    error('calibProjectorLink:judp','judp is not on the MATLAB path.');
end
if cmd == 54
    for a = 1:showAttempts
        logFcn(sprintf('-> cmd 54 (show image) to %s, send %d of %d',ip,a,showAttempts));
        judp('send',portNum,ip,int8(cmd))
        if a < showAttempts, pause(showGap); end
    end
    logFcn('   Command 54 gets no reply, so arrival cannot be confirmed - check the dome.');
    reply = '';
    return
end
logFcn(sprintf('-> cmd %d (%s) to %s, waiting up to %d s for a reply',cmd,action,ip,replyWait/1000));
judp('send',portNum,ip,int8(cmd))
t = tic;
try
    reply = char(judp('receive',portNum,50,replyWait)');
catch err
    msg = regexprep(err.message,'\s+',' ');
    logFcn(sprintf('<- NO REPLY after %.1f s (%s)',toc(t),msg));
    error('calibProjectorLink:noReply',...
        'No reply from %s to command %d within %d s. Is udpInitializationListener running there?',...
        ip,cmd,replyWait/1000);
end
logFcn(sprintf('<- reply "%s" after %.1f s',reply,toc(t)));
if strcmp(reply,'error')
    error('calibProjectorLink:stimError','The stimulus computer replied "error" to command %d.',cmd);
end
logFcn(sprintf('   waiting %d s for the listener to resume receiving',settle));
pause(settle);
end
