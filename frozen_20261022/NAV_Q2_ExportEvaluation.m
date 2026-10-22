function outDir = NAV_Q2_ExportEvaluation(formalDir, outDir, cfg)
%NAV_Q2_EXPORTEVALUATION Q2-grade multi-objective evaluation exporter.
%
% This is an evaluation-only module. It does not change objective functions,
% constraints, random numbers, FE accounting, archives, or optimizer search.
%
% Primary outputs:
%   q2_all_runs.csv
%   q2_summary_by_method.csv
%   q2_summary_by_scenario.csv
%   q2_objective_archive_summary.csv
%   q2_representative_robustness.csv
%   q2_pairwise_control_holm.csv
%   q2_friedman_average_ranks.csv
%   q2_friedman_omnibus.csv
%   q2_initialization_audit.csv and q2_initialization_summary.csv
%   q2_pairwise_by_scenario_holm.csv
%   q2_reference_contributions.csv
%   reference_sets/reference_manifest.csv and frozen scenario MAT/CSV files
%
% Main indicator protocol (MO-UAV-EVAL-V1.0):
%   - exact 4-D hypervolume on the original bounded F1-F4 scale with fixed
%     reference point [1.1 1.1 1.1 1.1] (primary HV)
%   - front-normalized region-of-interest hypervolume as a diagnostic only;
%     zero values are allowed when an archive does not enter that fixed ROI
%   - IGD+ and unary additive epsilon on the same frozen normalized reference
%   - spacing and nearest-neighbour CV as distribution-only secondary metrics
%   - optional cardinality-controlled HV@K and IGD+@K
%   - equal-sum, normalized-sum, augmented-Tchebycheff and ideal-L2
%     representative-solution sensitivity analysis
%   - paired exact/small-sample or tie-corrected Wilcoxon signed-rank, Holm correction, rank-biserial
%     effect size, wins/ties/losses, and Friedman/Iman-Davenport omnibus ranks
%
% Example:
%   NAV_Q2_ExportEvaluation(fullfile(pwd,'results', ...
%       'E31_FormalMain_4Scen_20Run_2000FE_Exact'));

if nargin < 1 || isempty(formalDir)
    error('NAV_Q2_ExportEvaluation:FormalDirRequired','formalDir is required.');
end
if nargin < 2 || isempty(outDir)
    outDir = fullfile(formalDir,'q2_evaluation_v3');
end
if nargin < 3 || isempty(cfg), cfg = struct(); end
cfg = localDefaults(cfg);
if exist(outDir,'dir')~=7, mkdir(outDir); end
refDir = fullfile(outDir,'reference_sets');
if exist(refDir,'dir')~=7, mkdir(refDir); end
if exist(fullfile(formalDir,'tasks'),'dir')~=7
    error('NAV_Q2_ExportEvaluation:MissingTasks','Task directory not found: %s',fullfile(formalDir,'tasks'));
end

fprintf('\n[Q2 evaluation] Loading task archives from:\n  %s\n', formalDir);
raw = localLoadTasks(formalDir, cfg);
if isempty(raw), error('NAV_Q2_ExportEvaluation:NoValidTasks','No valid task archives were extracted.'); end

scenarios = unique([raw.Scenario]);
refs = repmat(localEmptyReference(),0,1);
manifestRows = cell(0, numel(localReferenceManifestNames()));
for si = 1:numel(scenarios)
    sc = scenarios(si);
    scRaw = raw([raw.Scenario]==sc);
    refFile = fullfile(refDir,sprintf('reference_S%d.mat',sc));
    useExisting = exist(refFile,'file')==2 && ~cfg.RebuildReference;
    if useExisting
        try
            R = load(refFile,'reference');
            reference = R.reference;
            localValidateReference(reference, sc, cfg, scRaw);
            source = 'frozen-existing';
        catch MEref
            warning('ARCMOVWO:Q2Evaluation:RebuildReference', ...
                'Reference S%d is incompatible with protocol %s and will be rebuilt: %s', ...
                sc,cfg.ProtocolVersion,MEref.message);
            useExisting = false;
        end
    end
    if ~useExisting
        reference = localBuildReference(scRaw, sc, cfg);
        save(refFile,'reference','cfg');
        localWriteReferenceCSV(reference,refDir);
        source = 'built-and-frozen';
    end
    refs(end+1,1) = reference; %#ok<AGROW>
    manifestRows(end+1,:) = localReferenceManifestRow(reference,source); %#ok<AGROW>
end
refManifest = cell2table(manifestRows,'VariableNames',localReferenceManifestNames());
writetable(refManifest,fullfile(refDir,'reference_manifest.csv'));
refContrib = localReferenceContributions(raw,refs,cfg);
writetable(refContrib,fullfile(outDir,'q2_reference_contributions.csv'));

% Per-run set indicators and decision-rule sensitivity.
runRows = cell(0, localRunWidth(cfg));
repRows = cell(0, 18);
for i = 1:numel(raw)
    ref = refs([refs.Scenario]==raw(i).Scenario);
    [runRow, decisionRows] = localEvaluateTask(raw(i), ref, cfg);
    runRows(end+1,:) = runRow; %#ok<AGROW>
    repRows = [repRows; decisionRows]; %#ok<AGROW>
end
T = cell2table(runRows,'VariableNames',localRunNames(cfg));
T = sortrows(T,{'Scenario','Run','Method'});
R = cell2table(repRows,'VariableNames',localRepresentativeNames());
R = sortrows(R,{'Scenario','Run','Method','Rule'});
writetable(T,fullfile(outDir,'q2_all_runs.csv'));
writetable(R,fullfile(outDir,'q2_representative_robustness.csv'));

S = localSummaryByMethod(T,cfg);
SS = localSummaryByScenario(T,cfg);
objectiveSummary = localObjectiveArchiveSummary(T);
writetable(S,fullfile(outDir,'q2_summary_by_method.csv'));
writetable(SS,fullfile(outDir,'q2_summary_by_scenario.csv'));
writetable(objectiveSummary,fullfile(outDir,'q2_objective_archive_summary.csv'));

[pairwise, pairwiseScenario, friedmanRanks, friedmanOmnibus] = localStatistics(T,cfg);
writetable(pairwise,fullfile(outDir,'q2_pairwise_control_holm.csv'));
writetable(pairwiseScenario,fullfile(outDir,'q2_pairwise_by_scenario_holm.csv'));
writetable(friedmanRanks,fullfile(outDir,'q2_friedman_average_ranks.csv'));
writetable(friedmanOmnibus,fullfile(outDir,'q2_friedman_omnibus.csv'));

initAudit = localInitializationAudit(formalDir,cfg);
initSummary = localInitializationSummary(initAudit,cfg);
writetable(initAudit,fullfile(outDir,'q2_initialization_audit.csv'));
writetable(initSummary,fullfile(outDir,'q2_initialization_summary.csv'));

save(fullfile(outDir,'q2_evaluation.mat'),'T','R','S','SS','objectiveSummary','pairwise', ...
    'pairwiseScenario','friedmanRanks','friedmanOmnibus','initAudit','initSummary', ...
    'refs','refManifest','refContrib','cfg','-v7.3');
localWriteReadme(outDir,formalDir,cfg,T,refs);

fprintf('[Q2 evaluation] Completed: %s\n', outDir);
disp(S(:,intersect({'Method','N','MeanHVExactRaw','MeanIGDPlusNorm', ...
    'MeanHVExactRawRatio','MeanPaperScore','MeanSpacingL1Norm'}, ...
    S.Properties.VariableNames,'stable')));
end

