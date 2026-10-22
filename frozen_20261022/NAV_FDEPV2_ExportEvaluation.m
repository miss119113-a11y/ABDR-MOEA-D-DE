function outDir = NAV_FDEPV2_ExportEvaluation(formalDir,outDir,cfg)
%NAV_FDEPV2_EXPORTEVALUATION Unified offline multi-objective UAV evaluation.
%
% FDEP has three layers:
% 1) Compatibility: F1-F4 archive Max/Min/Mean/Std and NMOPSO sd=np/no.
% 2) Fair set quality: fixed-reference HV, frozen-front IGD+, fixed K=10,
%    and a common [0,1]^4 grid shared by every algorithm.
% 3) Deployment: exact continuous feasibility, safety-buffer eligibility,
%    the protocol-frozen DeploymentAugTchebyRawV1 representative, and
%    physical route metrics including worst local risk and turn/climb
%    percentiles.
%
% This function is evaluation-only. It never changes search objectives,
% candidate archives, random streams or FE accounting.

if nargin<1 || isempty(formalDir)
    error('NAV_FDEPV2_ExportEvaluation:FormalDir','formalDir is required.');
end
if nargin<2 || isempty(outDir)
    outDir=fullfile(formalDir,'fdep_evaluation_v2');
end
if nargin<3 || isempty(cfg),cfg=struct();end
cfg=localDefaults(cfg);
if exist(outDir,'dir')~=7,mkdir(outDir);end
deploymentDir=fullfile(outDir,'deployment_paths');
if exist(deploymentDir,'dir')~=7,mkdir(deploymentDir);end

[q2Dir,q2File,explicitQ2Source]=localResolveQ2Source(formalDir,cfg);
if explicitQ2Source
    assert(~cfg.RebuildQ2Reference, ...
        'NAV_FDEPV2_ExportEvaluation:ExplicitQ2IsReadOnly', ...
        ['RebuildQ2Reference cannot be used with Q2EvaluationDir or ' ...
         'Q2EvaluationFile. Explicit Q2 evaluation inputs are read-only.']);
    assert(exist(q2File,'file')==2, ...
        'NAV_FDEPV2_ExportEvaluation:ExplicitQ2Missing', ...
        'The requested Q2 evaluation file does not exist: %s',q2File);
elseif exist(q2File,'file')~=2 || cfg.RebuildQ2Reference
    NAV_Q2_ExportEvaluation(formalDir,q2Dir, ...
        struct('RebuildReference',logical(cfg.RebuildQ2Reference), ...
        'ControlMethod',cfg.ControlMethod));
end
cfg.Q2EvaluationResolvedFile=string(q2File);
Q=load(q2File,'T','refs');
assert(isfield(Q,'T') && isfield(Q,'refs'), ...
    'NAV_FDEPV2_ExportEvaluation:Q2Missing','Q2 evaluation output is incomplete.');

files=dir(fullfile(formalDir,'tasks','*.mat'));
assert(~isempty(files),'NAV_FDEPV2_ExportEvaluation:NoTasks','No task MAT files found.');

compatRows=cell(0,numel(localCompatibilityNames()));
setRows=cell(0,numel(localSetNames()));
repRows=cell(0,numel(localRepresentativeNames()));

for fi=1:numel(files)
    taskFile=fullfile(files(fi).folder,files(fi).name);
    try
        S=load(taskFile);
        [scenario,runId,method]=localTaskMeta(S,files(fi).name);
        if ~isfinite(scenario) || ~isfinite(runId) || strlength(method)==0
            continue;
        end
        candidates=localCandidatePool(S);
        if isempty(candidates),continue;end

        setappdata(0,'NAV_DISABLE_MODEL_PLOT',true);
        model=CreateModel(scenario);
        close all force;
        [vmin,~]=NAV_NavigationBounds(model);
        A=localEvaluateArchive(candidates,model,vmin,cfg);
        if isempty(A.Costs),continue;end
        ref=Q.refs([Q.refs.Scenario]==scenario);
        assert(numel(ref)==1,'FDEP:Reference','Missing or duplicate Q2 reference for S%d.',scenario);

        [compatRow,setRow,taskRepRows,deploymentSelection]=localEvaluateOne( ...
            scenario,runId,method,taskFile,A,ref,Q.T,cfg);
        compatRows(end+1,:)=compatRow; %#ok<AGROW>
        setRows(end+1,:)=setRow; %#ok<AGROW>
        repRows=[repRows;taskRepRows]; %#ok<AGROW>
        token=regexprep(char(method),'[^A-Za-z0-9]+','_');
        deploymentFile=fullfile(deploymentDir,sprintf( ...
            'S%d_R%02d_%s.mat',scenario,runId,token));
        save(deploymentFile,'deploymentSelection');
    catch ME
        warning('ARCMOVWO:FDEP:SkipTask','Skip %s: %s',files(fi).name,ME.message);
    end
end
localRemoveAppdata('NAV_DISABLE_MODEL_PLOT');

assert(~isempty(compatRows),'NAV_FDEPV2_ExportEvaluation:NoValidTasks', ...
    'No task could be evaluated.');

C=cell2table(compatRows,'VariableNames',localCompatibilityNames());
P=cell2table(setRows,'VariableNames',localSetNames());
R=cell2table(repRows,'VariableNames',localRepresentativeNames());
C=sortrows(C,{'Scenario','Run','Method'});
P=sortrows(P,{'Scenario','Run','Method'});
R=sortrows(R,{'Scenario','Run','Method','Rule'});

writetable(C,fullfile(outDir,'fdep_nmopso_compatibility_per_run.csv'));
writetable(P,fullfile(outDir,'fdep_fair_set_quality_per_run.csv'));
writetable(R,fullfile(outDir,'fdep_representative_paths_per_run.csv'));

