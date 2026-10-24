function S = ABDR_Review_Results(inputFile,outputFile)
%ABDR_REVIEW_RESULTS Summarize exported experiment CSV by algorithm/scenario.
% This file reads numerical records only, not comparator algorithm source.
if nargin<1 || isempty(inputFile)
    root=fileparts(fileparts(mfilename('fullpath')));
    inputFile=fullfile(root,'results','E01_Main_Comparison_1320_Runs.csv');
end
T=readtable(inputFile,'TextType','string');
assert(all(ismember({'Algorithm','Scenario'},T.Properties.VariableNames)), ...
    'Expected Algorithm and Scenario fields.');
measurements=intersect({'F1','F2','F3','F4','HV','IGDPlus','RuntimeSec'}, ...
    T.Properties.VariableNames,'stable');
[G,methods,scenes]=findgroups(T.Algorithm,T.Scenario);
rows=table();
for i=1:max(G)
    idx=(G==i);
    for m=1:numel(measurements)
        name=measurements{m};
        x=double(T.(name)(idx)); x=x(isfinite(x));
        if isempty(x),continue;end
        next=table(string(methods(i)),string(scenes(i)),string(name), ...
            numel(x),mean(x),std(x), ...
            'VariableNames',{'Algorithm','Scenario','Metric','N','Mean','SD'});
        rows=[rows;next]; %#ok<AGROW>
    end
end
S=rows;
if nargin>=2 && ~isempty(outputFile),writetable(S,outputFile);end
end
