function outDir=RUN_EXACT6000_PROTOCOL(cfg)
%RUN_EXACT6000_PROTOCOL Isolated shared-init engine for the Exact-6000 suite.
% Copied into an isolated engine so new protocol work cannot alter
% Exact-2000 task code or its frozen output semantics.
% cfg.ParallelAxis optionally selects 'method' (default) or 'case'.

if nargin<1 || isempty(cfg),error('PDMOEAD:Exact6000:Config','A configuration struct is required.');end
localValidateBudgetConfig(cfg);
parallelAxis=localParallelAxis(cfg);
engineDir=fileparts(mfilename('fullpath'));
rootDir=fileparts(fileparts(fileparts(engineDir)));
assert(exist(fullfile(rootDir,'setup_lcad_paths.m'),'file') == 2, ...
    'PDMOEAD:Exact6000:Root','Cannot locate the project root from %s.',engineDir);
cd(rootDir); setup_lcad_paths(rootDir);
setappdata(0,'NAV_COST_MODE','physical_v2');
setappdata(0,'NAV_DISABLE_MODEL_PLOT',true);
if localCfg(cfg,'FastSearchValidation',false)
    setappdata(0,'NAV_SEARCH_FAST_VALIDATION',true);
elseif isappdata(0,'NAV_SEARCH_FAST_VALIDATION')
    rmappdata(0,'NAV_SEARCH_FAST_VALIDATION');
end
cleanup=onCleanup(@localCleanup); %#ok<NASGU>

outDir=fullfile(rootDir,'results',cfg.OutName);
taskDir=fullfile(outDir,'tasks'); poolDir=fullfile(outDir,'shared_pools');
if exist(taskDir,'dir')~=7,mkdir(taskDir);end
if exist(poolDir,'dir')~=7,mkdir(poolDir);end

unitSummary=RUN_CURRENT_PHYSICAL_MODEL_UNIT_TESTS();
writetable(unitSummary,fullfile(outDir,'unit_test_summary.csv'));
methods=string(cfg.Methods); methods=reshape(methods,1,[]);
scenarios=cfg.Scenarios; runs=cfg.Runs;
rows=cell(0,numel(fieldnames(localEmptyRow())));
workers=localCfg(cfg,'NumWorkers',1);
p=gcp('nocreate');
if workers>1
    if isempty(p)||p.NumWorkers~=workers
        if ~isempty(p),delete(p);end
        parpool('local',workers);
    end
elseif ~isempty(p)
    % A unit-test helper can leave a default parpool behind.  A runtime
    % experiment with one worker must not reuse it through parfor.
    delete(p);
end

if strcmp(parallelAxis,'case') && workers>1
    % One worker owns a complete Scenario/Run case.  It constructs the
    % deterministic pool once and then runs the configured method order
    % serially, avoiding nested parallel regions and pool re-broadcasts.
    cases=localFlattenCases(scenarios,runs,cfg.SeedBase);
    caseRows=cell(numel(cases),1);
    parfor caseIndex=1:numel(cases)
        caseRows{caseIndex}=localRunCase(cases(caseIndex),methods,poolDir,taskDir,cfg);
    end
    for caseIndex=1:numel(cases)
        blockRows=caseRows{caseIndex};
        for i=1:numel(methods)
            rows(end+1,:)=struct2cell(blockRows{i})'; %#ok<AGROW>
        end
    end
else
    for scenario=scenarios
        for runId=runs
            seed=cfg.SeedBase+scenario*100+runId;
            pool=localLoadOrBuildPool(scenario,seed,cfg.PoolSize,poolDir,cfg);
            blockRows=cell(numel(methods),1);
            orderedRows=cell(numel(methods),1);
            methodOrder=localMethodOrder(methods,scenario,runId,cfg);
            if workers>1
                parfor i=1:numel(methods)
                    methodIndex=methodOrder(i);
                    task=struct('Scenario',scenario,'Run',runId,'Method',methods(methodIndex), ...
                        'Seed',seed,'FELimit',cfg.FELimit,'PoolSize',numel(pool));
                    orderedRows{i}=localRunOne(task,pool,taskDir,cfg);
                end
            else
                for i=1:numel(methods)
                    methodIndex=methodOrder(i);
                    task=struct('Scenario',scenario,'Run',runId,'Method',methods(methodIndex), ...
                        'Seed',seed,'FELimit',cfg.FELimit,'PoolSize',numel(pool));
                    orderedRows{i}=localRunOne(task,pool,taskDir,cfg);
                end
            end
            for i=1:numel(methods)
                blockRows{methodOrder(i)}=orderedRows{i};
            end
            for i=1:numel(methods)
                rows(end+1,:)=struct2cell(blockRows{i})'; %#ok<AGROW>
            end
        end
    end
