function [pool,vectors,costs,audit] = NAV_BuildNeutralSharedInitialPool( ...
    model,VarSize,VarMin,VarMax,CostFunction,params,nPool,opts)
%NAV_BUILDNEUTRALSHAREDINITIALPOOL Build a neutral shared feasible pool.
%   All optimizers consume the same ordered pool. The first ActiveCount
%   members are selected by a quality-diversity protocol that prevents the
%   decision-space-only initialization pathology in which almost all paths
%   have F3 close to one. The protocol does not optimize for one algorithm:
%   it preserves objective extremes, several quality strata, objective-space
%   coverage, and decision-space diversity under explicit F3 guardrails.
%
%   Candidate generation is performed once per scenario/seed outside the
%   timed optimizer run. Every selected member is evaluated again inside each
%   optimizer and therefore remains part of its common FE budget.

if nargin < 8 || isempty(opts), opts = struct(); end
validateattributes(nPool,{'numeric'},{'scalar','integer','positive'});
params = NAV_DefaultParams(params);

cfg.Protocol = localGet(opts,'Protocol','Q2-NEUTRAL-QD-SHARED-INIT-V3');
cfg.ActiveCount = min(nPool,localGet(opts,'ActiveCount',min(24,nPool)));
cfg.MinUnique = localGet(opts,'MinUnique',nPool);
cfg.RequireFullUnique = logical(localGet(opts,'RequireFullUnique',true));
cfg.TargetBankSize = localGet(opts,'TargetBankSize',max(10*nPool,360));
cfg.MaxBaseCalls = localGet(opts,'MaxBaseCalls',max(6*nPool,180));
cfg.MaxPerturbCalls = localGet(opts,'MaxPerturbCalls',max(70*nPool,2800));
cfg.UniqueTolerance = localGet(opts,'UniqueTolerance',1e-9);
cfg.PerturbScales = localGet(opts,'PerturbScales',[0.003 0.006 0.012 0.022 0.040]);
cfg.LowF3Threshold = localGet(opts,'LowF3Threshold',0.40);
cfg.HighF3Threshold = localGet(opts,'HighF3Threshold',0.90);
cfg.MinLowF3Ratio = localGet(opts,'MinLowF3Ratio',0.25);
cfg.MaxHighF3Ratio = localGet(opts,'MaxHighF3Ratio',0.25);
cfg.QualityUpperQuantile = localGet(opts,'QualityUpperQuantile',0.90);
cfg.DecisionWeight = localGet(opts,'DecisionWeight',0.55);
cfg.ObjectiveWeight = localGet(opts,'ObjectiveWeight',0.35);
cfg.TierWeight = localGet(opts,'TierWeight',0.10);
cfg.LowF3BankBuffer = localGet(opts,'LowF3BankBuffer', ...
    max(ceil(1.5*ceil(cfg.MinLowF3Ratio*cfg.ActiveCount)), ...
        ceil(cfg.MinLowF3Ratio*cfg.ActiveCount)+2));
cfg.MaxLowF3EnrichCalls = localGet(opts,'MaxLowF3EnrichCalls', ...
    max(900,35*nPool));
maxHighActive = floor(cfg.MaxHighF3Ratio*cfg.ActiveCount+1e-12);
requiredNonHighActive = max(0,cfg.ActiveCount-maxHighActive);
cfg.NonHighF3BankBuffer = localGet(opts,'NonHighF3BankBuffer', ...
    requiredNonHighActive);
cfg.MaxNonHighF3EnrichCalls = localGet(opts,'MaxNonHighF3EnrichCalls', ...
    max(1200,45*nPool));

nVar = model.n;
[lb,ub] = NAV_VectorBounds(nVar,VarMin,VarMax);
span = max(ub-lb,eps);

bankPos = cell(0,1);
bankVec = zeros(0,3*nVar);
bankCost = zeros(0,4);
baseCalls = 0;
perturbCalls = 0;

% Phase A1: structured horizontal corridor templates. Pitch increments are
% deliberately kept small; lateral diversity is created mainly through phi.
% This avoids manufacturing a population whose only diversity is altitude
% error while still retaining multiple left/right and multi-turn corridors.
angleSet = [0 0.10 0.16 0.24 0.34 0.46];
scaleSet = [0.90 1.00 1.10];
for a = 1:cfg.MaxBaseCalls
    pos = localNeutralTemplate(model,VarMin,VarMax,params,a,angleSet,scaleSet);
    [cost, evalOK] = NAV_FE_Evaluate(CostFunction, pos);
    if ~evalOK, break; end
    baseCalls = baseCalls + 1;
    [bankPos,bankVec,bankCost] = localTryAppend( ...
        bankPos,bankVec,bankCost,pos,cost,cfg.UniqueTolerance);
    if size(bankVec,1) >= max(ceil(0.35*cfg.TargetBankSize),2*nPool)
        break;
    end