%% Configuration
function cfg = localDefaults(cfg)
def = struct();
def.ProtocolVersion = 'MO-UAV-EVAL-V1.0';
def.ControlMethod = 'ARCMOVWO';
def.Alpha = 0.05;
def.TieTolerance = 1e-10;
def.FeasibleTolerance = 1e-9;
def.RawHVReference = 1.1*ones(1,4);
% Front-normalized ROI HV uses this fixed diagnostic reference only.
def.NormalizedHVReference = 1.1*ones(1,4);
def.ReferenceMaxPoints = 1500;
def.ReferenceSeed = 20260723;
def.RebuildReference = false;
def.CardinalityK = [10 20];
def.AugmentedTchebyRho = 0.05;
def.InitUniqueRatioTarget = 0.75;
def.InitialConsumedSlots = 24;
def.GridDivisions = 7;
def.QuantizationTolerance = 1e-12;
def.ExactSignedRankMaxN = 22;
def.MinPairsForInference = 10;
def.MinBlocksForOmnibus = 10;
fields = fieldnames(def);
for i=1:numel(fields)
    if ~isfield(cfg,fields{i}) || isempty(cfg.(fields{i}))
        cfg.(fields{i}) = def.(fields{i});
    end
end
cfg.CardinalityK = unique(round(double(cfg.CardinalityK(:)')),'stable');
cfg.CardinalityK = cfg.CardinalityK(cfg.CardinalityK>0);
validateattributes(cfg.RawHVReference,{'numeric'},{'vector','numel',4});
validateattributes(cfg.NormalizedHVReference,{'numeric'},{'vector','numel',4});
validateattributes(cfg.InitialConsumedSlots,{'numeric'},{'scalar','integer','positive'});
validateattributes(cfg.GridDivisions,{'numeric'},{'scalar','integer','>=',2});
validateattributes(cfg.ExactSignedRankMaxN,{'numeric'},{'scalar','integer','nonnegative'});
validateattributes(cfg.MinPairsForInference,{'numeric'},{'scalar','integer','positive'});
validateattributes(cfg.MinBlocksForOmnibus,{'numeric'},{'scalar','integer','positive'});
end

%% Task loading
function raw = localLoadTasks(formalDir,cfg)
files = dir(fullfile(formalDir,'tasks','*.mat'));
raw = repmat(struct('Scenario',NaN,'Run',NaN,'Method','','Costs',[], ...
    'TaskFile','','ArchiveSize',0),0,1);
for i=1:numel(files)
    fp = fullfile(files(i).folder,files(i).name);
    try
        S = load(fp);
        [sc,run,method] = localTaskMeta(S,files(i).name);
        C = localExtractCosts(S);
        C = C(all(isfinite(C),2),:);
        C = C(all(C>=-cfg.FeasibleTolerance & C<=1+cfg.FeasibleTolerance,2),:);
        if isnan(sc) || isnan(run) || strlength(string(method))==0 || isempty(C)
            continue;
        end
        item = struct('Scenario',double(sc),'Run',double(run), ...
            'Method',char(localNormalizeMethod(method)),'Costs',double(C(:,1:4)), ...
            'TaskFile',fp,'ArchiveSize',size(C,1));
        raw(end+1,1)=item; %#ok<AGROW>
    catch ME
        warning('ARCMOVWO:Q2Evaluation:SkipTask','Skip %s: %s',files(i).name,ME.message);
    end
end
end

function [sc,run,method] = localTaskMeta(S,name)
sc=NaN; run=NaN; method="";
if isfield(S,'task') && isstruct(S.task)
    t=S.task;
    if isfield(t,'Scenario'),sc=double(t.Scenario);end
    if isfield(t,'Run'),run=double(t.Run);end
    if isfield(t,'Method'),method=string(t.Method);end
elseif isfield(S,'taskMeta') && isstruct(S.taskMeta)
    t=S.taskMeta;
    if isfield(t,'Scenario'),sc=double(t.Scenario);end
    if isfield(t,'Run'),run=double(t.Run);end
    if isfield(t,'Method'),method=string(t.Method);end
elseif isfield(S,'scenario') && isfield(S,'runId') && isfield(S,'method')
    sc=double(S.scenario); run=double(S.runId); method=string(S.method);
end
if isnan(sc) || isnan(run) || strlength(method)==0
    tok=regexp(name,'S(\d+)_R(\d+)_(.+)\.mat','tokens','once');
    if ~isempty(tok)
        sc=str2double(tok{1}); run=str2double(tok{2}); method=string(tok{3});
    end
end
end

function method = localNormalizeMethod(method)
s=upper(char(string(method)));
s=strrep(s,'MOEA_D','MOEA/D');
s=strrep(s,'NSGA_III','NSGA-III');
s=strrep(s,'NSGA_II','NSGA-II');
s=strrep(s,'ARCMOVWO_WO_REPAIR','ARCMOVWO-WO-REPAIR');
s=strrep(s,'ARCMOVWO_WO_HYBRIDTRIM','ARCMOVWO-WO-HYBRIDTRIM');
s=strrep(s,'ARCMOVWO_NOPOLISH','ARCMOVWO-NOPOLISH');
method=string(s);
end

function C = localExtractCosts(S)
C=[];
if isfield(S,'rep'),C=[C;localCostsFromStruct(S.rep)];end
if isfield(S,'best'),C=[C;localCostsFromStruct(S.best)];end
if isempty(C) && isfield(S,'row') && isstruct(S.row)
    r=S.row;
    if all(isfield(r,{'F1','F2','F3','F4'}))
        C=[double(r.F1) double(r.F2) double(r.F3) double(r.F4)];
    end
end
if ~isempty(C),C=double(C(:,1:min(4,size(C,2))));end
if size(C,2)<4,C=[];end
end

function C=localCostsFromStruct(A)
C=[];
if isempty(A) || ~isstruct(A),return;end
A=A(:);
for i=1:numel(A)
    if isfield(A(i),'Cost') && ~isempty(A(i).Cost)
        c=double(A(i).Cost(:)');
        if numel(c)>=4,C(end+1,:)=c(1:4);end %#ok<AGROW>
    end
end
end

%% Frozen reference sets
function reference = localEmptyReference()
reference=struct('ProtocolVersion','','Scenario',NaN,'RawCandidateCount',0, ...
    'UniqueCandidateCount',0,'PooledNDCount',0,'StoredCount',0, ...
    'ReferenceSetID','','AlgorithmCount',0,'RunRosterEntryCount',0, ...
    'AlgorithmRosterText','','AlgorithmRosterHash','', ...
    'RunRosterText','','RunRosterHash','', ...
    'Ideal',nan(1,4),'Nadir',nan(1,4),'Span',nan(1,4), ...
    'RawFront',zeros(0,4),'NormalizedFront',zeros(0,4), ...
    'RawHVReference',1.1*ones(1,4),'NormalizedROIReference',1.1*ones(1,4), ...
    'BuildSeed',NaN,'BuildTimestamp','');
end

function reference = localBuildReference(scRaw,sc,cfg)
allC=vertcat(scRaw.Costs);
allC=allC(all(isfinite(allC),2),:);
rawCount=size(allC,1);
allC=localUniqueTol(allC,cfg.QuantizationTolerance);
uniqueCount=size(allC,1);
front=NAV_Q2_Nondominated(allC,cfg.QuantizationTolerance);
pooledCount=size(front,1);
ideal=min(front,[],1);
nadir=max(front,[],1);
span=max(nadir-ideal,1e-12);
frontN=(front-ideal)./span;
if size(front,1)>cfg.ReferenceMaxPoints
    idx=NAV_Q2_FarthestSubset(frontN,cfg.ReferenceMaxPoints);
    front=front(idx,:);frontN=frontN(idx,:);
end
reference=localEmptyReference();
reference.ProtocolVersion=char(cfg.ProtocolVersion);
reference.Scenario=sc;
reference.RawCandidateCount=rawCount;
reference.UniqueCandidateCount=uniqueCount;
reference.PooledNDCount=pooledCount;
reference.StoredCount=size(front,1);
roster=localReferenceRosterAudit(scRaw);
reference.ReferenceSetID=localReferenceSetID(cfg.ProtocolVersion,sc,roster);
reference.AlgorithmCount=roster.AlgorithmCount;
reference.RunRosterEntryCount=roster.RunRosterEntryCount;
reference.AlgorithmRosterText=roster.AlgorithmRosterText;
reference.AlgorithmRosterHash=roster.AlgorithmRosterHash;
reference.RunRosterText=roster.RunRosterText;
reference.RunRosterHash=roster.RunRosterHash;
reference.Ideal=ideal;
reference.Nadir=nadir;
reference.Span=span;
reference.RawFront=front;
reference.NormalizedFront=frontN;
reference.RawHVReference=double(cfg.RawHVReference(:)');
reference.NormalizedROIReference=double(cfg.NormalizedHVReference(:)');
reference.BuildSeed=cfg.ReferenceSeed;
reference.BuildTimestamp=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
end

function localValidateReference(reference,sc,cfg,scRaw)
required={'ProtocolVersion','Scenario','Ideal','Nadir','Span','RawFront', ...
    'NormalizedFront','RawHVReference','NormalizedROIReference', ...
    'ReferenceSetID','AlgorithmCount','RunRosterEntryCount', ...
    'AlgorithmRosterText','AlgorithmRosterHash','RunRosterText','RunRosterHash'};
for i=1:numel(required)
    if ~isfield(reference,required{i})
        error('NAV_Q2_ExportEvaluation:BadReference','Reference S%d missing %s.',sc,required{i});
    end
end
if ~strcmp(char(reference.ProtocolVersion),char(cfg.ProtocolVersion))
    error('Reference protocol version is %s, expected %s.', ...
        char(reference.ProtocolVersion),char(cfg.ProtocolVersion));
end
if reference.Scenario~=sc,error('Reference scenario mismatch.');end
expected=localReferenceRosterAudit(scRaw);
expectedID=localReferenceSetID(cfg.ProtocolVersion,sc,expected);
if ~strcmp(char(reference.ReferenceSetID),expectedID)
    error('Reference roster identity changed: stored %s, expected %s.', ...
        char(reference.ReferenceSetID),expectedID);
end
if reference.AlgorithmCount~=expected.AlgorithmCount || ...
        ~strcmp(char(reference.AlgorithmRosterText),expected.AlgorithmRosterText) || ...
        ~strcmp(char(reference.AlgorithmRosterHash),expected.AlgorithmRosterHash)
    error('Reference algorithm roster changed; the pooled reference must be rebuilt.');
end
if reference.RunRosterEntryCount~=expected.RunRosterEntryCount || ...
        ~strcmp(char(reference.RunRosterText),expected.RunRosterText) || ...
        ~strcmp(char(reference.RunRosterHash),expected.RunRosterHash)
    error('Reference run roster changed; the pooled reference must be rebuilt.');
end
end

function roster=localReferenceRosterAudit(scRaw)
methods=sort(unique(string({scRaw.Method})));
algorithmText=char(strjoin(methods,'|'));
runEntries=strings(numel(scRaw),1);
for i=1:numel(scRaw)
    runEntries(i)=sprintf('%s:R%.17g',char(string(scRaw(i).Method)),double(scRaw(i).Run));
end
runEntries=sort(runEntries);
runText=char(strjoin(runEntries,'|'));
roster=struct( ...
    'AlgorithmCount',numel(methods), ...
    'RunRosterEntryCount',numel(runEntries), ...
    'AlgorithmRosterText',algorithmText, ...
    'AlgorithmRosterHash',localStableAuditHash(algorithmText), ...
    'RunRosterText',runText, ...
    'RunRosterHash',localStableAuditHash(runText));
end

function id=localReferenceSetID(protocolVersion,sc,roster)
id=sprintf('%s-S%d-A%s-R%s',char(string(protocolVersion)),sc, ...
    roster.AlgorithmRosterHash,roster.RunRosterHash);
end

function h=localStableAuditHash(value)
% Portable Adler-32 audit digest. Exact roster text is also stored and
% compared, so the digest is an identifier rather than a security boundary.
bytes=unicode2native(char(string(value)),'UTF-8');
a=1;b=0;modulus=65521;
for i=1:numel(bytes)
    a=mod(a+double(bytes(i)),modulus);
    b=mod(b+a,modulus);
end
h=sprintf('ADLER32-%08X',uint32(b*65536+a));
end

function localWriteReferenceCSV(reference,refDir)
T=array2table([reference.RawFront reference.NormalizedFront], ...
    'VariableNames',{'F1','F2','F3','F4','N1','N2','N3','N4'});
writetable(T,fullfile(refDir,sprintf('reference_S%d.csv',reference.Scenario)));
end

function row=localReferenceManifestRow(r,source)
row={string(r.ProtocolVersion),r.Scenario,string(source),string(r.ReferenceSetID), ...
    r.AlgorithmCount,r.RunRosterEntryCount,string(r.AlgorithmRosterText), ...
    string(r.AlgorithmRosterHash),string(r.RunRosterText),string(r.RunRosterHash), ...
    r.RawCandidateCount, ...
    r.UniqueCandidateCount,r.PooledNDCount,r.StoredCount, ...
    r.Ideal(1),r.Ideal(2),r.Ideal(3),r.Ideal(4), ...
    r.Nadir(1),r.Nadir(2),r.Nadir(3),r.Nadir(4), ...
    r.RawHVReference(1),r.RawHVReference(2),r.RawHVReference(3),r.RawHVReference(4), ...
    r.NormalizedROIReference(1),r.NormalizedROIReference(2), ...
    r.NormalizedROIReference(3),r.NormalizedROIReference(4), ...
    string(r.BuildTimestamp),r.BuildSeed};
end
function names=localReferenceManifestNames()
names={'ProtocolVersion','Scenario','Source','ReferenceSetID', ...
    'AlgorithmCount','RunRosterEntryCount','AlgorithmRosterText','AlgorithmRosterHash', ...
    'RunRosterText','RunRosterHash','RawCandidateCount','UniqueCandidateCount', ...
    'PooledNDCount','StoredReferenceCount','IdealF1','IdealF2','IdealF3','IdealF4', ...
    'NadirF1','NadirF2','NadirF3','NadirF4', ...
    'RawHVRefF1','RawHVRefF2','RawHVRefF3','RawHVRefF4', ...
    'NormROIRefF1','NormROIRefF2','NormROIRefF3','NormROIRefF4', ...
    'BuildTimestamp','BuildSeed'};
end

%% Reference-front contribution audit
function A=localReferenceContributions(raw,refs,cfg)
rows=cell(0,8);
scenarios=unique([raw.Scenario]);
for sc=scenarios(:)'
    ref=refs([refs.Scenario]==sc);
    front=ref.RawFront;
    methods=unique(string({raw([raw.Scenario]==sc).Method}),'stable');
    methodPoints=cell(numel(methods),1);
    for m=1:numel(methods)
        items=raw([raw.Scenario]==sc & string({raw.Method})==methods(m));
        P=zeros(0,4);
        for i=1:numel(items)
            P=[P;NAV_Q2_Nondominated(items(i).Costs,cfg.QuantizationTolerance)]; %#ok<AGROW>
        end
        methodPoints{m}=localUniqueTol(P,cfg.QuantizationTolerance);
    end
    cover=false(size(front,1),numel(methods));
    for i=1:size(front,1)
        for m=1:numel(methods)
            cover(i,m)=localContainsPoint(methodPoints{m},front(i,:),cfg.QuantizationTolerance);
        end
    end
    nOwners=sum(cover,2);
    for m=1:numel(methods)
        covered=sum(cover(:,m));
        exclusive=sum(cover(:,m)&nOwners==1);
        fractional=sum(double(cover(:,m))./max(1,nOwners));
        rows(end+1,:)={sc,methods(m),size(front,1),covered,exclusive,fractional, ...
            covered/max(1,size(front,1)),fractional/max(1,size(front,1))}; %#ok<AGROW>
    end
end
A=cell2table(rows,'VariableNames',{'Scenario','Method','ReferencePointCount', ...
    'CoveredReferencePoints','ExclusiveReferencePoints','FractionalContribution', ...
    'CoverageRate','FractionalShare'});
if ~isempty(A),A=sortrows(A,{'Scenario','FractionalShare'},{'ascend','descend'});end
end

function tf=localContainsPoint(P,p,tol)
if isempty(P),tf=false;return;end
scale=max(1,max(abs(p)));
tf=any(max(abs(P-p),[],2)<=tol*scale);
end

%% Per-task evaluation
function [row,decisionRows]=localEvaluateTask(item,ref,cfg)
C=localUniqueTol(item.Costs,cfg.QuantizationTolerance);
ND=NAV_Q2_Nondominated(C,cfg.QuantizationTolerance);
N=(ND-ref.Ideal)./ref.Span;

hvRaw=NAV_Q2_HypervolumeExact(ND,ref.RawHVReference);
hvRawRatio=hvRaw/prod(ref.RawHVReference);
% Front-normalized ROI HV is diagnostic only. Because approximation points
% may lie outside the front-derived [0,1] scale, zero values are possible
% and must not replace the bounded raw-objective HV as the primary metric.
hvFrontNormROI=NAV_Q2_HypervolumeExact(N,ref.NormalizedROIReference);
igdPlus=NAV_Q2_IGDPlus(ref.NormalizedFront,N);
epsPlus=NAV_Q2_EpsilonPlus(ref.NormalizedFront,N);
[spacing,nncv]=NAV_Q2_Spacing(N);
[gridSD,gridOccupied]=NAV_Q2_GridDistribution(N,cfg.GridDivisions);

scores=localDecisionScores(ND,ref,cfg);
stats=[min(ND,[],1) max(ND,[],1) mean(ND,1,'omitnan') std(ND,0,1,'omitnan')];
row={item.Scenario,item.Run,string(item.Method),item.ArchiveSize,size(C,1),size(ND,1), ...
    scores.PaperScore,scores.NormSumScore,scores.TchebyScore,scores.IdealL2Score, ...
    hvRaw,hvRawRatio,hvFrontNormROI,igdPlus,epsPlus,spacing,nncv,gridSD,gridOccupied};
for k=cfg.CardinalityK
    if size(N,1)>=k
        idx=NAV_Q2_FarthestSubset(N,k);
        AkN=N(idx,:);AkRaw=ND(idx,:);
        hvK=NAV_Q2_HypervolumeExact(AkRaw,ref.RawHVReference);
        row=[row,{hvK,hvK/prod(ref.RawHVReference), ...
            NAV_Q2_IGDPlus(ref.NormalizedFront,AkN),true}]; %#ok<AGROW>
    else
        row=[row,{NaN,NaN,NaN,false}]; %#ok<AGROW>
    end
end
row=[row,num2cell(stats),{string(item.TaskFile)}];

decisionRows=localDecisionRows(item,ND,ref,scores);
end

function scores=localDecisionScores(C,ref,cfg)
N=(C-ref.Ideal)./ref.Span;
paper=sum(C,2);
normSum=sum(N,2);
tcheby=max(N,[],2)+cfg.AugmentedTchebyRho*sum(N,2);
l2=sqrt(sum(N.^2,2));
[ps,pi]=min(paper);[ns,ni]=min(normSum);[ts,ti]=min(tcheby);[ls,li]=min(l2);
scores=struct('PaperScore',ps,'PaperIndex',pi,'NormSumScore',ns,'NormSumIndex',ni, ...
    'TchebyScore',ts,'TchebyIndex',ti,'IdealL2Score',ls,'IdealL2Index',li);
end

function rows=localDecisionRows(item,C,ref,s)
rules={'PaperEqualSum','ScenarioNormalizedSum','AugmentedTchebycheff','IdealPointL2'};
indices=[s.PaperIndex s.NormSumIndex s.TchebyIndex s.IdealL2Index];
ruleScores=[s.PaperScore s.NormSumScore s.TchebyScore s.IdealL2Score];
rows=cell(numel(rules),18);
for i=1:numel(rules)
    idx=indices(i); c=C(idx,:); n=(c-ref.Ideal)./ref.Span;
    rows(i,:)={item.Scenario,item.Run,string(item.Method),string(rules{i}),idx, ...
        ruleScores(i),sum(c),sum(n),max(n),sqrt(sum(n.^2)), ...
        c(1),c(2),c(3),c(4),n(1),n(2),n(3),n(4)};
end
end

function names=localRepresentativeNames()
names={'Scenario','Run','Method','Rule','ArchiveIndex','RuleScore', ...
    'RawEqualSum','NormalizedSum','NormalizedMax','NormalizedL2', ...
    'F1','F2','F3','F4','N1','N2','N3','N4'};
end

function names=localRunNames(cfg)
names={'Scenario','Run','Method','ArchiveSizeRaw','ArchiveSizeUnique','NDArchiveSize', ...
    'PaperScore','NormSumScore','TchebyScore','IdealL2Score', ...
    'HVExactRaw','HVExactRawRatio','HVFrontNormROI','IGDPlusNorm','EpsilonPlusNorm', ...
    'SpacingL1Norm','SpreadNNCVNorm','GridDistributionSD','GridOccupiedCells'};
for k=cfg.CardinalityK
    names=[names,{sprintf('HVExactRaw_K%d',k),sprintf('HVExactRawRatio_K%d',k), ...
        sprintf('IGDPlusNorm_K%d',k),sprintf('HasK%d',k)}]; %#ok<AGROW>
end
names=[names,{'F1Min','F2Min','F3Min','F4Min', ...
    'F1Max','F2Max','F3Max','F4Max', ...
    'F1Mean','F2Mean','F3Mean','F4Mean','F1Std','F2Std','F3Std','F4Std','TaskFile'}];
end
function w=localRunWidth(cfg),w=numel(localRunNames(cfg));end

%% Summaries
function S=localSummaryByMethod(T,cfg)
methods=unique(T.Method,'stable'); rows=cell(0,localSummaryWidth(cfg));
for i=1:numel(methods)
    X=T(T.Method==methods(i),:);
    rows(end+1,:)=localSummaryRow(X,0,methods(i),cfg); %#ok<AGROW>
end
S=cell2table(rows,'VariableNames',localSummaryNames(cfg));
S=sortrows(S,{'MeanHVExactRaw','MeanIGDPlusNorm'},{'descend','ascend'});
end

function S=localSummaryByScenario(T,cfg)
scens=unique(T.Scenario);methods=unique(T.Method,'stable');rows=cell(0,localSummaryWidth(cfg));
for s=scens(:)'
    for i=1:numel(methods)
        X=T(T.Scenario==s & T.Method==methods(i),:);
        if isempty(X),continue;end
        rows(end+1,:)=localSummaryRow(X,s,methods(i),cfg); %#ok<AGROW>
    end
end
S=cell2table(rows,'VariableNames',localSummaryNames(cfg));
S=sortrows(S,{'Scenario','MeanHVExactRaw','MeanIGDPlusNorm'}, ...
    {'ascend','descend','ascend'});
end

function row=localSummaryRow(X,scenario,method,cfg)
metrics=localSummaryMetrics(cfg);
row={scenario,string(method),height(X)};
for i=1:numel(metrics)
    v=X.(metrics{i});
    row=[row,{mean(v,'omitnan'),std(v,0,'omitnan'),median(v,'omitnan'),localIQR(v)}]; %#ok<AGROW>
end
for k=cfg.CardinalityK
    row=[row,{mean(X.(sprintf('HasK%d',k)))}]; %#ok<AGROW>
end
end

function names=localSummaryNames(cfg)
names={'Scenario','Method','N'};
metrics=localSummaryMetrics(cfg);
for i=1:numel(metrics)
    m=metrics{i};
    names=[names,{['Mean' m],['Std' m],['Median' m],['IQR' m]}]; %#ok<AGROW>
end
for k=cfg.CardinalityK,names=[names,{sprintf('ValidK%dRate',k)}];end %#ok<AGROW>
end
function w=localSummaryWidth(cfg),w=numel(localSummaryNames(cfg));end
function metrics=localSummaryMetrics(cfg)
metrics={'PaperScore','NormSumScore','TchebyScore','IdealL2Score', ...
    'HVExactRaw','HVExactRawRatio','HVFrontNormROI','IGDPlusNorm','EpsilonPlusNorm', ...
    'SpacingL1Norm','SpreadNNCVNorm','GridDistributionSD','NDArchiveSize'};
for k=cfg.CardinalityK
    metrics=[metrics,{sprintf('HVExactRaw_K%d',k),sprintf('HVExactRawRatio_K%d',k), ...
        sprintf('IGDPlusNorm_K%d',k)}]; %#ok<AGROW>
end
end
function S=localObjectiveArchiveSummary(T)
base={'F1Min','F2Min','F3Min','F4Min','F1Max','F2Max','F3Max','F4Max', ...
    'F1Mean','F2Mean','F3Mean','F4Mean','F1Std','F2Std','F3Std','F4Std'};
names={'Scenario','Method','N'};
for i=1:numel(base)
    names=[names,{['Mean' base{i}],['Std' base{i}]}]; %#ok<AGROW>
end
rows=cell(0,numel(names));
scenarios=unique(T.Scenario);methods=unique(T.Method,'stable');
for sc=scenarios(:)'
    for m=1:numel(methods)
        X=T(T.Scenario==sc & T.Method==methods(m),:);
        if isempty(X),continue;end
        row={sc,methods(m),height(X)};
        for i=1:numel(base)
            v=X.(base{i});
            row=[row,{mean(v,'omitnan'),std(v,0,'omitnan')}]; %#ok<AGROW>
        end
        rows(end+1,:)=row; %#ok<AGROW>
    end
end
S=cell2table(rows,'VariableNames',names);
if ~isempty(S),S=sortrows(S,{'Scenario','Method'});end
end

function q=localIQR(v)
v=v(isfinite(v));
if isempty(v),q=NaN;return;end
q=localPercentile(v,75)-localPercentile(v,25);
end

%% Statistical protocol
function [P,PS,FRA,FRO]=localStatistics(T,cfg)
spec=localMetricSpec(cfg);
methods=string(unique(T.Method,'stable'));
requestedControl=string(cfg.ControlMethod);
controlIndex=find(strcmpi(methods,requestedControl),1,'first');
if isempty(controlIndex)
    error('NAV_Q2_ExportEvaluation:ControlMissing', ...
        'Control method %s was not found. Available methods: %s.', ...
        requestedControl,strjoin(cellstr(methods),', '));
end
control=methods(controlIndex);
scenarios=unique(T.Scenario);
hasControl=true;
pairRows=cell(0,22);
pairScenarioRows=cell(0,22);
rankRows=cell(0,10);
omniRows=cell(0,12);

for mi=1:size(spec,1)
    metric=spec{mi,1}; higher=spec{mi,2}; role=string(spec{mi,3});

    if hasControl
        % Overall paired scenario-run comparisons.
        metricStart=size(pairRows,1)+1;
        for j=1:numel(methods)
            base=methods(j);
            if base==control,continue;end
            [a,b,blocks]=localMatched(T,control,base,metric);
            pairRows(end+1,:)=localPairRow('Overall',NaN,metric,role,higher, ...
                control,base,a,b,blocks,cfg); %#ok<AGROW>
        end
        pairRows=localApplyHolmToBlock(pairRows,metricStart:size(pairRows,1),cfg);

        % Per-scenario paired comparisons. This prevents a pooled overall
        % test from hiding scenario-specific reversals.
        for sc=scenarios(:)'
            Ts=T(T.Scenario==sc,:);
            metricStart=size(pairScenarioRows,1)+1;
            for j=1:numel(methods)
                base=methods(j);
                if base==control,continue;end
                [a,b,blocks]=localMatched(Ts,control,base,metric);
                pairScenarioRows(end+1,:)=localPairRow('Scenario',sc,metric,role,higher, ...
                    control,base,a,b,blocks,cfg); %#ok<AGROW>
            end
            pairScenarioRows=localApplyHolmToBlock(pairScenarioRows, ...
                metricStart:size(pairScenarioRows,1),cfg);
        end
    end

    % Friedman/Iman-Davenport is exported overall and by scenario. Results
    % with too few complete paired blocks are explicitly marked ineligible.
    [rr,oo]=localFriedmanScope(T,'Overall',NaN,metric,role,higher,methods,cfg);
    rankRows=[rankRows;rr]; omniRows=[omniRows;oo]; %#ok<AGROW>
    for sc=scenarios(:)'
        [rr,oo]=localFriedmanScope(T(T.Scenario==sc,:),'Scenario',sc, ...
            metric,role,higher,methods,cfg);
        rankRows=[rankRows;rr]; omniRows=[omniRows;oo]; %#ok<AGROW>
    end
end

pairNames={'Scope','Scenario','Metric','MetricRole','HigherIsBetter','Control', ...
    'Baseline','NPairs','NEffective','MeanBenefitControl','MedianBenefitControl', ...
    'PMethod','PValue','HolmAdjustedP','RankBiserial','ControlWins','Ties', ...
    'ControlLosses','MinBlockKey','MaxBlockKey','InferenceEligible','SignificantHolm'};
P=cell2table(pairRows,'VariableNames',pairNames);
PS=cell2table(pairScenarioRows,'VariableNames',pairNames);
FRA=cell2table(rankRows,'VariableNames',{'Scope','Scenario','Metric','MetricRole', ...
    'HigherIsBetter','Method','AverageRank','NBlocks','NMethods','MeanMetric'});
FRO=cell2table(omniRows,'VariableNames',{'Scope','Scenario','Metric','MetricRole', ...
    'HigherIsBetter','NBlocks','NMethods','FriedmanChiSquare','FriedmanP', ...
    'ImanDavenportF','ImanDavenportP','InferenceEligible'});
end

function row=localPairRow(scope,scenario,metric,role,higher,control,base,a,b,blocks,cfg)
if higher,benefit=a-b;else,benefit=b-a;end % positive => control better
[p,rb,nEff,pMethod]=localSignedRank(benefit,cfg);
wins=sum(benefit>cfg.TieTolerance);
losses=sum(benefit<-cfg.TieTolerance);
ties=numel(benefit)-wins-losses;
eligible=nEff>=cfg.MinPairsForInference;
if isempty(blocks),minKey=NaN;maxKey=NaN;else,minKey=min(blocks);maxKey=max(blocks);end
row={string(scope),scenario,string(metric),string(role),higher,control,base, ...
    numel(benefit),nEff,mean(benefit,'omitnan'),median(benefit,'omitnan'), ...
    string(pMethod),p,NaN,rb,wins,ties,losses,minKey,maxKey,eligible,false};
end

function rows=localApplyHolmToBlock(rows,ix,cfg)
if isempty(ix),return;end
eligible=false(numel(ix),1);p=nan(numel(ix),1);
for q=1:numel(ix)
    eligible(q)=logical(rows{ix(q),21}) && isfinite(rows{ix(q),13});
    p(q)=rows{ix(q),13};
end
use=find(eligible);
if ~isempty(use)
    adj=localHolm(p(use));
    for q=1:numel(use)
        r=ix(use(q));
        rows{r,14}=adj(q);
        rows{r,22}=adj(q)<cfg.Alpha;
    end
end
end

function [rankRows,omniRows]=localFriedmanScope(Tscope,scope,scenario, ...
    metric,role,higher,methods,cfg)
rankRows=cell(0,10);omniRows=cell(0,12);
[M,~,usedMethods]=localCompleteMatrix(Tscope,metric,methods);
if isempty(M),return;end
if higher,MforRank=-M;else,MforRank=M;end
ranks=zeros(size(MforRank));tieTerm=0;
for r=1:size(MforRank,1)
    [ranks(r,:),ties]=localTiedRank(MforRank(r,:));
    tieTerm=tieTerm+sum(ties.^3-ties);
end
avg=mean(ranks,1);
N=size(M,1);K=size(M,2);
Q=12*N/(K*(K+1))*sum(avg.^2)-3*N*(K+1);
corr=1-tieTerm/(N*(K^3-K));
if corr>0,Q=Q/corr;end
pChi=gammainc(Q/2,(K-1)/2,'upper');
denom=N*(K-1)-Q;
if N<2
    % A one-block smoke test can report descriptive ranks and the
    % chi-square diagnostic, but the Iman-Davenport F transform has zero
    % denominator degrees of freedom and is not defined.
    F=NaN;pF=NaN;
elseif denom>0
    F=((N-1)*Q)/denom;
    x=((K-1)*F)/((K-1)*F+(N-1)*(K-1));
    pF=1-betainc(x,(K-1)/2,((N-1)*(K-1))/2);
else
    F=Inf;pF=0;
end
eligible=N>=cfg.MinBlocksForOmnibus;
for j=1:K
    rankRows(end+1,:)={string(scope),scenario,string(metric),string(role),higher, ...
        usedMethods(j),avg(j),N,K,mean(M(:,j),'omitnan')}; %#ok<AGROW>
end
omniRows(end+1,:)={string(scope),scenario,string(metric),string(role),higher, ...
    N,K,Q,pChi,F,pF,eligible};
end

function spec=localMetricSpec(cfg)
spec={ ...
    'PaperScore',false,'DecisionSensitivity'; ...
    'NormSumScore',false,'DecisionSensitivity'; ...
    'TchebyScore',false,'DecisionSensitivity'; ...
    'IdealL2Score',false,'DecisionSensitivity'; ...
    'HVExactRaw',true,'PrimaryPareto(P1)'; ...
    'IGDPlusNorm',false,'KeySecondaryPareto(K1)'; ...
    'EpsilonPlusNorm',false,'SecondarySet'; ...
    'SpacingL1Norm',false,'SecondaryDistribution'; ...
    'SpreadNNCVNorm',false,'SecondaryDistribution'; ...
    'GridDistributionSD',false,'ReferencePaperCompatibility'};
for k=cfg.CardinalityK
    role=localCardinalityRole(k);
    spec=[spec;{sprintf('HVExactRawRatio_K%d',k),true,role}; ...
        {sprintf('IGDPlusNorm_K%d',k),false,role}]; %#ok<AGROW>
end
end

function role=localCardinalityRole(k)
if k==10
    role='FormalCardinalitySensitivity(K10)';
elseif k==20
    role='ExploratoryCardinalitySensitivity(K20)';
else
    role=sprintf('ExploratoryCardinalitySensitivity(K%d)',k);
end
end

function [a,b,keys]=localMatched(T,ma,mb,metric)
A=T(T.Method==ma,{'Scenario','Run',metric});
B=T(T.Method==mb,{'Scenario','Run',metric});
keysA=A.Scenario*100000+A.Run;keysB=B.Scenario*100000+B.Run;
[keys,ia,ib]=intersect(keysA,keysB,'stable');
a=A.(metric)(ia);b=B.(metric)(ib);
ok=isfinite(a)&isfinite(b);a=a(ok);b=b(ok);keys=keys(ok);
end

function [M,keys,usedMethods]=localCompleteMatrix(T,metric,methods)
allKeys=unique(T.Scenario*100000+T.Run);
M=nan(numel(allKeys),numel(methods));
for j=1:numel(methods)
    X=T(T.Method==methods(j),:);kx=X.Scenario*100000+X.Run;
    [~,ia,ib]=intersect(allKeys,kx,'stable');M(ia,j)=X.(metric)(ib);
end
ok=all(isfinite(M),2);M=M(ok,:);keys=allKeys(ok);usedMethods=methods;
end

function [p,rb,n,pMethod]=localSignedRank(d,cfg)
d=double(d(:));d=d(isfinite(d));d=d(abs(d)>cfg.TieTolerance);n=numel(d);
if n==0,p=1;rb=0;pMethod='all-ties';return;end
[ranks,tieSizes]=localTiedRank(abs(d)');ranks=ranks(:);
wp=sum(ranks(d>0));wm=sum(ranks(d<0));rb=(wp-wm)/sum(ranks);
if n<=cfg.ExactSignedRankMaxN
    % Exact conditional distribution of W+ using dynamic programming.
    % Average ranks are integer or half-integer, so doubling makes them exact.
    r2=round(2*ranks);
    total=sum(r2);
    ways=zeros(1,total+1);ways(1)=1;
    for i=1:numel(r2)
        rr=r2(i);
        ways(rr+1:end)=ways(rr+1:end)+ways(1:end-rr);
    end
    support=0:total;
    obs=round(2*wp);
    dev=abs(obs-total/2);
    p=sum(ways(abs(support-total/2)>=dev-1e-12))/(2^n);
    p=min(max(p,0),1);
    pMethod='exact-dp';
else
    mu=n*(n+1)/4;
    varW=n*(n+1)*(2*n+1)/24-sum(tieSizes.^3-tieSizes)/48;
    if varW<=0,p=1;pMethod='normal-degenerate';return;end
    z=(abs(wp-mu)-0.5)/sqrt(varW);z=max(z,0);
    p=erfc(z/sqrt(2));p=min(max(p,0),1);
    pMethod='normal-tie-corrected';
end
end

function adj=localHolm(p)
p=double(p(:));m=numel(p);[ps,ord]=sort(p);as=zeros(m,1);running=0;
for i=1:m
    running=max(running,(m-i+1)*ps(i));as(i)=min(1,running);
end
adj=zeros(m,1);adj(ord)=as;
end

function [ranks,tieSizes]=localTiedRank(x)
x=double(x(:)');[xs,ord]=sort(x,'ascend');r=zeros(size(xs));tieSizes=[];i=1;
while i<=numel(xs)
    j=i;while j<numel(xs)&&abs(xs(j+1)-xs(i))<=1e-12*max(1,abs(xs(i))),j=j+1;end
    r(i:j)=mean(i:j);tieSizes(end+1)=j-i+1; %#ok<AGROW>
    i=j+1;
end
ranks=zeros(size(r));ranks(ord)=r;
end

%% Initialization audit
function A=localInitializationAudit(formalDir,cfg)
poolDir=fullfile(formalDir,'shared_pools');
consumedTarget=localInferConsumedSlots(formalDir,cfg.InitialConsumedSlots);
rows=cell(0,numel(localInitNames()));
if exist(poolDir,'dir')~=7
    A=cell2table(rows,'VariableNames',localInitNames());return;
end
files=dir(fullfile(poolDir,'*.mat'));
for i=1:numel(files)
    fp=fullfile(files(i).folder,files(i).name);
    try
        S=load(fp);
        scenario=NaN;seed=NaN;
        if isfield(S,'scenario'),scenario=double(S.scenario);end
        if isfield(S,'seed'),seed=double(S.seed);end
        poolSlots=NaN;
        if isfield(S,'pool'),poolSlots=numel(S.pool);end
        consumedSlots=min(consumedTarget,max(0,poolSlots));

        fullVectors=localPoolVectors(S,Inf);
        consumedVectors=localPoolVectors(S,consumedSlots);
        fullUnique=size(localUniqueRows(fullVectors),1);
        consumedUnique=size(localUniqueRows(consumedVectors),1);
        fullRatio=fullUnique/max(1,poolSlots);
        consumedRatio=consumedUnique/max(1,consumedSlots);
        [minNN,meanNN]=localDecisionNN(consumedVectors,scenario);

        poolProtocol="legacy-or-unknown";
        if isfield(S,'poolProtocol') && ~isempty(S.poolProtocol)
            poolProtocol=string(S.poolProtocol);
        elseif isfield(S,'poolAudit') && isstruct(S.poolAudit) && ...
                isfield(S.poolAudit,'Protocol')
            poolProtocol=string(S.poolAudit.Protocol);
        end
        candidateBank=NaN;minPoolScore=NaN;meanPoolScore=NaN;
        if isfield(S,'poolAudit') && isstruct(S.poolAudit)
            if isfield(S.poolAudit,'CandidateBankSize'),candidateBank=double(S.poolAudit.CandidateBankSize);end
            if isfield(S.poolAudit,'MinPaperScore'),minPoolScore=double(S.poolAudit.MinPaperScore);end
            if isfield(S.poolAudit,'MeanPaperScore'),meanPoolScore=double(S.poolAudit.MeanPaperScore);end
        end

        rows(end+1,:)={scenario,seed,poolSlots,consumedSlots,consumedUnique, ...
            consumedRatio,consumedRatio>=cfg.InitUniqueRatioTarget, ...
            fullUnique,fullRatio,minNN,meanNN,poolProtocol,candidateBank, ...
            minPoolScore,meanPoolScore,string(fp),string(files(i).name)}; %#ok<AGROW>
    catch ME
        warning('ARCMOVWO:Q2Evaluation:PoolAudit','Skip %s: %s',fp,ME.message);
    end
end
A=cell2table(rows,'VariableNames',localInitNames());
if ~isempty(A),A=sortrows(A,{'Scenario','Seed'});end
end

function n=localInferConsumedSlots(formalDir,defaultValue)
n=defaultValue;
files=dir(fullfile(formalDir,'tasks','*.mat'));
values=zeros(0,1);
for i=1:min(numel(files),30)
    taskFile=fullfile(files(i).folder,files(i).name);
    try
        % Query the MAT-file directory before loading. MATLAB otherwise
        % emits "variable params not found" warnings for legacy/test files.
        info=whos('-file',taskFile);
        if ~any(strcmp({info.name},'params'))
            continue;
        end
        S=load(taskFile,'params');
        if isfield(S,'params') && isstruct(S.params) && ...
                isfield(S.params,'nPop') && isnumeric(S.params.nPop) && ...
                isscalar(S.params.nPop) && isfinite(S.params.nPop)
            values(end+1,1)=double(S.params.nPop); %#ok<AGROW>
        end
    catch ME
        warning('ARCMOVWO:Q2Evaluation:ConsumedSlotAudit', ...
            'Could not inspect %s: %s',taskFile,ME.message);
    end
end
values=unique(round(values(values>0)));
if numel(values)==1
    n=values;
elseif numel(values)>1
    warning('ARCMOVWO:Q2Evaluation:MixedPopulationSizes', ...
        'Task files contain multiple nPop values %s; initialization audit uses %d.', ...
        mat2str(values(:)'),defaultValue);
end
end

function names=localInitNames()
names={'Scenario','Seed','PoolSlots','ConsumedSlots','UniqueConsumedPaths', ...
    'ConsumedUniqueRatio','PassTarget','FullPoolUniquePaths','FullPoolUniqueRatio', ...
    'MinDecisionNN','MeanDecisionNN','PoolProtocol','CandidateBankSize', ...
    'MinPoolPaperScore','MeanPoolPaperScore','PoolFile','FileName'};
end

function V=localPoolVectors(S,nTake)
V=[];
if isfield(S,'pool') && ~isempty(S.pool)
    P=S.pool(:);
    if isfinite(nTake),P=P(1:min(numel(P),max(0,round(nTake))));end
    V=zeros(0,0);
    for j=1:numel(P)
        try
            v=NAV_EncodePosition(P{j});
        catch
            try,v=NAV_EncodePosition(P(j));catch,v=[];end
        end
        if isempty(v),continue;end
        if isempty(V),V=zeros(0,numel(v));end
        if numel(v)==size(V,2),V(end+1,:)=double(v(:)');end %#ok<AGROW>
    end
elseif isfield(S,'vectors')
    V=double(S.vectors);
    if isfinite(nTake),V=V(1:min(size(V,1),max(0,round(nTake))),:);end
end
end

function U=localUniqueRows(V)
if isempty(V),U=zeros(0,size(V,2));return;end
scale=max(1,max(abs(V),[],1));
Q=round(V./(1e-10.*scale)).*(1e-10.*scale);
[~,ia]=unique(Q,'rows','stable');
U=V(sort(ia),:);
end

function [mn,av]=localDecisionNN(V,scenario)
V=localUniqueRows(V);
if size(V,1)<2,mn=NaN;av=NaN;return;end
hadPlotFlag=isappdata(0,'NAV_DISABLE_MODEL_PLOT');
oldPlotFlag=[];
if hadPlotFlag,oldPlotFlag=getappdata(0,'NAV_DISABLE_MODEL_PLOT');end
cleanup=onCleanup(@()localRestorePlotFlag(hadPlotFlag,oldPlotFlag)); %#ok<NASGU>
try
    setappdata(0,'NAV_DISABLE_MODEL_PLOT',true);
    model=CreateModel(scenario);close all force;
    [vmin,vmax]=NAV_NavigationBounds(model);
    [lb,ub]=NAV_VectorBounds(model.n,vmin,vmax);
    N=(V-lb)./max(ub-lb,1e-12);
catch
    lo=min(V,[],1);sp=max(max(V,[],1)-lo,1e-12);N=(V-lo)./sp;
end
AA=sum(N.^2,2);D2=max(0,AA+AA'-2*(N*N'));
D=sqrt(D2);D(1:size(D,1)+1:end)=Inf;
d=min(D,[],2);mn=min(d);av=mean(d);
end

function localRestorePlotFlag(hadFlag,oldValue)
try
    if hadFlag
        setappdata(0,'NAV_DISABLE_MODEL_PLOT',oldValue);
    elseif isappdata(0,'NAV_DISABLE_MODEL_PLOT')
        rmappdata(0,'NAV_DISABLE_MODEL_PLOT');
    end
catch
end
end

function S=localInitializationSummary(A,cfg)
names={'Scenario','NSeeds','MeanUniquePaths','MinUniquePaths','MaxUniquePaths', ...
    'MeanUniqueRatio','MinUniqueRatio','PassRateAtTarget','FailedSeeds', ...
    'TargetUniqueRatio','ConsumedSlots','GatePass'};
if isempty(A)
    S=cell2table(cell(0,numel(names)),'VariableNames',names);return;
end
rows=cell(0,numel(names));
scenarios=unique(A.Scenario);
for sc=scenarios(:)'
    X=A(A.Scenario==sc,:);
    passRate=mean(X.PassTarget);
    rows(end+1,:)={sc,height(X),mean(X.UniqueConsumedPaths), ...
        min(X.UniqueConsumedPaths),max(X.UniqueConsumedPaths), ...
        mean(X.ConsumedUniqueRatio),min(X.ConsumedUniqueRatio),passRate, ...
        sum(~X.PassTarget),cfg.InitUniqueRatioTarget,median(X.ConsumedSlots), ...
        passRate==1}; %#ok<AGROW>
end
passRate=mean(A.PassTarget);
rows(end+1,:)={0,height(A),mean(A.UniqueConsumedPaths),min(A.UniqueConsumedPaths), ...
    max(A.UniqueConsumedPaths),mean(A.ConsumedUniqueRatio),min(A.ConsumedUniqueRatio), ...
    passRate,sum(~A.PassTarget),cfg.InitUniqueRatioTarget,median(A.ConsumedSlots), ...
    passRate==1};
S=cell2table(rows,'VariableNames',names);
end

%% Utilities and documentation
function C=localUniqueTol(C,tol)
if isempty(C),return;end
scale=max(1,max(abs(C),[],1));Q=round(C./(tol.*scale)).*(tol.*scale);
[~,ia]=unique(Q,'rows','stable');C=C(sort(ia),:);
end

function p=localPercentile(v,q)
v=sort(double(v(:)));n=numel(v);
if n==0,p=NaN;return;end
pos=1+(n-1)*q/100;lo=floor(pos);hi=ceil(pos);
if lo==hi,p=v(lo);else,p=v(lo)+(pos-lo)*(v(hi)-v(lo));end
end

function localWriteReadme(outDir,formalDir,cfg,T,refs)
fid=fopen(fullfile(outDir,'README_Q2_EVALUATION_V3.md'),'w');if fid<0,return;end
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# MO-UAV-EVAL-V1.0 Q2 set-quality evaluation\n\n');
fprintf(fid,'Protocol version: `%s`\n\n',cfg.ProtocolVersion);
fprintf(fid,'Source results: `%s`\n\n',formalDir);
fprintf(fid,'This exporter is evaluation-only. It does not modify the optimizers, objective functions, constraints, random-number sequence, or FE budget.\n\n');
fprintf(fid,'## Endpoint hierarchy\n\n');
fprintf(fid,'- P1 `HVExactRaw`: primary Pareto-set endpoint, exact 4-D hypervolume on the original bounded F1-F4 scale with fixed reference point `%s`.\n',mat2str(cfg.RawHVReference));
fprintf(fid,'- K1 `IGDPlusNorm`: mandatory key secondary Pareto endpoint against the frozen pooled best-known non-dominated reference set.\n');
fprintf(fid,'- `PaperScore`: F1+F2+F3+F4 representative-path score retained only as decision-rule sensitivity; it is not a primary endpoint or overall algorithm rank.\n\n');
fprintf(fid,'## Sensitivity and secondary metrics\n\n');
fprintf(fid,'- `HVExactRawRatio`: primary raw-objective HV divided by the fixed reference-box volume; it lies in [0,1] and has the same ranking as HVExactRaw.\n');
fprintf(fid,'- `HVFrontNormROI`: diagnostic front-normalized region-of-interest HV. Zero values are possible when a set does not enter the fixed ROI, so this metric is not used as the primary HV.\n');
fprintf(fid,'- `EpsilonPlusNorm`, `SpacingL1Norm`, and `SpreadNNCVNorm` are secondary indicators.\n');
fprintf(fid,'- `GridDistributionSD = n_p/n_o` (M=%d) and F1-F4 max/min/mean/std are exported for direct compatibility with the NMOPSO reference-paper evaluation.\n',cfg.GridDivisions);
fprintf(fid,'- Representative-solution sensitivity: raw equal sum, scenario-normalized sum, augmented Tchebycheff (rho=%.4g), and normalized ideal-point L2.\n',cfg.AugmentedTchebyRho);
fprintf(fid,'- K10 cardinality-controlled indicators are formal sensitivity analyses. K20 indicators are exploratory supplements only. Every K result must disclose valid rate and matched-pair count; low-coverage K20 results are not confirmatory.\n\n');
fprintf(fid,'## Statistical protocol\n\n');
fprintf(fid,'- Paired scenario-run blocks and separate per-scenario paired tests.\n');
fprintf(fid,'- Exact dynamic-programming Wilcoxon signed-rank p-values for n<=%d; tie-corrected normal approximation above that.\n',cfg.ExactSignedRankMaxN);
fprintf(fid,'- Holm correction against control `%s`, rank-biserial effect size, and wins/ties/losses.\n',cfg.ControlMethod);
fprintf(fid,'- Tests with fewer than %d effective pairs and omnibus analyses with fewer than %d complete blocks are marked inference-ineligible.\n\n',cfg.MinPairsForInference,cfg.MinBlocksForOmnibus);
fprintf(fid,'## Frozen reference sets\n\n');
for i=1:numel(refs)
    fprintf(fid,'- Scenario %d: pooled ND=%d, stored=%d, ideal=%s, nadir=%s, normalized ROI ref=%s.\n', ...
        refs(i).Scenario,refs(i).PooledNDCount,refs(i).StoredCount, ...
        mat2str(refs(i).Ideal,6),mat2str(refs(i).Nadir,6), ...
        mat2str(refs(i).NormalizedROIReference,6));
    fprintf(fid,'  ReferenceSetID `%s`; algorithms `%s` (%s); run roster entries=%d (%s).\n', ...
        refs(i).ReferenceSetID,refs(i).AlgorithmRosterText,refs(i).AlgorithmRosterHash, ...
        refs(i).RunRosterEntryCount,refs(i).RunRosterHash);
end
fprintf(fid,'\nReference files carry protocol, algorithm-roster, and run-roster identities. Earlier references and references built from a different roster are rebuilt automatically and must not be mixed with MO-UAV-EVAL-V1.0 tables.\n\n');
fprintf(fid,'## Initialization audit\n\n');
fprintf(fid,['The %.2f unique-ratio threshold is applied to the shared-position prefix actually consumed by the optimizers (nPop inferred from task files; fallback %d), not to unused reserve slots. ' ...
    'Full-pool uniqueness is reported separately.\n\n'],cfg.InitUniqueRatioTarget,cfg.InitialConsumedSlots);
fprintf(fid,'Valid task archives evaluated: %d.\n',height(T));
end