end

% Reinstall an optional benchmark terrain on the client before Q2/FDEP
% post-processing. Parallel workers install the same file independently in
% localSetTaskState, so all stages use one identical terrain and scenario.
localApplyTerrainOverride(cfg);
localApplyScenarioOverride(cfg);
raw=cell2table(rows,'VariableNames',fieldnames(localEmptyRow()));
localValidateCompletedExactRows(raw,cfg);
control=string(localCfg(cfg,'ControlMethod','PDMOEA/D'));
summary=localSummary(raw,logical(localCfg(cfg,'ExcludeParallelRuntimeFromSummary',true)));
paired=localPairedControl(raw,control);
writetable(raw,fullfile(outDir,[cfg.Prefix '_raw.csv']));
writetable(summary,fullfile(outDir,[cfg.Prefix '_summary.csv']));
writetable(paired,fullfile(outDir,[cfg.Prefix '_pairwise_vs_control.csv']));
save(fullfile(outDir,[cfg.Prefix '_results.mat']), ...
    'unitSummary','raw','summary','paired','cfg','control','-v7.3');

if logical(localCfg(cfg,'RunParetoExport',true))
    NAV_LCAD_ExportParetoQuality(outDir,fullfile(outDir,'pareto_quality'));
end
if logical(localCfg(cfg,'RunQ2',true))
    try
        NAV_Q2_ExportEvaluation(outDir,fullfile(outDir,'q2_evaluation_v3'), ...
            struct('RebuildReference',true,'ControlMethod',control));
    catch ME
        warning('PDMOEAD:Exact6000:Q2Postprocess','Q2 export failed after tasks completed: %s',ME.message);
    end
end
if logical(localCfg(cfg,'RunFDEP',true))
    try
        NAV_FDEPV2_ExportEvaluation(outDir,fullfile(outDir,'fdep_evaluation_v2'), ...
            struct('ControlMethod',control,'FixedCardinality',10, ...
                   'RebuildQ2Reference',false));
    catch ME
        warning('PDMOEAD:Exact6000:FDEPPostprocess','FDEP export failed after tasks completed: %s',ME.message);
    end
end
localWriteReadme(outDir,raw,summary,paired,cfg,control,methods);
disp(summary);disp(paired);
end

function order=localMethodOrder(methods,scenario,runId,cfg)
order=1:numel(methods);
if ~logical(localCfg(cfg,'RotateMethodOrder',false)) || numel(order)<2
    return;
end
shift=mod(double(scenario)+double(runId)-2,numel(order));
order=circshift(order,[0 shift]);
end

function cases=localFlattenCases(scenarios,runs,seedBase)
cases=repmat(struct('Scenario',NaN,'Run',NaN,'Seed',NaN),numel(scenarios)*numel(runs),1);
index=0;
for scenario=scenarios
    for runId=runs
        index=index+1;
        cases(index)=struct('Scenario',scenario,'Run',runId, ...
            'Seed',seedBase+scenario*100+runId);
    end
end
end

function blockRows=localRunCase(caseTask,methods,poolDir,taskDir,cfg)
pool=localLoadOrBuildPool(caseTask.Scenario,caseTask.Seed,cfg.PoolSize,poolDir,cfg);
orderedRows=cell(numel(methods),1);
methodOrder=localMethodOrder(methods,caseTask.Scenario,caseTask.Run,cfg);
for i=1:numel(methods)
    methodIndex=methodOrder(i);
    task=struct('Scenario',caseTask.Scenario,'Run',caseTask.Run, ...
        'Method',methods(methodIndex),'Seed',caseTask.Seed, ...
        'FELimit',cfg.FELimit,'PoolSize',numel(pool));
    orderedRows{i}=localRunOne(task,pool,taskDir,cfg);