end

% Phase A2: retain some paths from the frozen feasible generator. This keeps
% the pool connected to the original protocol and supplies terrain/threat
% patterns not represented by the deterministic corridor family.
seedParams = params;
seedParams.initMaxTry = max(localGet(params,'initMaxTry',45),55);
seedParams.guidedInitRatio = min(max(localGet(params,'guidedInitRatio',0.70),0.55),0.85);
for a = 1:cfg.MaxBaseCalls
    [pos,cost] = NAV_CreateFeasibleSolution( ...
        model,VarSize,VarMin,VarMax,CostFunction,seedParams);
    baseCalls = baseCalls + 1;
    [bankPos,bankVec,bankCost] = localTryAppend( ...
        bankPos,bankVec,bankCost,pos,cost,cfg.UniqueTolerance);
    if size(bankVec,1) >= max(ceil(0.55*cfg.TargetBankSize),3*nPool)
        break;
    end
end

if isempty(bankPos)
    error('NAV:NeutralSharedInitEmpty','No exact-feasible shared initializer was found.');
end

% Phase B: expand the feasible bank. The pitch perturbation is smaller than
% the lateral perturbation and is mean-reverting, while a minority of trials
% retain broader vertical exploration. All candidates still pass the frozen
% objective/constraint entry before they can enter the bank.
baseCount = numel(bankPos);
scaleCount = numel(cfg.PerturbScales);
for a = 1:cfg.MaxPerturbCalls
    if size(bankVec,1) >= cfg.TargetBankSize, break; end
    parentIndex = 1 + mod(a-1,baseCount);
    scale = cfg.PerturbScales(1 + mod(floor((a-1)/baseCount),scaleCount));
    parent = bankPos{parentIndex};
    trial = localNeutralPerturb(parent,span,nVar,scale,a);
    trial = NAV_ClampPosition(trial,VarMin,VarMax);
    [cost, evalOK] = NAV_FE_Evaluate(CostFunction, trial);
    if ~evalOK, break; end
    perturbCalls = perturbCalls + 1;
    [bankPos,bankVec,bankCost] = localTryAppend( ...
        bankPos,bankVec,bankCost,trial,cost,cfg.UniqueTolerance);
end

% Phase C: explicitly enrich the candidate bank with altitude-reasonable
% paths when the stochastic/structured phases do not provide enough of them.
% This is a shared pre-run initializer operation, not an Arc-specific repair.
% It preserves the formal F3 quota instead of weakening the gate after a
% one-candidate miss.
[bankPos,bankVec,bankCost,lowF3EnrichCalls] = localEnrichLowF3Bank( ...
    bankPos,bankVec,bankCost,span,nVar,VarMin,VarMax,CostFunction,cfg);
perturbCalls = perturbCalls + lowF3EnrichCalls;

% Phase D: guarantee enough non-high-F3 candidates to satisfy the active
% upper guardrail. Generalization terrains can make most feasible random paths
% vertically poor even when the low-F3 minimum is already met. Without this
% reserve, the selector can exhaust all non-high candidates before ActiveCount
% and the later reserve-fill stage can accidentally place high-F3 paths in the
% active block. Enrichment remains shared, pre-run and algorithm-neutral.
[bankPos,bankVec,bankCost,nonHighF3EnrichCalls] = localEnrichNonHighF3Bank( ...
    bankPos,bankVec,bankCost,span,nVar,VarMin,VarMax,CostFunction,cfg);
perturbCalls = perturbCalls + nonHighF3EnrichCalls;

nUnique = size(bankVec,1);
required = min(nPool,max(1,round(cfg.MinUnique)));
if cfg.RequireFullUnique, required = nPool; end
if nUnique < required
    error('NAV:NeutralSharedInitDiversity', ...
        'Only %d exact-feasible unique paths were built; required %d.', ...
        nUnique,required);
end

[selected,selectionAudit] = localSelectNeutralPool( ...
    bankVec,bankCost,nPool,cfg.ActiveCount,lb,ub,cfg);
[selected,quotaAudit] = localEnforceActiveF3Guardrails( ...
    selected,bankVec,bankCost,cfg.ActiveCount,lb,ub,cfg);
selectionAudit.QuotaEnforcement = quotaAudit;
pool = bankPos(selected);
vectors = bankVec(selected,:);
costs = bankCost(selected,:);

