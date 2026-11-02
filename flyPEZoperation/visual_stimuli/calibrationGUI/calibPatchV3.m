function report = calibPatchV3(v3Path,pezName,vals)
%CALIBPATCHV3 Write calibration values into one pez case block of v3.
%   Copies v3 to a timestamped backup first, then replaces the first
%   uncommented assignment of each value inside "case '<pezName>'". Nothing
%   else in the file is touched. report.ok is true only if every value reads
%   back equal after the write; report.backup is the copy to restore from.
txt = fileread(v3Path);
lines = regexp(txt,'\r?\n','split');
eol = '\n'; if contains(txt,sprintf('\r\n')), eol = '\r\n'; end
first = find(~cellfun('isempty',regexp(lines,['^\s*case\s+''' pezName '''(\s|$)'],'once')),1);
if isempty(first), error('calibPatchV3:nocase','No case %s in %s',pezName,v3Path); end
last = numel(lines);
for k = first+1:numel(lines)
    if ~isempty(regexp(lines{k},'^\s*(case\s+''|otherwise)','once')), last = k-1; break, end
end
[d,n,e] = fileparts(v3Path);
report.backup = fullfile(d,[n '_backup_' datestr(now,'yyyymmdd_HHMMSS') e]);
copyfile(v3Path,report.backup);
fmt = @(x) strtrim(sprintf('%.10g',x));
newVal = vals; newVal.stimRefROI = ['[' fmt(vals.stimRefX) ' ' fmt(vals.stimRefY) ']'];
names = {'atMirPlane2projector','sphereCircumference','zoomTheta','sphDropDiff',...
    'whRatioAdjust','topThreshFactor','stimRefROI','hypSkewTB','hypSkewLR',...
    'hypTwistA','hypTwistB','hypTwistC','hypTwistD'};
report.missing = {};
for i = 1:numel(names)
    nm = names{i};
    if strcmp(nm,'stimRefROI'), rhs = newVal.stimRefROI; else, rhs = fmt(vals.(nm)); end
    pat = ['^(\s*' nm '\s*=\s*)[^;%]*;'];
    hit = [];
    for k = first:last
        if ~isempty(regexp(lines{k},pat,'once')), hit = k; break, end
    end
    if isempty(hit), report.missing{end+1} = nm; continue, end %#ok<AGROW>
    lines{hit} = regexprep(lines{hit},pat,['$1' rhs ';'],'once');
end
fid = fopen(v3Path,'w'); fprintf(fid,'%s',strjoin(lines,sprintf(eol))); fclose(fid);
back = fileread(v3Path); bl = regexp(back,'\r?\n','split');
report.mismatch = {};
for i = 1:numel(names)
    nm = names{i};
    for k = first:last
        t = regexp(bl{k},['^\s*' nm '\s*=\s*([^;%]*);'],'tokens','once');
        if ~isempty(t)
            got = str2num(t{1}); %#ok<ST2NM>
            if strcmp(nm,'stimRefROI'), want = [vals.stimRefX vals.stimRefY];
            else, want = vals.(nm); end
            if ~isequal(size(got),size(want)) || any(abs(got-want) > 1e-9), report.mismatch{end+1} = nm; end %#ok<AGROW>
            break
        end
    end
end
report.ok = isempty(report.missing) && isempty(report.mismatch);
end