end
blockRows=cell(numel(methods),1);
for i=1:numel(methods)
    blockRows{methodOrder(i)}=orderedRows{i};
end
end

function row=localRunOne(task,pool,taskDir,cfg)
row=localEmptyRow(); names=fieldnames(task);
for i=1:numel(names),row.(names{i})=task.(names{i});end
row.Method=string(task.Method);
token=regexprep(char(task.Method),'[^A-Za-z0-9]+','_');
taskFile=fullfile(taskDir,sprintf('S%d_R%02d_%s.mat',task.Scenario,task.Run,token));
row.TaskFile=string(taskFile);
if exist(taskFile,'file')==2
    loaded=false;
    try
        S=load(taskFile,'row');
        loaded=isfield(S,'row')&&isstruct(S.row)&&isscalar(S.row);
        if loaded,row=S.row;end
    catch ME
        if localRequireExactSearchFE(cfg)
            error('PDMOEAD:Exact6000:ExactSearchFEResumeUnreadable', ...
                'Exact-FE mode will not overwrite unreadable task file %s: %s', ...
                taskFile,ME.message);
        end
    end
    if loaded && isfield(row,'Success') && logical(row.Success)
        if localRequireExactSearchFE(cfg)
            localValidateExactResumeRow(row,task,taskFile);
        end
        fprintf('%s resume S%d R%d %-28s C=%.6g FE=%d\n', ...
            cfg.Prefix,row.Scenario,row.Run,row.Method,row.TotalCost,row.FEEvaluated);
        return;
    end
    fprintf('%s retry failed S%d R%d %s\n',cfg.Prefix,task.Scenario,task.Run,task.Method);
    % A failed resume row may carry its old diagnostic text into the new
    % attempt.  Start the retried task with a clean audit row.
    row=localEmptyRow();
    names=fieldnames(task);
    for i=1:numel(names),row.(names{i})=task.(names{i});end
    row.Method=string(task.Method);
    row.TaskFile=string(taskFile);
end

% Install the identical neutral pool before each method, then reset the
% method-local random stream.  Every algorithm therefore consumes the same
% ordered initial population under its own reproducible subsequent search.
localSetTaskState(task,pool,cfg);
rng(task.Seed,'twister');
params=struct();
t=tic;
fatalME=[];
try
    params=localParams(task.Method,task.Seed,cfg.Profile);
    params=localApplyMethodOverrides(params,cfg,task.Method);
    if localCfg(cfg,'StoreConvergenceHistory',false)
        params.StoreConvergenceHistory=true;
    end
    optimizer=localMethod(task.Method);
    [rep,best,history]=optimizer(params);
    row.RuntimeSec=toc(t);
    row.FEAttempted=double(getappdata(0,'NAV_FE_ATTEMPTED'));
    row.FEEvaluated=double(getappdata(0,'NAV_FE_EVALUATED'));
    if localRequireExactSearchFE(cfg)
        localAssertExactSearchFE(row,task);
    end
    if isappdata(0,'NAV_FE_LIMIT'),rmappdata(0,'NAV_FE_LIMIT');end
    model=CreateModel(task.Scenario);close all force;
    % The representative is rechecked with the physical verifier after the
    % FE counter is closed.  This post-search check never changes the fixed
    % search budget and prevents a reported route from relying on a proxy.
    [best,verifiedCost,info,rep]=localSelectExactFeasible([best;rep(:)],model);
    assert(info.IsFeasible && all(verifiedCost<=1), ...
        'No returned path passed exact continuous verification.');
    c=verifiedCost(:)';
    row.Success=true;row.Message="";row.F1=c(1);row.F2=c(2);row.F3=c(3);row.F4=c(4);
    row.TotalCost=sum(c);row.ArchiveSize=numel(rep);
    row.MinCollisionMarginM=info.Feasibility.MinCollisionMarginM;
    row.MinTerrainClearanceM=info.Feasibility.MinTerrainClearanceM;
    row.MaxTurnDeg=info.Feasibility.MaxTurnDeg;
    row.MaxClimbDeg=info.Feasibility.MaxClimbDeg;
    save(taskFile,'task','params','rep','best','history','verifiedCost','info','row');