% Formal protocols require full uniqueness. The fallback is retained only
% for diagnostic callers that explicitly disable RequireFullUnique.
while numel(pool) < nPool
    sourceIndex = 1 + mod(numel(pool),numel(selected));
    pool{end+1,1} = pool{sourceIndex}; %#ok<AGROW>
    vectors(end+1,:) = vectors(sourceIndex,:); %#ok<AGROW>
    costs(end+1,:) = costs(sourceIndex,:); %#ok<AGROW>
end

X = (vectors-lb)./span;
D = localPairwiseDistance(X,X);
D(1:size(D,1)+1:end) = inf;
nearest = min(D,[],2);
if numel(nearest) <= 1
    minNN = NaN; meanNN = NaN;
else
    minNN = min(nearest); meanNN = mean(nearest);
end

active = 1:min(cfg.ActiveCount,size(costs,1));
activeCost = costs(active,:);
activeScore = sum(activeCost,2);
activeF3 = activeCost(:,3);
activeUnique = size(unique(round(vectors(active,:)/cfg.UniqueTolerance)* ...
    cfg.UniqueTolerance,'rows'),1);
lowRatio = mean(activeF3 < cfg.LowF3Threshold);
highRatio = mean(activeF3 > cfg.HighF3Threshold);
passGate = activeUnique==numel(active) && ...
    lowRatio+1e-12>=cfg.MinLowF3Ratio && ...
    highRatio<=cfg.MaxHighF3Ratio+1e-12;

% Fail before launching optimizers when a supposedly neutral formal pool is
% still altitude-degenerate. This prevents another biased full experiment.
if localGet(opts,'RequireNeutralGate',true) && ~passGate
    error('NAV:NeutralSharedInitGate', ...
        ['Neutral initializer gate failed: active unique %d/%d, ' ...
         'F3<%.2f ratio %.3f (target %.3f), F3>%.2f ratio %.3f (max %.3f).'], ...
        activeUnique,numel(active),cfg.LowF3Threshold,lowRatio,cfg.MinLowF3Ratio, ...
        cfg.HighF3Threshold,highRatio,cfg.MaxHighF3Ratio);
end

audit = struct();
audit.Protocol = cfg.Protocol;
audit.PopulationSlots = nPool;
audit.ActiveCount = numel(active);
audit.CandidateBankSize = nUnique;
audit.UniqueSelected = size(unique(round(vectors/cfg.UniqueTolerance)* ...
    cfg.UniqueTolerance,'rows'),1);
audit.UniqueRatio = audit.UniqueSelected/nPool;
audit.ActiveUnique = activeUnique;
audit.ActiveUniqueRatio = activeUnique/max(1,numel(active));
audit.MinDecisionNN = minNN;
audit.MeanDecisionNN = meanNN;
audit.BaseGeneratorCalls = baseCalls;
audit.PerturbationCalls = perturbCalls;
audit.LowF3EnrichmentCalls = lowF3EnrichCalls;
audit.NonHighF3EnrichmentCalls = nonHighF3EnrichCalls;
audit.LowF3CandidateCount = sum(bankCost(:,3)<cfg.LowF3Threshold);
audit.NonHighF3CandidateCount = sum(bankCost(:,3)<=cfg.HighF3Threshold+1e-12);
audit.LowF3BankBufferTarget = cfg.LowF3BankBuffer;
audit.NonHighF3BankBufferTarget = cfg.NonHighF3BankBuffer;
audit.MinPaperScore = min(sum(costs,2));
audit.MeanPaperScore = mean(sum(costs,2));
audit.ActiveMinPaperScore = min(activeScore);
audit.ActiveMeanPaperScore = mean(activeScore);
audit.ActiveMedianPaperScore = median(activeScore);
audit.ActiveF3Min = min(activeF3);
audit.ActiveF3Mean = mean(activeF3);
audit.ActiveF3Median = median(activeF3);
audit.ActiveF3Max = max(activeF3);
audit.ActiveLowF3Ratio = lowRatio;
audit.ActiveHighF3Ratio = highRatio;
audit.LowF3Threshold = cfg.LowF3Threshold;
audit.HighF3Threshold = cfg.HighF3Threshold;
audit.MinLowF3RatioTarget = cfg.MinLowF3Ratio;
audit.MaxHighF3RatioTarget = cfg.MaxHighF3Ratio;
audit.PassNeutralGate = passGate;
audit.Selection = selectionAudit;
end

