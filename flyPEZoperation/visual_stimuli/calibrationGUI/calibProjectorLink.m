function reply = calibProjectorLink(action,ip)
%CALIBPROJECTORLINK UDP commands to the stimulus (projector) computer.
%   Same transport as projectorCalibration3000_v3.m (judp, port 21566):
%     'wake'   command 5  - open the display window (v3 L43-50)
%     'show'   command 54 - display im2show.tif (v3 L243, 756)
%     'reload' command 0  - load the saved stimuliVars.mat into the display
%   Command 0 is taken from the listener's documented behaviour and has not
%   been exercised from here.
portNum = 21566;
switch action
    case 'wake',   cmd = 5;
    case 'show',   cmd = 54;
    case 'reload', cmd = 0;
    otherwise, error('calibProjectorLink:action','Unknown action %s',action);
end
if exist('judp','file') == 0
    error('calibProjectorLink:judp','judp is not on the MATLAB path.');
end
judp('send',portNum,ip,int8(cmd))
if cmd == 54
    reply = '';
else
    reply = char(judp('receive',portNum,50,15000)');
end
end