catch ME
    row.RuntimeSec=toc(t);
    if isappdata(0,'NAV_FE_ATTEMPTED'),row.FEAttempted=double(getappdata(0,'NAV_FE_ATTEMPTED'));end
    if isappdata(0,'NAV_FE_EVALUATED'),row.FEEvaluated=double(getappdata(0,'NAV_FE_EVALUATED'));end
    row.Success=false;row.Message=string(getReport(ME,'basic','hyperlinks','off'));
    save(taskFile,'task','params','row','ME');
    if localRequireExactSearchFE(cfg) && ...
            strcmp(ME.identifier,'PDMOEAD:Exact6000:ExactSearchFEIncomplete')
        fatalME=ME;
    end
    firstLine=extractBefore(row.Message,newline);
    if ismissing(firstLine) || strlength(firstLine)==0
        firstLine=row.Message;
    end
    fprintf('%s ERROR S%d R%d %s: %s\n',cfg.Prefix,row.Scenario,row.Run,row.Method,firstLine);
end
fprintf('%s S%d R%d %-28s ok=%d C=%.6g FE=%d time=%.2fs\n', ...
    cfg.Prefix,row.Scenario,row.Run,row.Method,row.Success,row.TotalCost,row.FEEvaluated,row.RuntimeSec);
localClearTaskState();close all force;
if ~isempty(fatalME),rethrow(fatalME);end
end

function localSetTaskState(task,pool,cfg)
localClearTaskState();
localApplyTerrainOverride(cfg);
localApplyScenarioOverride(cfg);
setappdata(0,'NAV_COST_MODE','physical_v2');
setappdata(0,'NAV_DISABLE_MODEL_PLOT',true);
if localCfg(cfg,'FastSearchValidation',false),setappdata(0,'NAV_SEARCH_FAST_VALIDATION',true);end
setappdata(0,'NAV_SCENARIO_ID',task.Scenario);
setappdata(0,'NAV_SHARED_INIT_POOL',pool);
setappdata(0,'NAV_SHARED_INIT_CURSOR',1);
setappdata(0,'NAV_FE_LIMIT',task.FELimit);
setappdata(0,'NAV_FE_ATTEMPTED',0);
setappdata(0,'NAV_FE_EVALUATED',0);
end

function [best,cost,info,exactPool]=localSelectExactFeasible(pool,model)
vmin=NAV_NavigationBounds(model);best=[];cost=inf(4,1);info=struct('IsFeasible',false);
bestTotal=inf;exactPool=pool([]);
for i=1:numel(pool)
    if isempty(pool(i).Position),continue;end
    [c,q]=NAV_MyCost_PhysicalV2(pool(i).Position,model,vmin);
    if q.IsFeasible
        candidate=pool(i);candidate.Cost=c(:);exactPool(end+1,1)=candidate; %#ok<AGROW>
        if sum(c(1:4))<bestTotal,best=candidate;cost=c;info=q;bestTotal=sum(c(1:4));end
    end
end
end

function pool=localLoadOrBuildPool(scenario,seed,nPool,poolDir,cfg)
protocol=char(localCfg(cfg,'InitProtocol','N30G200-NEUTRAL-SHARED30-V1'));
poolFile=fullfile(poolDir,sprintf('S%d_seed%d.mat',scenario,seed));
if exist(poolFile,'file')==2
    try
        S=load(poolFile,'pool','poolProtocol','poolAudit');
        valid=isfield(S,'pool')&&numel(S.pool)==nPool&& ...
            isfield(S,'poolProtocol')&&strcmp(char(S.poolProtocol),protocol)&& ...
            isfield(S,'poolAudit')&&logical(S.poolAudit.PassNeutralGate);
        if valid,pool=S.pool;return;end
    catch
    end