function pos = localNeutralTemplate(model,VarMin,VarMax,params,attempt,angleSet,scaleSet)
[~,~,meta] = NAV_NavigationBounds(model);
n = model.n;
baseR = meta.DirectDistanceM/(n+1);
angle = angleSet(1+mod(attempt-1,numel(angleSet)));
scale = scaleSet(1+mod(floor((attempt-1)/numel(angleSet)),numel(scaleSet)));
direction = 2*mod(floor((attempt-1)/(numel(angleSet)*numel(scaleSet))),2)-1;
if direction==0, direction=1; end
pattern = 1+mod(floor((attempt-1)/(2*numel(angleSet)*numel(scaleSet))),4);

pos = struct('r',baseR*scale*ones(1,n),'phi',zeros(1,n),'psi',zeros(1,n));
pos.r = pos.r.*(0.97+0.06*rand(1,n));

switch pattern
    case 1
        i1=max(1,round(n/3)); i2=min(n,round(2*n/3));
        pos.phi(i1)=direction*angle;
        pos.phi(i2)=-direction*angle;
    case 2
        i1=max(1,round(n/4)); i2=max(i1+1,round(n/2)); i3=min(n,round(3*n/4));
        pos.phi([i1 i2 i3])=direction*[angle -1.4*angle 0.4*angle];
    case 3
        width=max(1,round(n/5)); ids=max(1,round(n/2)-width):min(n,round(n/2)+width);
        w=sin(linspace(0,pi,numel(ids)));
        pos.phi(ids)=direction*angle*w;
        if ids(end)<n, pos.phi(ids(end)+1)=-direction*0.65*angle; end
    otherwise
        pos.phi = 0.25*params.guidedAngleStd*randn(1,n);
        pos.phi = conv(pos.phi,[0.25 0.50 0.25],'same');
end

% Small, smooth pitch increments preserve altitude variety without making
% F3 the sole source of decision-space separation.
pitchScale = 0.10 + 0.15*mod(attempt,4);
pos.psi = pitchScale*params.guidedAngleStd*randn(1,n);
if n>=3, pos.psi=conv(pos.psi,[0.25 0.50 0.25],'same'); end
pos = NAV_ClampPosition(pos,VarMin,VarMax);
end

function trial = localNeutralPerturb(parent,span,nVar,scale,attempt)
trial = parent;
noiseR = localSmoothNoise(nVar);
noisePhi = localSmoothNoise(nVar);
noisePsi = localSmoothNoise(nVar);

trial.r = trial.r + scale*span(1:nVar).*noiseR;
trial.phi = trial.phi + scale*span(nVar+(1:nVar)).*noisePhi;
if mod(attempt,5)==0
    pitchFactor = 0.55;       % minority vertical-exploration trials
else
    pitchFactor = 0.18;       % altitude-stable majority
end
trial.psi = 0.92*trial.psi + pitchFactor*scale* ...
    span(2*nVar+(1:nVar)).*noisePsi;

mid = 1 + mod(attempt-1,nVar);
ids = max(1,mid-1):min(nVar,mid+1);
signValue = 2*mod(attempt,2)-1;
structured = min(0.09,1.3*scale);
weights = ones(size(ids));
if numel(weights)>1, weights([1 end])=0.6; end
if mod(attempt,4)<=1
    trial.phi(ids) = trial.phi(ids) + signValue*structured.*weights;
elseif mod(attempt,4)==2
    trial.r(ids) = trial.r(ids).*(1 + signValue*0.30*scale);
else
    trial.psi(ids) = trial.psi(ids) + signValue*0.20*structured.*weights;
end
end

function [P,V,C,calls] = localEnrichLowF3Bank(P,V,C,span,nVar,VarMin,VarMax,CostFunction,cfg)
% Add a small reserve of F3-reasonable candidates without optimizing the
% final pool for one algorithm. Parents are selected only from the common
% feasible bank and all generated candidates remain available to every method.
calls = 0;
target = max(ceil(cfg.MinLowF3Ratio*cfg.ActiveCount),cfg.LowF3BankBuffer);
if sum(C(:,3)<cfg.LowF3Threshold) >= target, return; end