CS=localCompatibilitySummary(C);
PS=localSetSummary(P);
RS=localRepresentativeSummary(R);
CSByScenario=localCompatibilitySummaryByScenario(C);
PSByScenario=localSetSummaryByScenario(P);
RSByScenario=localRepresentativeSummary(R,true);
PW=localDeploymentPairwise(R,cfg);
writetable(CS,fullfile(outDir,'fdep_nmopso_compatibility_summary.csv'));
writetable(PS,fullfile(outDir,'fdep_fair_set_quality_summary.csv'));
writetable(RS,fullfile(outDir,'fdep_representative_summary.csv'));
writetable(CSByScenario,fullfile(outDir,'fdep_nmopso_compatibility_summary_by_scenario.csv'));
writetable(PSByScenario,fullfile(outDir,'fdep_fair_set_quality_summary_by_scenario.csv'));
writetable(RSByScenario,fullfile(outDir,'fdep_representative_summary_by_scenario.csv'));
writetable(PW,fullfile(outDir,'fdep_deployment_pairwise_vs_control.csv'));

matFile = fullfile(outDir,'fdep_evaluation.mat');
try
    save(matFile, ...
        'C','P','R','CS','PS','RS','CSByScenario','PSByScenario', ...
        'RSByScenario','PW','cfg','-v7.3');
catch ME
    % Some Windows MATLAB/HDF5 combinations fail on this table bundle even
    % though every CSV export is valid. Keep the same variables and fall
    % back to the classic MAT container so the audit artifact is nonempty.
    if exist(matFile,'file')==2, delete(matFile); end
    warning('NAV_FDEPV2:MatSaveFallback', ...
        'v7.3 MAT save failed (%s); retrying with -v7.',ME.message);
    save(matFile, ...
        'C','P','R','CS','PS','RS','CSByScenario','PSByScenario', ...
        'RSByScenario','PW','cfg','-v7');
end
localWriteProtocol(outDir,formalDir,cfg,C,P,R,PS,RS);
fprintf('[FDEP] Completed: %s\n',outDir);
end

function cfg=localDefaults(cfg)
if isfield(cfg,'ConservativeMinSafetyMarginM') && ...
        (~isfield(cfg,'StrictMinSafetyMarginM') || isempty(cfg.StrictMinSafetyMarginM))
    cfg.StrictMinSafetyMarginM=cfg.ConservativeMinSafetyMarginM;
end
d=struct( ...
    'ProtocolVersion','MO-UAV-EVAL-V1.0', ...
    'RepresentativeRuleID','DeploymentAugTchebyRawV1', ...
    'ControlMethod','ARCMOVWO', ...
    'RebuildQ2Reference',false, ...
    'Q2EvaluationDir','', ...
    'Q2EvaluationFile','', ...
    'LocalGridDivisions',7, ...
    'CommonGridDivisions',7, ...
    'FixedCardinality',10, ...
    'AugmentedTchebyRho',0.05, ...
    'PreferredMinSafetyMarginM',0, ...
    'StrictMinSafetyMarginM',2, ...
    'PreferredP95TurnDeg',30, ...
    'PreferredP95ClimbDeg',15, ...
    'TieTolerance',1e-10, ...
    'Alpha',0.05, ...
    'ExactSignedRankMaxN',22);
f=fieldnames(d);
for i=1:numel(f)
    if ~isfield(cfg,f{i}) || isempty(cfg.(f{i})),cfg.(f{i})=d.(f{i});end
end
% V1 formal deployment definitions are frozen, not caller-tunable.
cfg.ProtocolVersion='MO-UAV-EVAL-V1.0';
cfg.RepresentativeRuleID='DeploymentAugTchebyRawV1';
cfg.AugmentedTchebyRho=0.05;
cfg.PreferredMinSafetyMarginM=0;
cfg.StrictMinSafetyMarginM=2;
cfg.PreferredP95TurnDeg=30;
cfg.PreferredP95ClimbDeg=15;
cfg.TieTolerance=1e-10;
cfg.Alpha=0.05;
end

function [q2Dir,q2File,isExplicit]=localResolveQ2Source(formalDir,cfg)
hasDir=strlength(string(cfg.Q2EvaluationDir))>0;
hasFile=strlength(string(cfg.Q2EvaluationFile))>0;
assert(~(hasDir && hasFile), ...
    'NAV_FDEPV2_ExportEvaluation:AmbiguousQ2Source', ...
    'Specify only one of cfg.Q2EvaluationDir and cfg.Q2EvaluationFile.');
isExplicit=hasDir || hasFile;
if hasFile
    q2File=char(string(cfg.Q2EvaluationFile));
    q2Dir=fileparts(q2File);
elseif hasDir
    q2Dir=char(string(cfg.Q2EvaluationDir));
    q2File=fullfile(q2Dir,'q2_evaluation.mat');
else
    q2Dir=fullfile(formalDir,'q2_evaluation_v3');
    q2File=fullfile(q2Dir,'q2_evaluation.mat');
end
end