end
localClearTaskState();localApplyTerrainOverride(cfg);
localApplyScenarioOverride(cfg);
setappdata(0,'NAV_SCENARIO_ID',scenario);rng(seed,'twister');
model=CreateModel(scenario);close all force;[vmin,vmax]=NAV_NavigationBounds(model);
varSize=[1 model.n];costFunction=@(x)MyCost(x,model,vmin);
p=localBaseParams(seed);p.initMaxTry=55;p.guidedInitRatio=0.70;
opts=NAV_EXACT6000_NeutralOptions();
initOverrides=localCfg(cfg,'NeutralInitOptions',struct());
if isstruct(initOverrides)
    overrideNames=fieldnames(initOverrides);
    for oi=1:numel(overrideNames)
        opts.(overrideNames{oi})=initOverrides.(overrideNames{oi});
    end
end
opts.Protocol=protocol;opts.MinUnique=nPool;
opts.RequireFullUnique=true;opts.ActiveCount=nPool;opts.RequireNeutralGate=true;
[pool,vectors,costs,poolAudit]=NAV_BuildNeutralSharedInitialPool( ...
    model,varSize,vmin,vmax,costFunction,p,nPool,opts);
assert(poolAudit.UniqueSelected==nPool && poolAudit.PassNeutralGate, ...
    'Exact-6000 shared initialization failed the %d/%d neutral gate.',nPool,nPool);
poolProtocol=protocol; %#ok<NASGU>
save(poolFile,'scenario','seed','pool','vectors','costs','poolAudit','poolProtocol');
fprintf('%s pool S%d seed%d: %d/%d unique | bank=%d gate=%d\n', ...
    cfg.Prefix,scenario,seed,poolAudit.UniqueSelected,nPool, ...
    poolAudit.CandidateBankSize,poolAudit.PassNeutralGate);
end

function params=localParams(method,seed,profile)
params=localBaseParams(seed);key=upper(char(method));
if strcmpi(profile,'FINAL-SO')
    error('PDMOEAD:RetiredProfile', ...
        'The retired FINAL-SO profile is not part of the retained paper code.');
end
params.nPop=24;params.nRep=36;
if strcmp(key,'NMOPSO')
    params.MaxIt=66;
elseif strcmp(key,'MOGWO')
    % Historical Exact-2000 compatibility only; not a current Main-5 method.
    params.MaxIt=83;
elseif strcmp(key,'MOEA/D-DE')
    params.MaxIt=52;
elseif ismember(key,{'PDMOEA/D','MOEA/D-AWA','MOEA-2DE'}) || ...
        startsWith(key,'PBA-DQRF-DIVERSE-DFE')
    params.MaxIt=83;
elseif strcmp(key,'ECDE-2025')
    params.MaxIt=100;
elseif ismember(key,{'SPEA2','MOEA/D','NSGA-III'})
    params.MaxIt=52;
else
    error('PDMOEAD:RetiredOrUnknownMethod', ...
        'Method %s is not in the retained paper registry.',method);
end
end
function p=localBaseParams(seed)
p=struct('MaxIt',25,'nPop',16,'nRep',24,'nGrid',7,'alpha',0.1, ...
    'beta',2,'gamma',2,'delta',5,'fixMutation',true, ...
    'usePaperMutationGain',true,'table1Weights',[1 1 1 1], ...
    'reportWeights',[1 1 1 1],'verbose',false,'Seed',seed);
p=NAV_DefaultParams(p);
end

function params=localApplyMethodOverrides(params,cfg,method)
if ~isfield(cfg,'ParamOverrides')||isempty(cfg.ParamOverrides),return;end
key=matlab.lang.makeValidName(char(method));
if ~isfield(cfg.ParamOverrides,key)||isempty(cfg.ParamOverrides.(key)),return;end
override=cfg.ParamOverrides.(key);names=fieldnames(override);
for i=1:numel(names),params.(names{i})=override.(names{i});end
end