for a=1:cfg.MaxLowF3EnrichCalls
    lowCount = sum(C(:,3)<cfg.LowF3Threshold);
    if lowCount >= target, break; end

    lowParents=find(C(:,3)<cfg.LowF3Threshold);
    if ~isempty(lowParents)
        [~,lowOrd]=sortrows([C(lowParents,3),sum(C(lowParents,:),2)],[1 2]);
        parentOrder=lowParents(lowOrd);
    else
        [~,ord]=sortrows([C(:,3),sum(C,2)],[1 2]);
        parentOrder=ord(1:min(max(6,2*target),numel(ord)));
    end
    parentCount=numel(parentOrder);
    parent = P{parentOrder(1+mod(a-1,parentCount))};

    trial = parent;
    scaleSet = [0.002 0.004 0.007 0.011 0.017];
    scale = scaleSet(1+mod(floor((a-1)/parentCount),numel(scaleSet)));
    noiseR = localSmoothNoise(nVar);
    noisePhi = localSmoothNoise(nVar);
    noisePsi = localSmoothNoise(nVar);

    % Retain horizontal/length diversity while mean-reverting pitch. This
    % produces genuinely distinct paths rather than clones of the low-F3
    % parent and avoids selecting altitude error as the diversity source.
    trial.r = trial.r + scale*span(1:nVar).*noiseR;
    trial.phi = trial.phi + 1.25*scale*span(nVar+(1:nVar)).*noisePhi;
    pitchShrink = 0.72 - 0.05*mod(a,4);
    trial.psi = pitchShrink*trial.psi + 0.045*scale* ...
        span(2*nVar+(1:nVar)).*noisePsi;

    mid = 1+mod(a-1,nVar);
    ids=max(1,mid-1):min(nVar,mid+1);
    signValue=2*mod(a,2)-1;
    trial.phi(ids)=trial.phi(ids)+signValue*min(0.035,1.1*scale);
    trial = NAV_ClampPosition(trial,VarMin,VarMax);

    [cost, evalOK] = NAV_FE_Evaluate(CostFunction, trial);
    if ~evalOK, break; end
    calls = calls + 1;
    [P,V,C] = localTryAppend(P,V,C,trial,cost,cfg.UniqueTolerance);
end
end

function [P,V,C,calls] = localEnrichNonHighF3Bank(P,V,C,span,nVar,VarMin,VarMax,CostFunction,cfg)
% Ensure the bank contains enough candidates with F3 at or below the high
% threshold to populate the formal active block without exceeding its cap.
calls = 0;
maxHigh = floor(cfg.MaxHighF3Ratio*cfg.ActiveCount+1e-12);
required = max(0,cfg.ActiveCount-maxHigh);
target = max(required,cfg.NonHighF3BankBuffer);
if sum(C(:,3)<=cfg.HighF3Threshold+1e-12) >= target, return; end

scaleSet = [0.0015 0.003 0.005 0.008 0.012];
shrinkSet = [0.88 0.80 0.72 0.64 0.56];
for a=1:cfg.MaxNonHighF3EnrichCalls
    if sum(C(:,3)<=cfg.HighF3Threshold+1e-12) >= target, break; end

    midParents=find(C(:,3)>=cfg.LowF3Threshold & C(:,3)<=cfg.HighF3Threshold+1e-12);
    highParents=find(C(:,3)>cfg.HighF3Threshold);
    lowParents=find(C(:,3)<cfg.LowF3Threshold);
    if ~isempty(midParents)
        [~,ord]=sortrows([sum(C(midParents,:),2),C(midParents,3)],[1 2]);
        parentOrder=midParents(ord);
        parentClass=1;
    elseif ~isempty(highParents)
        % Start from candidates closest to the high threshold, not the most
        % vertically degenerate paths.
        [~,ord]=sortrows([C(highParents,3),sum(C(highParents,:),2)],[1 2]);
        parentOrder=highParents(ord);
        parentClass=2;
    else
        [~,ord]=sortrows([sum(C(lowParents,:),2),C(lowParents,3)],[1 2]);
        parentOrder=lowParents(ord);
        parentClass=3;
    end
    if isempty(parentOrder), break; end

    parentCount=numel(parentOrder);
    parent=P{parentOrder(1+mod(a-1,parentCount))};
    scale=scaleSet(1+mod(floor((a-1)/parentCount),numel(scaleSet)));
    trial=parent;
    trial.r=trial.r + scale*span(1:nVar).*localSmoothNoise(nVar);
    trial.phi=trial.phi + 1.15*scale*span(nVar+(1:nVar)).*localSmoothNoise(nVar);

    if parentClass==2
        shrink=shrinkSet(1+mod(floor((a-1)/parentCount),numel(shrinkSet)));
        trial.psi=shrink*trial.psi + 0.025*scale* ...
            span(2*nVar+(1:nVar)).*localSmoothNoise(nVar);
    elseif parentClass==1
        trial.psi=(0.94+0.02*mod(a,3))*trial.psi + 0.018*scale* ...
            span(2*nVar+(1:nVar)).*localSmoothNoise(nVar);
    else
        trial.psi=0.98*trial.psi + 0.030*scale* ...
            span(2*nVar+(1:nVar)).*localSmoothNoise(nVar);
    end

    mid=1+mod(a-1,nVar);
    ids=max(1,mid-1):min(nVar,mid+1);
    trial.phi(ids)=trial.phi(ids)+(2*mod(a,2)-1)*min(0.025,scale);
    trial=NAV_ClampPosition(trial,VarMin,VarMax);
    [cost,evalOK]=NAV_FE_Evaluate(CostFunction,trial);
    if ~evalOK, break; end
    calls=calls+1;
    [P,V,C]=localTryAppend(P,V,C,trial,cost,cfg.UniqueTolerance);
