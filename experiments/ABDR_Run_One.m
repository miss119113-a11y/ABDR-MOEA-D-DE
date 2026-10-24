function row = ABDR_Run_One(s,r,opts)
%ABDR_RUN_ONE Execute one proposed-method task with an exact FE cap.
% To match the paper's shared-initialization protocol, supply PoolDir
% containing S<scene>_seed<seed>.mat files with variable 'pool'.
if nargin < 3, opts = struct(); end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'algorithm'),fullfile(root,'algorithm','core'),'-begin');
seed = 260825000 + 100*s + r;
p = ABDR_Config(seed);
if isfield(opts,'BI'), p.EnableAPB=logical(opts.BI); p.TriadPBB=p.EnableAPB; end
if isfield(opts,'DQR'), p.EnableDQR=logical(opts.DQR); p.CodexArchiveGuide=p.EnableDQR; end
if isfield(opts,'SHDE'), p.AdaptiveDE=logical(opts.SHDE); p.MultiMemoryCR=p.AdaptiveDE; end
setappdata(0,'NAV_COST_MODE','physical_v2');
setappdata(0,'NAV_DISABLE_MODEL_PLOT',true);
setappdata(0,'NAV_SCENARIO_ID',s);
setappdata(0,'NAV_FE_LIMIT',6000);
setappdata(0,'NAV_FE_ATTEMPTED',0);
setappdata(0,'NAV_FE_EVALUATED',0);
if isappdata(0,'NAV_SHARED_INIT_POOL'), rmappdata(0,'NAV_SHARED_INIT_POOL'); end
if isappdata(0,'NAV_SHARED_INIT_CURSOR'), rmappdata(0,'NAV_SHARED_INIT_CURSOR'); end
if isappdata(0,'NAV_TERRAIN_FILE_OVERRIDE'), rmappdata(0,'NAV_TERRAIN_FILE_OVERRIDE'); end
if isfield(opts,'TerrainFile') && ~isempty(opts.TerrainFile)
    assert(isfile(opts.TerrainFile),'TerrainFile not found.');
    setappdata(0,'NAV_TERRAIN_FILE_OVERRIDE',opts.TerrainFile);
end
if isfield(opts,'PoolDir') && ~isempty(opts.PoolDir)
    poolFile=fullfile(opts.PoolDir,sprintf('S%d_seed%d.mat',s,seed));
    assert(isfile(poolFile),'Shared initial pool missing: %s',poolFile);
    P=load(poolFile,'pool');
    assert(isfield(P,'pool') && numel(P.pool)>=30,'Pool must contain 30 feasible solutions.');
    setappdata(0,'NAV_SHARED_INIT_POOL',P.pool(1:30));
    setappdata(0,'NAV_SHARED_INIT_CURSOR',1);
elseif ~isfield(opts,'AllowUnmatchedInitialization') || ~opts.AllowUnmatchedInitialization
    error('ABDR:MissingPool','PoolDir is required for paper-matched runs. For a functional example, set AllowUnmatchedInitialization=true.');
end
rng(seed,'twister');
timer=tic;
[rep,best,history]=ABDR_MOEAD_DE(p);
elapsed=toc(timer);
fe=double(getappdata(0,'NAV_FE_EVALUATED'));
assert(fe==6000,'Exact-6000 requirement not satisfied (observed %g).',fe);
costs=reshape([rep.Cost],4,[])';
row=struct('Scenario',s,'Run',r,'Seed',seed, ...
    'Method',"ABDR-MOEA/D-DE",'F1',best.Cost(1), ...
    'F2',best.Cost(2),'F3',best.Cost(3),'F4',best.Cost(4), ...
    'HV',NAV_Q2_HypervolumeExact(costs,[1.1 1.1 1.1 1.1]), ...
    'IGDPlus',NaN,'RuntimeSec',elapsed,'FEEvaluated',fe, ...
    'ArchiveSize',numel(rep),'BI',logical(p.EnableAPB), ...
    'DQR',logical(p.EnableDQR),'SHDE',logical(p.AdaptiveDE));
if isfield(opts,'ReferenceFile') && isfile(opts.ReferenceFile)
    R=load(opts.ReferenceFile);
    reference=R.reference;
    normalized=(costs-reference.Ideal)./reference.Span;
    row.IGDPlus=NAV_Q2_IGDPlus(reference.NormalizedFront,normalized);
end
if isfield(opts,'OutputDir') && ~isempty(opts.OutputDir)
    if ~isfolder(opts.OutputDir),mkdir(opts.OutputDir);end
    save(fullfile(opts.OutputDir,sprintf('ABDR_S%d_R%02d.mat',s,r)), ...
        'row','p','rep','best','history','-v7.3');
end
end
