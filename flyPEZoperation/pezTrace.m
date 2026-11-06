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
        if ~isdir(logDir), mkdir(logDir), end
        logPath = fullfile(logDir,'pezFreezeTrace.log');
        consolePath = fullfile(logDir,'pezConsole.log');
        for oldPath = {logPath,consolePath} % keep each file under about 20 MB
            fileInfo = dir(oldPath{1});
            if ~isempty(fileInfo) && fileInfo.bytes > 20e6
                movefile(oldPath{1},[oldPath{1} '.old'],'f')
            end
        end
        diary(consolePath) % saves Command Window text
        diary on
    end
    if isempty(logPath), return, end
    fid = fopen(logPath,'a');
    if fid < 0, return, end
    st = dbstack;
    names = strrep({st.name},'runPezControl_v16_3/','');
    chain = strjoin(names(2:min(end,8)),' < ');
    fprintf(fid,'%s  %s  %s    [%s]\r\n',datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'),getenv('COMPUTERNAME'),msg,chain);
    fclose(fid);
catch
end
end