end
end

function [selected,audit] = localEnforceActiveF3Guardrails(selected,V,F,activeCount,lb,ub,cfg)
% Deterministically enforce both formal F3 guardrails on the active block.
% This is a final safety step after the quality-diversity selector.
audit=struct('Applied',false,'BeforeLowCount',0,'AfterLowCount',0, ...
    'BeforeHighCount',0,'AfterHighCount',0,'TargetLowCount',0, ...
    'MaxHighCount',0,'HighReplacements',0,'LowReplacements',0);
activeCount=min(activeCount,numel(selected));
targetLow=ceil(cfg.MinLowF3Ratio*activeCount);
maxHigh=floor(cfg.MaxHighF3Ratio*activeCount+1e-12);
active=selected(1:activeCount);
audit.TargetLowCount=targetLow;
audit.MaxHighCount=maxHigh;
audit.BeforeLowCount=sum(F(active,3)<cfg.LowF3Threshold);
audit.BeforeHighCount=sum(F(active,3)>cfg.HighF3Threshold);

X=(V-lb)./max(ub-lb,eps);
Y=localNormalizeObjectives(F);
score=sum(F,2);
qRank=localFractionalRanks(score);

% First remove excess high-F3 members. Prefer moderate-F3 replacements so the
% low-F3 minimum does not turn into an unintended all-low active population.
while sum(F(active,3)>cfg.HighF3Threshold)>maxHigh
    candidates=find(F(:,3)<=cfg.HighF3Threshold+1e-12 & ...
        F(:,3)>=cfg.LowF3Threshold-1e-12);
    candidates=setdiff(candidates,selected,'stable');
    if isempty(candidates)
        candidates=find(F(:,3)<=cfg.HighF3Threshold+1e-12);
        candidates=setdiff(candidates,selected,'stable');
    end
    if isempty(candidates), break; end

    highSlots=find(F(active,3)>cfg.HighF3Threshold);
    nonProtected=highSlots(highSlots>4);
    if isempty(nonProtected), replaceable=highSlots; else, replaceable=nonProtected; end
    [~,rLocal]=max(score(active(replaceable)));
    slot=replaceable(rLocal);
    context=active; context(slot)=[];
    addIdx=localGreedyPick(candidates,context,X,Y,qRank,0.55,cfg);
    selected(slot)=addIdx;
    active=selected(1:activeCount);
    audit.Applied=true;
    audit.HighReplacements=audit.HighReplacements+1;
end

% Then meet the low-F3 minimum. Replace high members first when any remain;
% otherwise replace a poorer non-low member while protecting objective slots.
while sum(F(active,3)<cfg.LowF3Threshold)<targetLow
    candidates=find(F(:,3)<cfg.LowF3Threshold);
    candidates=setdiff(candidates,selected,'stable');
    if isempty(candidates), break; end
    replaceable=find(F(active,3)>=cfg.LowF3Threshold);
    highReplaceable=replaceable(F(active(replaceable),3)>cfg.HighF3Threshold);
    if ~isempty(highReplaceable)
        replaceable=highReplaceable;
    else
        nonProtected=replaceable(replaceable>4);
        if ~isempty(nonProtected), replaceable=nonProtected; end
    end
    if isempty(replaceable), break; end
    [~,rLocal]=max(score(active(replaceable)));
    slot=replaceable(rLocal);
    context=active; context(slot)=[];
    addIdx=localGreedyPick(candidates,context,X,Y,qRank,0.35,cfg);
    selected(slot)=addIdx;
    active=selected(1:activeCount);
    audit.Applied=true;
    audit.LowReplacements=audit.LowReplacements+1;
end

audit.AfterLowCount=sum(F(active,3)<cfg.LowF3Threshold);
audit.AfterHighCount=sum(F(active,3)>cfg.HighF3Threshold);
end