function f=localMethod(method)
f=NAV_PaperMethodHandle(method);
end

function T=localSummary(raw,excludeRuntime)
x=raw(raw.Success,:);methods=unique(x.Method,'stable');rows=cell(0,11);
for i=1:numel(methods)
    q=x(x.Method==methods(i),:);
    rows(end+1,:)={methods(i),height(q),mean(q.TotalCost),std(q.TotalCost), ...
        mean(q.F1),mean(q.F2),mean(q.F3),mean(q.F4), ...
        mean(q.FEEvaluated),mean(q.RuntimeSec),mean(q.ArchiveSize)}; %#ok<AGROW>
end
T=cell2table(rows,'VariableNames',{'Method','N','MeanTotalCost','StdTotalCost', ...
    'MeanF1','MeanF2','MeanF3','MeanF4','MeanFE','MeanRuntimeSec','MeanArchiveSize'});
if excludeRuntime,T.MeanRuntimeSec=[];end
T=sortrows(T,'MeanTotalCost','ascend');
end

function T=localPairedControl(raw,control)
x=raw(raw.Success,:);a=x(x.Method==control,:);methods=unique(x.Method,'stable');rows=cell(0,6);
for i=1:numel(methods)
    if methods(i)==control,continue;end
    b=x(x.Method==methods(i),:);d=[];
    for j=1:height(a)
        k=find(b.Scenario==a.Scenario(j)&b.Run==a.Run(j),1);
        if ~isempty(k),d(end+1,1)=a.TotalCost(j)-b.TotalCost(k);end %#ok<AGROW>
    end
    rows(end+1,:)={methods(i),numel(d),mean(d),sum(d<0),sum(abs(d)<=1e-12),sum(d>0)}; %#ok<AGROW>
end
T=cell2table(rows,'VariableNames',{'Baseline','N','MeanControlMinusBaseline', ...
    'ControlWins','Ties','ControlLosses'});
end

function row=localEmptyRow()
row=struct('Scenario',NaN,'Run',NaN,'Method',string(''),'Seed',NaN,'FELimit',NaN, ...
    'PoolSize',NaN,'Success',false,'F1',NaN,'F2',NaN,'F3',NaN,'F4',NaN, ...
    'TotalCost',NaN,'ArchiveSize',NaN,'FEEvaluated',NaN,'FEAttempted',NaN, ...
    'RuntimeSec',NaN,'MinCollisionMarginM',NaN,'MinTerrainClearanceM',NaN, ...
    'MaxTurnDeg',NaN,'MaxClimbDeg',NaN,'Message',string(''),'TaskFile',string(''));
end

function localWriteReadme(outDir,raw,summary,paired,cfg,control,methods)
fid=fopen(fullfile(outDir,'README.md'),'w');if fid<0,return;end
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# %s final experiment\n\n',cfg.Prefix);
fprintf(fid,'- Control method: %s.\n',control);
fprintf(fid,'- Methods (%d): %s.\n',numel(methods),strjoin(cellstr(methods),', '));
fprintf(fid,'- Scenarios: %s; runs: %s.\n',mat2str(cfg.Scenarios),mat2str(cfg.Runs));
if isinf(double(cfg.FELimit))
    fprintf(fid,'- Search-FE target: Inf (uncapped).\n');
else
    fprintf(fid,'- Search-FE target: %g.\n',double(cfg.FELimit));
end
if localRequireExactSearchFE(cfg)
    fprintf(fid,'- Search-FE budget protocol: %s.\n',char(string(cfg.BudgetProtocol)));
    fprintf(fid,['- Exact-search-FE enforcement: every successful task has ' ...
        'FELimit = FEEvaluated = FEAttempted = %g.\n'],double(cfg.FELimit));
elseif isinf(double(cfg.FELimit))
    fprintf(fid,'- Search-FE budget protocol: uncapped; actual FE is reported per task.\n');
else
    fprintf(fid,'- Search-FE budget protocol: finite cap (exact exhaustion not required).\n');