function A=localEvaluateArchive(pool,model,vmin,cfg)
costs=zeros(0,4);items=pool([]);geoms=repmat(localEmptyGeometry(),0,1);
for i=1:numel(pool)
    if ~isfield(pool(i),'Position') || isempty(pool(i).Position),continue;end
    [c,info]=NAV_MyCost_PhysicalV2(pool(i).Position,model,vmin);
    c=double(c(:)');
    if numel(c)<4 || any(~isfinite(c(1:4))) || any(c(1:4)<-1e-9) || ...
            any(c(1:4)>1+1e-9) || ~info.IsFeasible
        continue;
    end
    candidate=pool(i);candidate.Cost=c(1:4)';
    costs(end+1,:)=c(1:4); %#ok<AGROW>
    items(end+1,1)=candidate; %#ok<AGROW>
    geoms(end+1,1)=localGeometry(info,model,cfg); %#ok<AGROW>
end
if isempty(costs)
    A=struct('Costs',zeros(0,4),'Items',items,'Geometry',geoms);return;
end
[costs,ia]=localUniqueTol(costs,1e-12);
items=items(ia);geoms=geoms(ia);
keep=localNondominatedMask(costs,1e-12);
A=struct('Costs',costs(keep,:),'Items',items(keep),'Geometry',geoms(keep));
end

function G=localGeometry(info,model,cfg)
V=info.Feasibility;
turn=abs(double(localField(V,'TurnDeg',[])));
climb=abs(double(localField(V,'ClimbDeg',[])));
xyz=double(info.Path.AbsoluteM);
dz=diff(xyz(:,3));
safetyDist=double(localField(model,'SafetyDistM',50));
minCollision=double(info.MinCollisionMarginM);
minSafety=double(info.MinSafetyMarginM);
worstRisk=max(0,min(1,1-minCollision/max(safetyDist,eps)));
softRate=double(info.SoftThreatSegmentCount)/max(1,double(info.ThreatSegmentPairCount));
requiredClear=double(localField(V,'RequiredMinTerrainClearanceM',0));
terrainReserve=double(V.MinTerrainClearanceM)-requiredClear;
p95Turn=localPercentile(turn,95);
p95Climb=localPercentile(climb,95);
geometryValid=isfinite(minSafety) && isfinite(p95Turn) && isfinite(p95Climb) && ...
    isfinite(safetyDist) && safetyDist>0;
eligible=logical(info.IsFeasible) && geometryValid && ...
    minSafety>=cfg.PreferredMinSafetyMarginM && ...
    p95Turn<=cfg.PreferredP95TurnDeg && p95Climb<=cfg.PreferredP95ClimbDeg;
strict2mEligible=logical(info.IsFeasible) && geometryValid && ...
    minSafety>=cfg.StrictMinSafetyMarginM && ...
    p95Turn<=cfg.PreferredP95TurnDeg && p95Climb<=cfg.PreferredP95ClimbDeg;
if geometryValid
    vop=max(0,-minSafety/safetyDist) + ...
        0.25*max(0,p95Turn/cfg.PreferredP95TurnDeg-1) + ...
        0.25*max(0,p95Climb/cfg.PreferredP95ClimbDeg-1);
else
    vop=Inf;
end
G=struct( ...
    'OperationalEligible',eligible, ...
    'Strict2mEligible',strict2mEligible, ...
    'ConservativeEligible',strict2mEligible, ...
    'OperationalViolationVop',vop, ...
    'SafetyDistM',safetyDist, ...
    'PathLengthM',double(info.PathLengthM), ...
    'Tortuosity',double(info.PathLengthM)/max(double(info.StraightLengthM),eps), ...
    'MinCollisionMarginM',double(info.MinCollisionMarginM), ...
    'MinSafetyMarginM',minSafety, ...
    'WorstPairRisk',worstRisk, ...
    'SoftThreatPairRate',softRate, ...
    'MinTerrainClearanceM',double(V.MinTerrainClearanceM), ...
    'TerrainReserveM',terrainReserve, ...
    'MeanTurnDeg',localMean(turn), ...
    'P95TurnDeg',p95Turn, ...
    'MaxTurnDeg',localMax(turn), ...
    'MeanClimbDeg',localMean(climb), ...
    'P95ClimbDeg',p95Climb, ...
    'MaxClimbDeg',localMax(climb), ...
    'TotalAscentM',sum(max(0,dz),'omitnan'), ...
    'TotalDescentM',sum(max(0,-dz),'omitnan'));
end

function [compatRow,setRow,repRows,deploymentSelection]=localEvaluateOne(sc,runId,method,taskFile,A,ref,Q2T,cfg)
C=A.Costs;
np=size(C,1);
N=(C-ref.Ideal)./ref.Span;
[localSD,localOccupied]=NAV_Q2_GridDistribution(C,cfg.LocalGridDivisions);
common=NAV_FDEPV2_CommonGrid(N,cfg.CommonGridDivisions);
stats=[min(C,[],1),max(C,[],1),mean(C,1,'omitnan'),std(C,0,1,'omitnan')];

compatRow={sc,runId,string(method),np,localOccupied,localSD, ...
    common.OccupiedCells,common.Redundancy,common.Efficiency,common.GlobalCoverage};
compatRow=[compatRow,num2cell(stats),{string(taskFile)}];

qix=Q2T.Scenario==sc & Q2T.Run==runId & Q2T.Method==string(method);
assert(sum(qix)==1,'FDEP:Q2Match','No unique Q2 row for S%d R%d %s.',sc,runId,method);
q=Q2T(qix,:);

k=cfg.FixedCardinality;
if np>=k
    idx=NAV_Q2_FarthestSubset(N,k);
    commonK=NAV_FDEPV2_CommonGrid(N(idx,:),cfg.CommonGridDivisions);
    kValid=true;
else
    commonK=struct('OccupiedCells',NaN,'Redundancy',NaN,'Efficiency',NaN);
    kValid=false;
end
setRow={sc,runId,string(method),np, ...
    q.HVExactRaw,q.HVExactRawRatio,q.IGDPlusNorm,q.EpsilonPlusNorm, ...
    q.SpacingL1Norm,q.SpreadNNCVNorm, ...
    common.OccupiedCells,common.Redundancy,common.Efficiency, ...
    commonK.OccupiedCells,commonK.Redundancy,commonK.Efficiency,kValid, ...
    localTableValue(q,sprintf('HVExactRaw_K%d',k)), ...
    localTableValue(q,sprintf('IGDPlusNorm_K%d',k)),string(taskFile)};

[repRows,deploymentSelection]=localRepresentativeRows(sc,runId,method,taskFile,A,ref,cfg);
end

function [rows,deploymentSelection]=localRepresentativeRows(sc,runId,method,taskFile,A,ref,cfg)
C=A.Costs;N=(C-ref.Ideal)./ref.Span;
paper=sum(C,2);
fairTcheby=max(N,[],2)+cfg.AugmentedTchebyRho*sum(N,2);
rawTcheby=max(C,[],2)+cfg.AugmentedTchebyRho*sum(C,2);
[~,iPaper]=min(paper);
[~,iFair]=min(fairTcheby);
eligible=[A.Geometry.OperationalEligible]';
strict2m=[A.Geometry.Strict2mEligible]';
vop=[A.Geometry.OperationalViolationVop]';
archiveOperational=any(eligible);
archiveStrict2m=any(strict2m);
if any(eligible)
    iDeploy=localSelectDeployment(find(eligible),vop,rawTcheby,C,A.Geometry,false,cfg);
    fallback=false;
else
    iDeploy=localSelectDeployment((1:size(C,1))',vop,rawTcheby,C,A.Geometry,true,cfg);
    fallback=true;
end
rules=["NMOPSOEqualSum","FairAugTcheby",string(cfg.RepresentativeRuleID)];
indices=[iPaper iFair iDeploy];
scores=[paper(iPaper) fairTcheby(iFair) rawTcheby(iDeploy)];
selectedOperational=logical(A.Geometry(iDeploy).OperationalEligible);
selectedStrict2m=logical(A.Geometry(iDeploy).Strict2mEligible);
deploymentSelection=struct( ...
    'Scenario',sc,'Run',runId,'Method',string(method), ...
    'ProtocolVersion',string(cfg.ProtocolVersion), ...
    'Rule',string(cfg.RepresentativeRuleID),'ArchiveIndex',iDeploy, ...
    'RuleScore',rawTcheby(iDeploy), ...
    'ArchiveOperationalAvailable',archiveOperational, ...
    'ArchiveStrict2mAvailable',archiveStrict2m, ...
    'SelectedOperationalEligible',selectedOperational, ...
    'SelectedStrict2mEligible',selectedStrict2m, ...
    'FallbackUsed',fallback, ...
    'Fallback',fallback, ...
    'OperationalViolationVop',vop(iDeploy), ...
    'Candidate',A.Items(iDeploy), ...
    'Cost',C(iDeploy,:),'NormalizedCost',N(iDeploy,:), ...
    'Geometry',A.Geometry(iDeploy),'SourceTask',string(taskFile));
rows=cell(3,numel(localRepresentativeNames()));
for r=1:3
    i=indices(r);c=C(i,:);g=A.Geometry(i);n=N(i,:);
    rows(r,:)={sc,runId,string(method),rules(r),i,scores(r), ...
        sum(c),sum(n),max(n),sqrt(sum(n.^2)), ...
        c(1),c(2),c(3),c(4), ...
        g.OperationalEligible,g.Strict2mEligible,fallback && r==3, ...
        g.PathLengthM,g.Tortuosity,g.MinCollisionMarginM,g.MinSafetyMarginM, ...
        g.WorstPairRisk,g.SoftThreatPairRate,g.MinTerrainClearanceM,g.TerrainReserveM, ...
        g.MeanTurnDeg,g.P95TurnDeg,g.MaxTurnDeg, ...
        g.MeanClimbDeg,g.P95ClimbDeg,g.MaxClimbDeg, ...
        g.TotalAscentM,g.TotalDescentM,string(taskFile), ...
        archiveOperational,archiveStrict2m, ...
        g.OperationalEligible,g.Strict2mEligible,fallback && r==3, ...
        g.OperationalViolationVop};
end
end

function idx=localSelectDeployment(indices,vop,rawTcheby,C,G,useVop,cfg)
% Deterministic protocol order: [Vop,] S_AT, F2, F4, path length, index.
indices=double(indices(:));
if useVop
    indices=localKeepMinTie(indices,vop,cfg.TieTolerance);
end
indices=localKeepMinTie(indices,rawTcheby,cfg.TieTolerance);
indices=localKeepMinTie(indices,C(:,2),cfg.TieTolerance);
indices=localKeepMinTie(indices,C(:,4),cfg.TieTolerance);
pathLength=[G.PathLengthM]';
indices=localKeepMinTie(indices,pathLength,cfg.TieTolerance);
idx=min(indices);
end

function keep=localKeepMinTie(indices,values,tol)
values=double(values(:));
v=values(indices);
finiteMask=isfinite(v);
if ~any(finiteMask)
    keep=indices;
    return;
end
indices=indices(finiteMask);
v=v(finiteMask);
best=min(v);
keep=indices(abs(v-best)<=tol);
if isempty(keep)
    [~,j]=min(v);
    keep=indices(j);
end
end

function T=localCompatibilitySummary(C)
T=localGroupedSummary(C, ...
    {'LocalGridSD','LocalGridOccupied','CommonGridRedundancy', ...
     'CommonGridOccupied','CommonGridEfficiency','NDArchiveSize', ...
     'F1Min','F2Min','F3Min','F4Min','F1Mean','F2Mean','F3Mean','F4Mean'});
end

function T=localCompatibilitySummaryByScenario(C)
T=localGroupedSummary(C, ...
    {'LocalGridSD','LocalGridOccupied','CommonGridRedundancy', ...
     'CommonGridOccupied','CommonGridEfficiency','NDArchiveSize', ...
     'F1Min','F2Min','F3Min','F4Min','F1Mean','F2Mean','F3Mean','F4Mean'},true);
end

function T=localSetSummary(P)
T=localGroupedSummary(P, ...
    {'HVExactRaw','HVExactRawRatio','IGDPlusNorm','EpsilonPlusNorm', ...
     'SpacingL1Norm','SpreadNNCVNorm','CommonGridOccupied', ...
     'CommonGridRedundancy','CommonGridEfficiency','CommonGridOccupiedK10', ...
     'CommonGridRedundancyK10','HVExactRawK10','IGDPlusNormK10'});
end

function T=localSetSummaryByScenario(P)
T=localGroupedSummary(P, ...
    {'HVExactRaw','HVExactRawRatio','IGDPlusNorm','EpsilonPlusNorm', ...
     'SpacingL1Norm','SpreadNNCVNorm','CommonGridOccupied', ...
     'CommonGridRedundancy','CommonGridEfficiency','CommonGridOccupiedK10', ...
     'CommonGridRedundancyK10','HVExactRawK10','IGDPlusNormK10'},true);
end

function T=localRepresentativeSummary(R,byScenario)
if nargin<2,byScenario=false;end
if byScenario
    groupNames={'Scenario','Method','Rule'};
else
    groupNames={'Method','Rule'};
end
groups=unique(R(:,groupNames),'rows','stable');
binarySpecs={ ...
    'ArchiveOperationalAvailable','ArchiveOperational'; ...
    'ArchiveStrict2mAvailable','ArchiveStrict2m'; ...
    'SelectedOperationalEligible','SelectedOperational'; ...
    'SelectedStrict2mEligible','SelectedStrict2m'; ...
    'FallbackUsed','FallbackUsed'};
names=[groupNames,{'N'}];
% Legacy aliases retained for readers of the previous CSV schema.
names=[names,{'OperationalEligibleRate','ConservativeEligibleRate','FallbackRate'}];
metrics={'RuleScore','RawEqualSum','F1','F2','F3','F4','PathLengthM','Tortuosity', ...
    'MinCollisionMarginM','MinSafetyMarginM','WorstPairRisk','SoftThreatPairRate', ...
    'MinTerrainClearanceM','TerrainReserveM','P95TurnDeg','MaxTurnDeg', ...
    'P95ClimbDeg','MaxClimbDeg','TotalAscentM','TotalDescentM', ...
    'OperationalViolationVop'};
for i=1:numel(metrics)
    names=[names,{['Mean' metrics{i}],['Std' metrics{i}]}]; %#ok<AGROW>
end
for b=1:size(binarySpecs,1)
    prefix=binarySpecs{b,2};
    names=[names,{[prefix 'SuccessN'],[prefix 'NOverN'],[prefix 'Rate'], ...
        [prefix 'Wilson95Low'],[prefix 'Wilson95High']}]; %#ok<AGROW>
end
rows=cell(0,numel(names));
for i=1:height(groups)
    mask=R.Method==groups.Method(i) & R.Rule==groups.Rule(i);
    if byScenario,mask=mask & R.Scenario==groups.Scenario(i);end
    X=R(mask,:);
    if byScenario
        row={groups.Scenario(i),groups.Method(i),groups.Rule(i),height(X)};
    else
        row={groups.Method(i),groups.Rule(i),height(X)};
    end
    row=[row,{mean(double(X.OperationalEligible)), ...
        mean(double(X.ConservativeEligible)),mean(double(X.EligibilityFallback))}]; %#ok<AGROW>
    for j=1:numel(metrics)
        v=X.(metrics{j});
        row=[row,{mean(v,'omitnan'),std(v,0,'omitnan')}]; %#ok<AGROW>
    end
    for b=1:size(binarySpecs,1)
        v=double(X.(binarySpecs{b,1}));
        valid=isfinite(v);
        n=sum(valid);
        success=sum(v(valid)~=0);
        [lo,hi]=localWilson95(success,n);
        if n>0,rate=success/n;else,rate=NaN;end
        row=[row,{success,string(sprintf('%d/%d',success,n)),rate,lo,hi}]; %#ok<AGROW>
    end
    rows(end+1,:)=row; %#ok<AGROW>
end
T=cell2table(rows,'VariableNames',names);
end

function T=localGroupedSummary(X,metrics,byScenario)
if nargin<3,byScenario=false;end
if byScenario
    groups=unique(X(:,{'Scenario','Method'}),'rows','stable');
    names={'Scenario','Method','N'};
else
    groups=table(unique(X.Method,'stable'),'VariableNames',{'Method'});
    names={'Method','N'};
end
for i=1:numel(metrics)
    names=[names,{['Mean' metrics{i}],['Std' metrics{i}]}]; %#ok<AGROW>
end
rows=cell(0,numel(names));
for i=1:height(groups)
    mask=X.Method==groups.Method(i);
    if byScenario,mask=mask & X.Scenario==groups.Scenario(i);end
    Q=X(mask,:);
    if byScenario
        row={groups.Scenario(i),groups.Method(i),height(Q)};
    else
        row={groups.Method(i),height(Q)};
    end
    for j=1:numel(metrics)
        v=Q.(metrics{j});
        row=[row,{mean(v,'omitnan'),std(v,0,'omitnan')}]; %#ok<AGROW>
    end
    rows(end+1,:)=row; %#ok<AGROW>
end
T=cell2table(rows,'VariableNames',names);
end

function T=localDeploymentPairwise(R,cfg)
D=R(R.Rule==string(cfg.RepresentativeRuleID),:);
control=string(cfg.ControlMethod);
methods=unique(D.Method,'stable');
spec={ ...
    'ArchiveOperationalAvailable',true,true; ...
    'ArchiveStrict2mAvailable',true,true; ...
    'SelectedOperationalEligible',true,true; ...
    'SelectedStrict2mEligible',true,true; ...
    'F1',false,false; ...
    'F2',false,false; ...
    'F3',false,false; ...
    'F4',false,false; ...
    'RuleScore',false,false; ...
    'RawEqualSum',false,false; ...
    'MinSafetyMarginM',true,false; ...
    'WorstPairRisk',false,false; ...
    'P95TurnDeg',false,false; ...
    'P95ClimbDeg',false,false; ...
    'PathLengthM',false,false; ...
    'TotalAscentM',false,false};
names={'Metric','HigherIsBetter','Control','Baseline','NPairs','NEffective', ...
    'MeanBenefitControl','PValue','HolmAdjustedP','RankBiserial', ...
    'ControlWins','Ties','ControlLosses','SignificantHolm', ...
    'EndpointType','Test','PairedRateDifference','B01','B10'};
rows=cell(0,numel(names));
objectiveFamilyRows=[];
for s=1:size(spec,1)
    start=size(rows,1)+1;
    metric=spec{s,1};higher=spec{s,2};isBinary=spec{s,3};
    for m=1:numel(methods)
        base=methods(m);
        if base==control,continue;end
        [a,b]=localMatched(D,control,base,metric);
        if higher,benefit=a-b;else,benefit=b-a;end
        if isBinary
            [p,b01,b10,nEff]=localExactMcNemar(a,b);
            endpointType="Binary";
            testName="ExactMcNemarTwoSided";
            rb=NaN;
            pairedRateDifference=mean(a-b,'omitnan');
        else
            [p,rb,nEff]=localSignedRank(benefit,cfg);
            endpointType="Continuous";
            testName="PairedWilcoxonSignedRankTwoSided";
            b01=NaN;b10=NaN;pairedRateDifference=NaN;
        end
        wins=sum(benefit>cfg.TieTolerance);
        losses=sum(benefit<-cfg.TieTolerance);
        ties=numel(benefit)-wins-losses;
        rows(end+1,:)={string(metric),higher,control,base,numel(benefit),nEff, ...
            mean(benefit,'omitnan'),p,NaN,rb,wins,ties,losses,false, ...
            endpointType,testName,pairedRateDifference,b01,b10}; %#ok<AGROW>
    end
    block=start:size(rows,1);
    if ismember(metric,{'F1','F2','F3','F4'})
        objectiveFamilyRows=[objectiveFamilyRows,block]; %#ok<AGROW>
    else
        p=cell2mat(rows(block,8));
        adj=localHolm(p);
        for j=1:numel(block)
            rows{block(j),9}=adj(j);
            rows{block(j),14}=isfinite(adj(j)) && adj(j)<cfg.Alpha;
        end
    end
end
% PAPER-MO-UAV-V1 freezes F1-F4 x every comparator as one Holm family.
if ~isempty(objectiveFamilyRows)
    p=cell2mat(rows(objectiveFamilyRows,8));
    adj=localHolm(p);
    for j=1:numel(objectiveFamilyRows)
        rows{objectiveFamilyRows(j),9}=adj(j);
        rows{objectiveFamilyRows(j),14}= ...
            isfinite(adj(j)) && adj(j)<cfg.Alpha;
    end
end
T=cell2table(rows,'VariableNames',names);
end

function [a,b]=localMatched(T,ma,mb,metric)
A=T(T.Method==ma,{'Scenario','Run',metric});
B=T(T.Method==mb,{'Scenario','Run',metric});
ka=A.Scenario*100000+A.Run;kb=B.Scenario*100000+B.Run;
[~,ia,ib]=intersect(ka,kb,'stable');
a=double(A.(metric)(ia));b=double(B.(metric)(ib));
ok=isfinite(a)&isfinite(b);a=a(ok);b=b(ok);
end

function [p,b01,b10,nDiscordant]=localExactMcNemar(control,baseline)
control=double(control(:))~=0;
baseline=double(baseline(:))~=0;
b01=sum(~control & baseline);
b10=sum(control & ~baseline);
nDiscordant=b01+b10;
if nDiscordant==0
    p=1;
    return;
end
k=min(b01,b10);
i=(0:k)';
logTerms=gammaln(nDiscordant+1)-gammaln(i+1)- ...
    gammaln(nDiscordant-i+1)-nDiscordant*log(2);
p=min(1,2*sum(exp(logTerms)));
end

function [p,rb,n]=localSignedRank(d,cfg)
d=double(d(:));d=d(isfinite(d));d=d(abs(d)>cfg.TieTolerance);n=numel(d);
if n==0,p=1;rb=0;return;end
[ranks,ties]=localTiedRank(abs(d)');ranks=ranks(:);
wp=sum(ranks(d>0));wm=sum(ranks(d<0));rb=(wp-wm)/sum(ranks);
if n<=cfg.ExactSignedRankMaxN
    r2=round(2*ranks);total=sum(r2);ways=zeros(1,total+1);ways(1)=1;
    for i=1:numel(r2)
        rr=r2(i);ways(rr+1:end)=ways(rr+1:end)+ways(1:end-rr);
    end
    support=0:total;obs=round(2*wp);dev=abs(obs-total/2);
    p=sum(ways(abs(support-total/2)>=dev-1e-12))/(2^n);
else
    mu=n*(n+1)/4;
    varW=n*(n+1)*(2*n+1)/24-sum(ties.^3-ties)/48;
    if varW<=0,p=1;return;end
    z=max(0,(abs(wp-mu)-0.5)/sqrt(varW));
    p=erfc(z/sqrt(2));
end
p=min(1,max(0,p));
end

function adj=localHolm(p)
p=double(p(:));m=numel(p);adj=nan(m,1);
valid=find(isfinite(p));
if isempty(valid),return;end
[ps,ord]=sort(p(valid));as=zeros(numel(valid),1);running=0;
for i=1:numel(valid)
    running=max(running,(numel(valid)-i+1)*ps(i));
    as(i)=min(1,running);
end
tmp=zeros(numel(valid),1);tmp(ord)=as;adj(valid)=tmp;
end

function [lo,hi]=localWilson95(success,n)
if n<=0 || ~isfinite(success)
    lo=NaN;hi=NaN;
    return;
end
z=1.959963984540054;
phat=success/n;
den=1+z^2/n;
centre=(phat+z^2/(2*n))/den;
half=z/den*sqrt(phat*(1-phat)/n+z^2/(4*n^2));
lo=max(0,centre-half);
hi=min(1,centre+half);
end

function [ranks,tieSizes]=localTiedRank(x)
x=double(x(:)');[xs,ord]=sort(x);r=zeros(size(xs));tieSizes=[];i=1;
while i<=numel(xs)
    j=i;
    while j<numel(xs) && abs(xs(j+1)-xs(i))<=1e-12*max(1,abs(xs(i))),j=j+1;end
    r(i:j)=mean(i:j);tieSizes(end+1)=j-i+1; %#ok<AGROW>
    i=j+1;
end
ranks=zeros(size(r));ranks(ord)=r;
end

function [sc,runId,method]=localTaskMeta(S,name)
sc=NaN;runId=NaN;method="";
if isfield(S,'task') && isstruct(S.task)
    if isfield(S.task,'Scenario'),sc=double(S.task.Scenario);end
    if isfield(S.task,'Run'),runId=double(S.task.Run);end
    if isfield(S.task,'Method'),method=string(S.task.Method);end
end
if ~isfinite(sc) || ~isfinite(runId) || strlength(method)==0
    tok=regexp(name,'S(\d+)_R(\d+)_(.+)\.mat','tokens','once');
    if ~isempty(tok)
        sc=str2double(tok{1});runId=str2double(tok{2});
        method=string(strrep(tok{3},'_','-'));
    end
end
method=localNormalizeMethod(method);
end

function method=localNormalizeMethod(method)
s=upper(char(string(method)));
s=strrep(s,'MOEA-D','MOEA/D');
s=strrep(s,'MOEA_D','MOEA/D');
s=strrep(s,'NSGA-III','NSGA-III');
s=strrep(s,'NSGA_III','NSGA-III');
method=string(s);
end

function pool=localCandidatePool(S)
pool=[];
if isfield(S,'rep') && isstruct(S.rep),pool=S.rep(:);end
if isempty(pool) && isfield(S,'best') && isstruct(S.best),pool=S.best(:);end
end

function keep=localNondominatedMask(C,tol)
n=size(C,1);keep=true(n,1);
for i=1:n
    if ~keep(i),continue;end
    for j=1:n
        if i==j,continue;end
        if all(C(j,:)<=C(i,:)+tol) && any(C(j,:)<C(i,:)-tol)
            keep(i)=false;break;
        end
    end
end
end

function [C,ia]=localUniqueTol(C,tol)
scale=max(1,max(abs(C),[],1));
Q=round(C./(tol.*scale)).*(tol.*scale);
[~,ia]=unique(Q,'rows','stable');
ia=sort(ia);C=C(ia,:);
end

function v=localTableValue(T,name)
if ismember(name,T.Properties.VariableNames),v=T.(name);else,v=NaN;end
end

function localWriteProtocol(outDir,formalDir,cfg,C,P,R,PS,RS)
fid=fopen(fullfile(outDir,'README_FDEP_PROTOCOL.md'),'w');
if fid<0,return;end
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Unified multi-objective UAV evaluation export\n\n');
fprintf(fid,'Protocol: `%s`\n\n',cfg.ProtocolVersion);
fprintf(fid,'Source tasks: `%s`\n\n',formalDir);
fprintf(fid,'Read-only Q2 evaluation source: `%s`\n\n',cfg.Q2EvaluationResolvedFile);
fprintf(fid,'## Layer 1: NMOPSO compatibility\n\n');
fprintf(fid,'- F1-F4 archive Max/Min/Mean/Std are first calculated per run and then aggregated across independent runs.\n');
fprintf(fid,'- Original NMOPSO `sd=np/no` uses M=%d and remains a compatibility indicator.\n',cfg.LocalGridDivisions);
fprintf(fid,'- `np`, occupied cells and sd are reported together; sd is never interpreted alone.\n\n');
fprintf(fid,'## Layer 2: fair Pareto-set quality\n\n');
fprintf(fid,'- Fixed raw-objective HV and frozen pooled-front IGD+ come from Q2 evaluation V3.\n');
fprintf(fid,'- K=%d cardinality-controlled HV/IGD+ removes archive-size advantage.\n',cfg.FixedCardinality);
fprintf(fid,'- Common-grid distribution uses the same [0,1]^4 grid (M=%d) for every method.\n\n',cfg.CommonGridDivisions);
fprintf(fid,'## Layer 3: deployable route quality\n\n');
fprintf(fid,'- All archive members are rechecked by continuous terrain, cylindrical collision, turn and climb constraints.\n');
fprintf(fid,'- Formal representative rule: `%s`.\n',cfg.RepresentativeRuleID);
fprintf(fid,'- Its score is `max(F1..F4) + %.3g*sum(F1..F4)` on the frozen physical [0,1] objectives; it does not use a pooled-front ideal/nadir.\n',cfg.AugmentedTchebyRho);
fprintf(fid,'- Deployment eligibility requires safety-buffer margin >= %.3g m, P95 turn <= %.3g deg and P95 climb <= %.3g deg.\n', ...
    cfg.PreferredMinSafetyMarginM,cfg.PreferredP95TurnDeg,cfg.PreferredP95ClimbDeg);
fprintf(fid,'- Strict-2m sensitivity keeps the same turn/climb limits but requires safety-buffer margin >= %.3g m.\n', ...
    cfg.StrictMinSafetyMarginM);
fprintf(fid,'- If no member passes the deployment screen, fallback selection minimizes Vop, then the raw-objective score, F2, F4, path length and stable archive index.\n');
fprintf(fid,'- Binary paired comparisons use two-sided exact McNemar tests with b01/b10; marginal rates include Wilson 95%% intervals.\n');
fprintf(fid,'- McNemar orientation is b01=(control 0, baseline 1), b10=(control 1, baseline 0).\n');
fprintf(fid,'- Formal representative-path F1-F4 comparisons against every comparator share one Holm family.\n');
fprintf(fid,'- Overall and scenario-stratified summaries are exported separately.\n');
fprintf(fid,'- Worst local threat risk, safety margin, terrain reserve, turn/climb percentiles and ascent/descent are reported.\n\n');
fprintf(fid,'## Data completeness\n\n');
fprintf(fid,'- Valid tasks: %d.\n',height(C));
fprintf(fid,'- Set-quality rows: %d; representative rows: %d.\n',height(P),height(R));
fprintf(fid,'\n## Current summaries\n\n```text\n%s\n\n%s\n```\n',evalc('disp(PS)'),evalc('disp(RS)'));
end

function names=localCompatibilityNames()
names={'Scenario','Run','Method','NDArchiveSize','LocalGridOccupied','LocalGridSD', ...
    'CommonGridOccupied','CommonGridRedundancy','CommonGridEfficiency', ...
    'CommonGridGlobalCoverage', ...
    'F1Min','F2Min','F3Min','F4Min', ...
    'F1Max','F2Max','F3Max','F4Max', ...
    'F1Mean','F2Mean','F3Mean','F4Mean', ...
    'F1Std','F2Std','F3Std','F4Std','TaskFile'};
end

function names=localSetNames()
names={'Scenario','Run','Method','NDArchiveSize', ...
    'HVExactRaw','HVExactRawRatio','IGDPlusNorm','EpsilonPlusNorm', ...
    'SpacingL1Norm','SpreadNNCVNorm', ...
    'CommonGridOccupied','CommonGridRedundancy','CommonGridEfficiency', ...
    'CommonGridOccupiedK10','CommonGridRedundancyK10','CommonGridEfficiencyK10', ...
    'HasK10','HVExactRawK10','IGDPlusNormK10','TaskFile'};
end

function names=localRepresentativeNames()
names={'Scenario','Run','Method','Rule','ArchiveIndex','RuleScore', ...
    'RawEqualSum','NormalizedSum','NormalizedMax','NormalizedL2', ...
    'F1','F2','F3','F4', ...
    'OperationalEligible','ConservativeEligible','EligibilityFallback', ...
    'PathLengthM','Tortuosity','MinCollisionMarginM','MinSafetyMarginM', ...
    'WorstPairRisk','SoftThreatPairRate','MinTerrainClearanceM','TerrainReserveM', ...
    'MeanTurnDeg','P95TurnDeg','MaxTurnDeg', ...
    'MeanClimbDeg','P95ClimbDeg','MaxClimbDeg', ...
    'TotalAscentM','TotalDescentM','TaskFile', ...
    'ArchiveOperationalAvailable','ArchiveStrict2mAvailable', ...
    'SelectedOperationalEligible','SelectedStrict2mEligible','FallbackUsed', ...
    'OperationalViolationVop'};
end

function G=localEmptyGeometry()
G=struct('OperationalEligible',false,'Strict2mEligible',false, ...
    'ConservativeEligible',false, ...
    'OperationalViolationVop',Inf,'SafetyDistM',NaN, ...
    'PathLengthM',NaN,'Tortuosity',NaN, ...
    'MinCollisionMarginM',NaN,'MinSafetyMarginM',NaN,'WorstPairRisk',NaN, ...
    'SoftThreatPairRate',NaN,'MinTerrainClearanceM',NaN,'TerrainReserveM',NaN, ...
    'MeanTurnDeg',NaN,'P95TurnDeg',NaN,'MaxTurnDeg',NaN, ...
    'MeanClimbDeg',NaN,'P95ClimbDeg',NaN,'MaxClimbDeg',NaN, ...
    'TotalAscentM',NaN,'TotalDescentM',NaN);
end

function v=localField(s,name,defaultValue)
if isstruct(s)&&isfield(s,name)&&~isempty(s.(name)),v=s.(name);else,v=defaultValue;end
end
function v=localMean(x),x=x(isfinite(x));if isempty(x),v=NaN;else,v=mean(x);end,end
function v=localMax(x),x=x(isfinite(x));if isempty(x),v=NaN;else,v=max(x);end,end
function p=localPercentile(x,q)
x=sort(double(x(isfinite(x))));
if isempty(x),p=NaN;return;end
pos=1+(numel(x)-1)*q/100;lo=floor(pos);hi=ceil(pos);
if lo==hi,p=x(lo);else,p=x(lo)+(pos-lo)*(x(hi)-x(lo));end
end
function localRemoveAppdata(name)
try,if isappdata(0,name),rmappdata(0,name);end,catch,end
end