function [selected,audit] = localSelectNeutralPool(V,F,nKeep,activeCount,lb,ub,cfg)
n = size(V,1);
nKeep = min(nKeep,n);
activeCount = min(activeCount,nKeep);
X = (V-lb)./max(ub-lb,eps);
Y = localNormalizeObjectives(F);
score = sum(F,2);
qRank = localFractionalRanks(score);
selected = zeros(0,1);

% 1) Protect one strong direction for every objective. A high-F3 candidate
% is excluded when a non-degenerate alternative exists.
for j=1:4
    eligible = find(F(:,3)<=cfg.HighF3Threshold+1e-12);
    if isempty(eligible), eligible=(1:n)'; end
    [~,ord] = sortrows([F(eligible,j),score(eligible)],[1 2]);
    selected = localAppendUnique(selected,eligible(ord(1)));
end

% 2) Guarantee an altitude-reasonable share, selected for joint objective
% and decision diversity rather than for F3 alone.
lowTarget = ceil(cfg.MinLowF3Ratio*activeCount);
while sum(F(selected,3)<cfg.LowF3Threshold) < lowTarget
    eligible = find(F(:,3)<cfg.LowF3Threshold);
    eligible = setdiff(eligible,selected,'stable');
    if isempty(eligible), break; end
    idx = localGreedyPick(eligible,selected,X,Y,qRank,0.30,cfg);
    selected = localAppendUnique(selected,idx);
end

% 3) Reference directions cover extremes, pairwise compromises and the
% equal-preference centre without turning initialization into a C optimizer.
W = localReferenceDirections();
ideal = min(Y,[],1);
qualityLimit = localQuantile(score,cfg.QualityUpperQuantile);
for k=1:size(W,1)
    if numel(selected)>=min(activeCount,12), break; end
    eligible = find(score<=qualityLimit+1e-12 & ...
        F(:,3)<=cfg.HighF3Threshold+1e-12);
    eligible = setdiff(eligible,selected,'stable');
    if isempty(eligible), continue; end
    scalar = max(abs(Y(eligible,:)-ideal).*W(k,:),[],2) + ...
        0.05*sum(abs(Y(eligible,:)-ideal),2);
    [~,ord] = sort(scalar,'ascend');
    shortlist = eligible(ord(1:min(12,numel(ord))));
    idx = localGreedyPick(shortlist,selected,X,Y,qRank,0.25,cfg);
    selected = localAppendUnique(selected,idx);
end

% 4) Fill explicit quality strata. This prevents both an artificially elite
% pre-optimized pool and the previous almost-all-F3=1 pool.
q1=localQuantile(score,0.35);
q2=localQuantile(score,0.70);
q3=localQuantile(score,cfg.QualityUpperQuantile);
targets=[round(0.35*activeCount),round(0.35*activeCount), ...
    round(0.20*activeCount),activeCount];
bounds=[-inf q1; q1 q2; q2 q3; -inf q3];
centres=[0.18 0.52 0.80 0.50];
for tier=1:4
    target=min(activeCount,targets(tier));
    while numel(selected)<target
        eligible=find(score>bounds(tier,1)-1e-12 & ...
            score<=bounds(tier,2)+1e-12 & ...
            F(:,3)<=cfg.HighF3Threshold+1e-12);
        eligible=setdiff(eligible,selected,'stable');
        eligible=localApplyHighF3Cap(eligible,selected,F,activeCount,cfg);
        if isempty(eligible), break; end
        idx=localGreedyPick(eligible,selected,X,Y,qRank,centres(tier),cfg);
        selected=localAppendUnique(selected,idx);
    end
end