end
fprintf(fid,'- Shared initialization: exactly %d/%d unique feasible paths in identical order.\n',cfg.PoolSize,cfg.PoolSize);
fprintf(fid,'- Initialization protocol: %s.\n',char(string(localCfg(cfg,'InitProtocol','N30G200-NEUTRAL-SHARED30-V1'))));
fprintf(fid,'- Search objectives remain NMOPSO-aligned F1-F4.\n');
fprintf(fid,'- FDEP V2 reports NMOPSO compatibility, fair Pareto quality and deployment-path quality.\n');
fprintf(fid,'- Successful tasks: %d/%d.\n\n',sum(raw.Success),height(raw));
fprintf(fid,'```text\n%s\n%s\n```\n',evalc('disp(summary)'),evalc('disp(paired)'));
end

function localValidateBudgetConfig(cfg)
if ~localRequireExactSearchFE(cfg),return;end
expectedLimit=double(localCfg(cfg,'FELimit',NaN));
expectedProtocol=string(sprintf('SEARCH-FE-EXACT-%d-V1',expectedLimit));
validLimit=isfield(cfg,'FELimit')&&isnumeric(cfg.FELimit)&&isscalar(cfg.FELimit)&& ...
    isfinite(cfg.FELimit)&&expectedLimit>=1&&expectedLimit==floor(expectedLimit);
if ~validLimit
    error('PDMOEAD:Exact6000:ExactSearchFEConfig', ...
        'Exact-search-FE mode requires a positive integer finite cfg.FELimit.');
end
validProtocol=isfield(cfg,'BudgetProtocol')&&isscalar(string(cfg.BudgetProtocol))&& ...
    string(cfg.BudgetProtocol)==expectedProtocol;
if ~validProtocol
    error('PDMOEAD:Exact6000:ExactSearchFEProtocol', ...
        'Exact-search-FE mode requires BudgetProtocol = %s.',expectedProtocol);
end
end

function axis=localParallelAxis(cfg)
value=localCfg(cfg,'ParallelAxis','method');
value=string(value);
if ~isscalar(value)
        error('PDMOEAD:Exact6000:ParallelAxis','ParallelAxis must be a scalar string or character vector.');
end
axis=lower(char(value));
if ~ismember(axis,{'method','case'})
    error('PDMOEAD:Exact6000:ParallelAxis', ...
        'ParallelAxis must be ''method'' (default) or ''case''; received %s.',axis);
end
end

function tf=localRequireExactSearchFE(cfg)
value=localCfg(cfg,'RequireExactSearchFE',false);
if ~(isscalar(value)&&(islogical(value)||isnumeric(value)))
    error('PDMOEAD:Exact6000:ExactSearchFEFlag', ...
        'RequireExactSearchFE must be a scalar logical value.');
end
tf=logical(value);
end

function localValidateExactResumeRow(row,task,taskFile)
expectedLimit=double(task.FELimit);
validFields=isfield(row,'FELimit')&&isfield(row,'FEEvaluated')&& ...
    isfield(row,'FEAttempted');
validValues=validFields&&isnumeric(row.FELimit)&&isscalar(row.FELimit)&& ...
    isnumeric(row.FEEvaluated)&&isscalar(row.FEEvaluated)&& ...
    isnumeric(row.FEAttempted)&&isscalar(row.FEAttempted)&& ...
    isfinite(row.FELimit)&&isfinite(row.FEEvaluated)&&isfinite(row.FEAttempted)&& ...
    double(row.FELimit)==expectedLimit&&double(row.FEEvaluated)==expectedLimit&& ...
    double(row.FEAttempted)==expectedLimit&& ...
    double(task.FELimit)==expectedLimit;
if ~validValues
    oldLimit=localNumericFieldText(row,'FELimit');
    oldEvaluated=localNumericFieldText(row,'FEEvaluated');
    oldAttempted=localNumericFieldText(row,'FEAttempted');
    error('PDMOEAD:Exact6000:ExactSearchFEIncompatibleResume', ...
        ['Exact-search-FE mode refuses to resume or overwrite successful task %s. ' ...
         'Required FELimit=FEEvaluated=FEAttempted=%d; stored FELimit=%s, ' ...
         'FEEvaluated=%s, FEAttempted=%s.'], ...
        taskFile,expectedLimit,oldLimit,oldEvaluated,oldAttempted);
