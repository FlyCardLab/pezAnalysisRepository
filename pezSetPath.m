function pezSetPath
%pezSetPath Adds this repository to the MATLAB search path.
%   Run this once per MATLAB session, before launching any flyPEZ program.
%   Because the repository is not on the path yet when you start, invoke it
%   by full path or by cd'ing here first:
%
%       run('C:\Users\<you>\Documents\pezAnalysisRepository\pezSetPath.m')
%
%   Live code is added to the FRONT of the path and anything under an
%   '_archive' folder is added to the BACK, so an archived file can never
%   shadow the live function of the same name.
%
%   Note on an existing duplicate: flyPEZoperation/pezProc_subfunctions and
%   flyPEZanalysis/pezProc_subfunctions hold same-named copies of several
%   files whose contents have drifted apart. genpath returns flyPEZanalysis
%   first, so that copy wins - which is the behavior this repository has
%   always had. Do not reorder without checking both copies.

repositoryDir = fileparts(mfilename('fullpath'));

allDirs = strsplit(genpath(repositoryDir),pathsep);
allDirs = allDirs(~cellfun(@isempty,allDirs));

% genpath descends into dot-directories, so it returns all of .git - 72
% folders on a normal clone. Drop anything with a dot-named component.
isHidden = ~cellfun(@isempty,regexp(allDirs,['\' filesep '\.'],'once'));
allDirs = allDirs(~isHidden);

isArchived = ~cellfun(@isempty,strfind(allDirs,[filesep '_archive'])); %#ok<STRCLFH>
liveDirs = allDirs(~isArchived);
archiveDirs = allDirs(isArchived);

addpath(strjoin(liveDirs,pathsep))
if ~isempty(archiveDirs)
    addpath(strjoin(archiveDirs,pathsep),'-end')
end

fprintf('pezAnalysisRepository on path: %d live folders, %d archived.\n',...
    numel(liveDirs),numel(archiveDirs))
end