% 5) Robust active-population fallback. The F3 cap is maintained whenever
% candidates permit it; only then is the eligible region broadened.
while numel(selected)<activeCount
    eligible=find(F(:,3)<=cfg.HighF3Threshold+1e-12 & ...
        qRank<=cfg.QualityUpperQuantile+1e-12);
    eligible=setdiff(eligible,selected,'stable');
    eligible=localApplyHighF3Cap(eligible,selected,F,activeCount,cfg);
    if isempty(eligible)
        eligible=setdiff((1:n)',selected,'stable');
        eligible=localApplyHighF3Cap(eligible,selected,F,activeCount,cfg);
    end
    if isempty(eligible), break; end
    idx=localGreedyPick(eligible,selected,X,Y,qRank,0.55,cfg);
    selected=localAppendUnique(selected,idx);
end

% 6) Reserve members retain broader exploration, but still use joint
% objective/decision maximin rather than decision-space distance alone.
while numel(selected)<nKeep
    eligible=setdiff((1:n)',selected,'stable');
    if numel(selected)<activeCount
        eligible=localApplyHighF3Cap(eligible,selected,F,activeCount,cfg);
    end
    if isempty(eligible), break; end
    idx=localGreedyPick(eligible,selected,X,Y,qRank,0.65,cfg);
    selected=localAppendUnique(selected,idx);
end

active=selected(1:min(activeCount,numel(selected)));
audit=struct();
audit.ActiveCount=numel(active);
audit.ActiveMeanPaperScore=mean(score(active));
audit.ActiveMedianPaperScore=median(score(active));
audit.ActiveLowF3Ratio=mean(F(active,3)<cfg.LowF3Threshold);
audit.ActiveHighF3Ratio=mean(F(active,3)>cfg.HighF3Threshold);
audit.ActiveObjectiveMin=min(F(active,:),[],1);
audit.ActiveObjectiveMax=max(F(active,:),[],1);
audit.ActiveObjectiveStd=std(F(active,:),0,1);
end

function eligible=localApplyHighF3Cap(eligible,selected,F,activeCount,cfg)
maxHigh=floor(cfg.MaxHighF3Ratio*activeCount+1e-12);
currentHigh=sum(F(selected,3)>cfg.HighF3Threshold);
if currentHigh>=maxHigh
    eligible=eligible(F(eligible,3)<=cfg.HighF3Threshold+1e-12);
end
end

function idx=localGreedyPick(eligible,selected,X,Y,qRank,targetQ,cfg)
if isempty(selected)
    dDecision=ones(numel(eligible),1);
    dObjective=ones(numel(eligible),1);
else
    dDecision=min(localPairwiseDistance(X(eligible,:),X(selected,:)),[],2);
    dObjective=min(localPairwiseDistance(Y(eligible,:),Y(selected,:)),[],2);
end
tierFit=1-abs(qRank(eligible)-targetQ);
value=cfg.DecisionWeight*dDecision + cfg.ObjectiveWeight*dObjective + ...
    cfg.TierWeight*tierFit;
[~,k]=max(value);
idx=eligible(k);
end

function W=localReferenceDirections()
W=eye(4);
W(end+1,:)=0.25*ones(1,4);
for i=1:4
    for j=i+1:4
        w=zeros(1,4); w([i j])=0.5; W(end+1,:)=w; %#ok<AGROW>
    end
end
W=W./max(sum(W,2),eps);
end

function Y=localNormalizeObjectives(F)
lo=min(F,[],1); hi=max(F,[],1);
Y=(F-lo)./max(hi-lo,eps);
Y=min(max(Y,0),1);
end

function r=localFractionalRanks(x)
[~,ord]=sort(x,'ascend');
r=zeros(size(x));
if numel(x)==1, r(:)=0; return; end
r(ord)=linspace(0,1,numel(x))';
end

function q=localQuantile(x,p)
x=sort(double(x(:)),'ascend');
if isempty(x), q=NaN; return; end
p=min(max(double(p),0),1);
t=1+(numel(x)-1)*p;
i=floor(t); j=ceil(t);
if i==j, q=x(i); else, q=x(i)+(t-i)*(x(j)-x(i)); end
end

function selected=localAppendUnique(selected,idx)
if isempty(idx) || any(selected==idx), return; end
selected(end+1,1)=idx;
end

function z = localSmoothNoise(n)
z = randn(1,n);
if n >= 3, z = conv(z,[0.25 0.50 0.25],'same'); end
z = z/(std(z)+eps);
end

function [P,V,C] = localTryAppend(P,V,C,pos,cost,tol)
if ~localFeasible(cost) || isempty(pos), return; end
v = NAV_EncodePosition(pos);
if isempty(V)
    isNew = true;
else
    isNew = all(max(abs(V-v),[],2)>tol);
end
if ~isNew, return; end
P{end+1,1} = pos; %#ok<AGROW>
V(end+1,:) = v; %#ok<AGROW>
c = double(cost(:)');
C(end+1,:) = c(1:4); %#ok<AGROW>
end

function D = localPairwiseDistance(A,B)
AA = sum(A.^2,2);
BB = sum(B.^2,2)';
D2 = max(0,AA+BB-2*(A*B'));
D = sqrt(D2);
end

function tf = localFeasible(cost)
c = double(cost(:));
tf = numel(c)>=4 && all(isfinite(c(1:4))) && ...
    all(c(1:4)>=-1e-10) && all(c(1:4)<=1+1e-10);
end

function value = localGet(s,name,defaultValue)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    value = s.(name);
else
    value = defaultValue;
end
end