end
end

function localAssertExactSearchFE(row,task)
expectedLimit=double(task.FELimit);
valid=isnumeric(task.FELimit)&&isscalar(task.FELimit)&& ...
    isnumeric(row.FEEvaluated)&&isscalar(row.FEEvaluated)&& ...
    isnumeric(row.FEAttempted)&&isscalar(row.FEAttempted)&& ...
    isfinite(task.FELimit)&&isfinite(row.FEEvaluated)&&isfinite(row.FEAttempted)&& ...
    double(task.FELimit)==expectedLimit&& ...
    double(row.FEEvaluated)==double(task.FELimit)&& ...
    double(row.FEAttempted)==double(task.FELimit);
if ~valid
    error('PDMOEAD:Exact6000:ExactSearchFEIncomplete', ...
        ['Exact-search-FE task S%d R%d %s ended at evaluated=%g, attempted=%g, ' ...
         'target=%g FE; the task is invalid and cannot be reported as successful.'], ...
        task.Scenario,task.Run,char(string(task.Method)), ...
        double(row.FEEvaluated),double(row.FEAttempted),double(task.FELimit));
end
end

function localValidateCompletedExactRows(raw,cfg)
if ~localRequireExactSearchFE(cfg)||isempty(raw),return;end
success=logical(raw.Success);
target=double(cfg.FELimit);
valid=raw.FELimit==target&raw.FEEvaluated==target&raw.FEAttempted==target;
if any(success&~valid)
    error('PDMOEAD:Exact6000:ExactSearchFEPostcondition', ...
        ['%d successful task(s) violate ' ...
         'FELimit = FEEvaluated = FEAttempted = %g.'], ...
        sum(success&~valid),target);
end
end

function value=localNumericFieldText(s,name)
value="missing";
if isstruct(s)&&isfield(s,name)&&isnumeric(s.(name))&&isscalar(s.(name))
    value=string(sprintf('%.15g',double(s.(name))));
end
value=char(value);
end

function value=localCfg(cfg,name,defaultValue)
if isstruct(cfg)&&isfield(cfg,name)&&~isempty(cfg.(name)),value=cfg.(name);else,value=defaultValue;end
end
function localApplyTerrainOverride(cfg)
terrainFile=string(localCfg(cfg,'TerrainFileOverride',""));
if strlength(terrainFile)==0,return;end
terrainFile=char(terrainFile);
if exist(terrainFile,'file')~=2
    error('PDMOEAD:Exact6000:MissingTerrainOverride','Terrain override file is missing: %s',terrainFile);
end
setappdata(0,'NAV_TERRAIN_FILE_OVERRIDE',terrainFile);
end
function localApplyScenarioOverride(cfg)
scenarioFile=string(localCfg(cfg,'ScenarioOverrideFile',""));
if strlength(scenarioFile)==0,return;end
scenarioFile=char(scenarioFile);
if exist(scenarioFile,'file')~=2
    error('PDMOEAD:Exact6000:MissingScenarioOverride', ...
        'Scenario override file is missing: %s',scenarioFile);
end
setappdata(0,'NAV_SCENARIO_OVERRIDE_FILE',scenarioFile);
end
function localClearTaskState()
keys={'NAV_COST_MODE','NAV_DISABLE_MODEL_PLOT','NAV_SCENARIO_ID','NAV_SEARCH_FAST_VALIDATION', ...
    'NAV_SHARED_INIT_POOL','NAV_SHARED_INIT_CURSOR','NAV_FE_LIMIT','NAV_FE_ATTEMPTED','NAV_FE_EVALUATED', ...
    'NAV_TERRAIN_FILE_OVERRIDE','NAV_SCENARIO_OVERRIDE_FILE'};
for i=1:numel(keys),try,if isappdata(0,keys{i}),rmappdata(0,keys{i});end,catch,end,end
end
function localCleanup(),localClearTaskState();close all force;end
