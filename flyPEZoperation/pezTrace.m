function pezTrace(msg,logDir)
% pezTrace  TEMPORARY freeze diagnostic. Appends one timestamped line to
% pezFreezeTrace.log and closes the file, so the last line on disk is the
% last step reached before a freeze.
%   pezTrace('init',dirPath)  sets the log folder (call once at startup).
%   pezTrace('text')          writes a line.
% To remove: delete this file and every line that starts with pezTrace(.
persistent logPath
try
    if nargin > 1
        logPath = fullfile(logDir,'pezFreezeTrace.log');
    end
    if isempty(logPath), return, end
    fid = fopen(logPath,'a');
    if fid < 0, return, end
    fprintf(fid,'%s  %s\r\n',datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'),msg);
    fclose(fid);
catch
end
end
