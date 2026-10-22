function report = NAV_SeedAliasedControlTasks(sourceResultDir,targetResultDir,sourceMethod,targetMethod,scenarios,runs)
%NAV_SEEDALIASEDCONTROLTASKS Reuse frozen control tasks under a new label.
%   The copied MAT files retain the exact optimizer outputs but rewrite only
%   method/provenance labels. This avoids rerunning the unchanged full method
%   when building parent-algorithm and progressive-ablation experiments.

if nargin < 6,error('DA_MOVWO:SeedAlias','Six inputs are required.');end
sourceResultDir = char(sourceResultDir); targetResultDir = char(targetResultDir);
sourceMethod = string(sourceMethod); targetMethod = string(targetMethod);
sourceTaskDir = fullfile(sourceResultDir,'tasks');
targetTaskDir = fullfile(targetResultDir,'tasks');
sourcePoolDir = fullfile(sourceResultDir,'shared_pools');
targetPoolDir = fullfile(targetResultDir,'shared_pools');
localEnsureDir(targetResultDir); localEnsureDir(targetTaskDir); localEnsureDir(targetPoolDir);

srcToken = regexprep(char(sourceMethod),'[^A-Za-z0-9]+','_');
dstToken = regexprep(char(targetMethod),'[^A-Za-z0-9]+','_');
rows = cell(numel(scenarios)*numel(runs),7); k = 0;
for scenario = scenarios
    for runId = runs
        k = k + 1;
        src = fullfile(sourceTaskDir,sprintf('S%d_R%02d_%s.mat',scenario,runId,srcToken));
        dst = fullfile(targetTaskDir,sprintf('S%d_R%02d_%s.mat',scenario,runId,dstToken));
        ok = false; message = '';
        try
            if exist(src,'file') ~= 2,error('Missing source task: %s',src);end
            if exist(dst,'file') == 2
                D = load(dst,'row');
                if isfield(D,'row') && isfield(D.row,'Success') && logical(D.row.Success) && ...
                        string(D.row.Method) == targetMethod
                    ok = true; message = 'existing';
                end
            end
            if ~ok
                S = load(src);
                if isfield(S,'task') && isstruct(S.task),S.task.Method = targetMethod;end
                if isfield(S,'row') && isstruct(S.row)
                    S.row.Method = targetMethod;
                    S.row.TaskFile = string(dst);
                    if isfield(S.row,'Message')
                        msg = string(S.row.Message);
                        if isempty(msg) || all(ismissing(msg)),msg = string('');end
                        S.row.Message = msg(1);
                    end
                end
                if isfield(S,'history') && isstruct(S.history)
                    S.history.Algorithm = char(targetMethod);
                    S.history.PaperMethod = char(targetMethod);
                    S.history.AliasedFromMethod = char(sourceMethod);
                    S.history.AliasedFromTaskFile = src;
                end
                S.aliasProvenance = struct('SourceMethod',sourceMethod,'TargetMethod',targetMethod, ...
                    'SourceTaskFile',src,'CreatedAt',string(datetime('now')),'AlgorithmicallyIdentical',true);
                save(dst,'-struct','S','-v7.3');
                ok = true; message = 'copied-and-relabeled';
            end
        catch ME
            message = string(ME.message);
        end
        rows(k,:) = {scenario,runId,sourceMethod,targetMethod,string(src),string(dst),ok};
        if ~ok,warning('DA_MOVWO:SeedAlias','%s',message);end
    end
end

if exist(sourcePoolDir,'dir') == 7
    files = dir(fullfile(sourcePoolDir,'*.mat'));
    for i = 1:numel(files)
        src = fullfile(files(i).folder,files(i).name);
        dst = fullfile(targetPoolDir,files(i).name);
        if exist(dst,'file') ~= 2,copyfile(src,dst,'f');end
    end
end
report = cell2table(rows,'VariableNames',{'Scenario','Run','SourceMethod','TargetMethod', ...
    'SourceTaskFile','TargetTaskFile','Success'});
writetable(report,fullfile(targetResultDir,'ALIASED_CONTROL_TASKS_AUDIT.csv'));
assert(all(report.Success),'DA_MOVWO:SeedAlias','One or more control tasks could not be seeded.');
end

function localEnsureDir(p)
if exist(p,'dir') ~= 7,mkdir(p);end
end