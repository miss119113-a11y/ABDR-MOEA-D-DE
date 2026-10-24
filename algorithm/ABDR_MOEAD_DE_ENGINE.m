function [rep,best,history] = ABDR_MOEAD_DE_ENGINE(params)
%ABDR_MOEAD_DE_ENGINE Proposed MATLAB optimizer for UAV multiobjective path planning.
%   The final PBA-DQRF line has three independently testable search blocks:
%   PBB changes the single DE child's crossover mask according to the
%   parent's worst-ranked physical objective; Success-History DE updates DE
%   controls only from accepted offspring; fallback DQR permits at most one
%   successful replacement in each reference direction in a generation.
%   Archive diversity and evaluator shortcuts are separated from parent
%   replacement so they do not silently change a mechanism ablation.
%   No probe, repair, local search, or TotalCost-based search acceptance is
%   used.  Each processed parent evaluates at most one child.
%   FastSearchPath is an opt-in implementation path for the current PBA
%   line. It keeps the same child formula and random draws while removing
%   repeated validation calls and reusing generation-frozen scalar scores.

if nargin < 1 || isempty(params), params = struct(); end
params = NAV_DefaultParams(params);
params = localDefaults(params);
if isfield(params,'Seed') && ~isempty(params.Seed)
    rng(params.Seed,'twister');
end
NAV_DAG_DeploymentMetricsMemoBatch([],[],'clear');

[model,varSize,varMin,varMax,costFunction,nObj] = localProblem();
nVar = model.n;
[lb,ub] = NAV_VectorBounds(nVar,varMin,varMax);
% Precompute the PBB mask family once. The pressure objective is selected
% per parent, but the block geometry is invariant across the entire run.
if params.FastSearchPath && params.EnableAPB && strcmp(params.PressureMap,'coupled')
    pressureMasks = localPressureMasks(nVar);
else
    pressureMasks = [];
end
pop = repmat(localEmptyParticle(),params.nPop,1);
for i = 1:params.nPop
    [pos,cost] = NAV_CreateFeasibleSolution( ...
        model,varSize,varMin,varMax,costFunction,params);
    if isempty(pos) || isempty(cost) || ~all(isfinite(cost))
        error('APDP:Initialization', ...
            'Could not initialize population member %d.',i);
    end
    pop(i) = localParticle(pos,cost);
end

weights = NAV_GenerateWeights(params.nPop,nObj,'balanced');
% Reference directions are fixed for the whole run.  Keep their unit-norm
% form beside the original weights so DQR association does not renormalize
% the full direction matrix for every evaluated child.
if params.UseWeightCache
    weightsNormalized = double(weights) ./ max(vecnorm(double(weights),2,2),1e-12);
else
    weightsNormalized = [];
end
for i = 1:params.nPop
    pop(i).Weight = weights(i,:);
end
neighborhood = NAV_Neighborhood(weights,params.neighborSize);
globalParentPools = localParentPools(params.nPop,neighborhood,'global');
neighborhoodParentPools = localParentPools(params.nPop,neighborhood,'neighborhood');
parentPools = globalParentPools;
eligibleDirections = localEligibleDirections(neighborhood);
[rep,archiveAudit] = localUpdateArchive(repmat(localEmptyParticle(),0,1), ...
    pop,params);
if isempty(rep)
    error('APDP:InitializationArchive','Initial constrained Pareto archive is empty.');
end

history = localHistory(params.MaxIt,nObj,params);
pending = repmat(localEmptyParticle(),0,1);
adaptiveF = params.deF;
adaptiveCR = params.deCR;
controllerMode = params.ControllerMode;
controllerH = 5;
controllerContexts = 1;
if strcmp(controllerMode,'CONTEXT_H5_FIR'), controllerContexts = 4; end
useMultiMemoryCR = isfield(params, 'MultiMemoryCR') && params.MultiMemoryCR;
if useMultiMemoryCR
    if isfield(params, 'CustomMemoryCR') && ~isempty(params.CustomMemoryCR)
        memoryCR = repmat(params.CustomMemoryCR, controllerContexts, 1);
    else
        % Axiomatic Uniform Maximum-Entropy Spectrum across [0.1, 0.9]:
        % M_CR^{(0)} = [0.10, 0.30, 0.50, 0.70, 0.90] with equal prior p_h = 0.20
        memoryCR = repmat([0.10, 0.30, 0.50, 0.70, 0.90], controllerContexts, 1);
    end
    cellProb = repmat(1 / controllerH, controllerContexts, controllerH);
else
    memoryCR = repmat(params.deCR, controllerContexts, controllerH);
    cellProb = repmat(1 / controllerH, controllerContexts, controllerH);
end
memoryF = repmat(params.deF,controllerContexts,controllerH);
memoryPointer = ones(controllerContexts,1);
alpha_p = 0.25;
if isfield(params, 'ControllerAlphaP') && ~isempty(params.ControllerAlphaP)
    alpha_p = params.ControllerAlphaP;
elseif isfield(params, 'CustomAlphaP') && ~isempty(params.CustomAlphaP)
    alpha_p = params.CustomAlphaP;
end
history.ControllerAlphaP = alpha_p;
history.InitialMemoryCR = memoryCR;
history.InitialMemoryF = memoryF;
history.InitialCellProb = cellProb;
directPhysicalFE = logical(params.DirectPhysicalFE);
if directPhysicalFE
    % Initialization still uses the shared MyCost entry.  From this point
    % onward the generation capacity already enforces the FE limit, so the
    % child path can call the same physical evaluator without per-child
    % NAV_FE_Evaluate/getappdata dispatch.
    feLimit = localAppDataNumber('NAV_FE_LIMIT',inf);
    feAttempted = localAppDataNumber('NAV_FE_ATTEMPTED',0);
    feEvaluated = localAppDataNumber('NAV_FE_EVALUATED',0);
else
    feLimit = inf;
    feAttempted = 0;
    feEvaluated = 0;
end
tStart = tic;
codexGuideUseTotal=0;
for it = 1:params.MaxIt
    if directPhysicalFE
        remaining = max(0,feLimit-feEvaluated);
    else
        remaining = localRemainingFE();
    end
    if remaining <= 0, break; end

    % Freeze the parent statistics for the complete generation so that
    % within-generation order cannot alter APB pressure or scalarization.
    costs = localCostMatrix(pop);
    ideal = min(costs,[],1);
    nadir = max(costs,[],1);
    generationParetoQ = zeros(0,nObj);
    if strcmp(controllerMode,'GLOBAL_H5_FIR_CR_ARITH_ND')
        popFeasible = false(numel(pop),1);
        for qFeasible = 1:numel(pop), popFeasible(qFeasible) = localIsFeasible(pop(qFeasible).Cost); end
        repFeasible = false(numel(rep),1);
        for qFeasible = 1:numel(rep), repFeasible(qFeasible) = localIsFeasible(rep(qFeasible).Cost); end
        generationParetoQ = NAV_SHDE_FREEZE_PARETO_Q(localCostMatrix(rep), ...
            localCostMatrix(pop),repFeasible,popFeasible);
    end
    ndGatePassedCount = 0; ndGateDominatedRejectCount = 0; ndGateDuplicateRejectCount = 0;
    if params.FastSearchPath
        objectiveRanks = localObjectiveRanksFast(costs);
        bestNeighborhood = localBestNeighborhoodIndices( ...
            costs,neighborhood,weights,ideal,nadir,params.NormalizeDecomposition);
    else
        objectiveRanks = localObjectiveRanks(costs);
        bestNeighborhood = [];
    end
    guideArchiveCosts=localCostMatrix(rep);
    guideArchiveVectors=localVectorMatrix(rep);
    directionalQuota = zeros(params.nPop,1);
    accepted = 0;
    generatedCount = 0;
        matingNeighborProbability = localMatingProbability(params,it);
        if strcmp(params.MatingScope,'pressure')
            % High pressure widens the differential donor scope. The
            % normalized rank of each target's worst physical objective
            % determines its probability of using the local neighborhood;
            % a poorly ranked target is therefore more likely to draw from
            % the global population and escape a local search basin.
            rankPressure = max(objectiveRanks,[],2) ./ max(size(objectiveRanks,1),1);
            matingNeighborProbability = mean(1-rankPressure);
        end
    generationCapacity = min(params.nPop,max(0,floor(remaining)));
    if ~isfinite(generationCapacity), generationCapacity = params.nPop; end
    successF = zeros(generationCapacity,1);
    successCR = zeros(generationCapacity,1);
    successCell = zeros(generationCapacity,1);
    successWeight = zeros(generationCapacity,1);
    successCount = 0;
    successContext = zeros(generationCapacity,1);
    sampledF = nan(generationCapacity,1);
    sampledCR = nan(generationCapacity,1);
    sampledCell = zeros(generationCapacity,1);
    sampledContext = zeros(generationCapacity,1);
    excludedCreditCount = 0;
    generated = repmat(localEmptyParticle(),generationCapacity,1);
    popVectors = [];
    if params.FastSearchPath
        popVectors = localVectorMatrix(pop);
    end
    order = randperm(params.nPop);
    order = order(1:min(numel(order),remaining));
    for q = 1:numel(order)
        i = order(q);
        % Success-History DE samples the current memories before each child;
        % memory updates are deferred until all generation outcomes are known.
        if strcmp(controllerMode,'LEGACY')
            if params.AdaptiveDE
                [trialF,trialCR] = localSampleAdaptiveDE(adaptiveF,adaptiveCR);
            else
                trialF = params.deF;
                trialCR = params.deCR;
            end
            trialContext = 1;
            trialCell = 1;
        elseif ismember(controllerMode,{'GLOBAL_H5_FIR','GLOBAL_H5_FIR_CR_ARITH','GLOBAL_H5_FIR_CR_ARITH_ND'})
            pressureObjective = localPressureObjective(objectiveRanks(i,:));
            trialContext = 1;
            if params.AdaptiveDE
                [trialF,trialCR,trialCell] = NAV_SHDE_ADAPTIVE_SAMPLE(memoryF,memoryCR,trialContext,cellProb);
            else
                trialF = params.deF; trialCR = params.deCR; trialCell = 1;
            end
        elseif strcmp(controllerMode,'CONTEXT_H5_FIR')
            pressureObjective = localPressureObjective(objectiveRanks(i,:));
            trialContext = pressureObjective;
            if params.AdaptiveDE
                [trialF,trialCR,trialCell] = NAV_SHDE_ADAPTIVE_SAMPLE(memoryF,memoryCR,trialContext,cellProb);
            else
                trialF = params.deF; trialCR = params.deCR; trialCell = 1;
            end
        else
            error('APDP:ControllerMode','Unsupported ControllerMode: %s',controllerMode);
        end
        if params.FastSearchPath
            bestIndex = bestNeighborhood(i);
            guideVector = popVectors(bestIndex,:);
        else
            bestIndex = localBestInNeighborhood(pop,neighborhood(i,:), ...
                weights(i,:),ideal,nadir,params.NormalizeDecomposition);
            guideVector = [];
        end
        if strcmp(controllerMode,'LEGACY')
            pressureObjective = localPressureObjective(objectiveRanks(i,:));
        end
        if isfield(params,'TriadPBB') && params.TriadPBB
            pressureObjective = TRIAD_PRESSURE(costs(i,:),weights(i,:),ideal,pressureObjective);
        end
        if params.FastSearchPath && isfield(params,'CodexArchiveGuide') && params.CodexArchiveGuide
            [guideVector,codexGuideIndex]=CODEX_ARCHIVE_GUIDE(guideArchiveCosts, ...
                guideArchiveVectors,pop(bestIndex).Cost,guideVector,weights(i,:),ideal,nadir,params.NormalizeDecomposition);
            codexGuideUseTotal=codexGuideUseTotal+(codexGuideIndex>0);
        end
        donorPool = parentPools{i};
        if strcmp(params.MatingScope,'neighborhood')
            donorPool = neighborhoodParentPools{i};
        elseif strcmp(params.MatingScope,'hybrid') && ...
                rand < params.NeighborMatingProbability
            donorPool = neighborhoodParentPools{i};
        elseif strcmp(params.MatingScope,'staged') && ...
                rand < matingNeighborProbability
            % Parameter-free exploration-to-exploitation schedule: the
            % first generation is global, and the last generation is fully
            % neighborhood based.  The schedule is frozen at generation
            % start and does not depend on a tuned threshold or objective
            % scale.
            donorPool = neighborhoodParentPools{i};
        elseif strcmp(params.MatingScope,'pressure') && ...
                rand < 1-max(objectiveRanks(i,:))/max(size(objectiveRanks,1),1)
            % High pressure preserves global exploration. As pressure
            % declines, the target increasingly uses its local MOEA/D
            % neighborhood for fine-grained decomposition search.
            donorPool = neighborhoodParentPools{i};
        end
        if params.FastSearchPath
            if params.FastDonorSampling
                donor = localDECurrentToLocalBestVectorFast( ...
                    popVectors,i,guideVector,lb,ub,trialF,donorPool);
            else
                donor = localDECurrentToLocalBestVector( ...
                    popVectors,i,guideVector,lb,ub,trialF,donorPool);
            end
        else
            guide = pop(bestIndex);
            donor = localDECurrentToLocalBest( ...
                pop,i,guide,lb,ub,trialF,donorPool);
        end

        % PBB is the only operation that changes crossover structure. With
        % the switch off, the same donor reaches ordinary binomial crossover.
        if params.EnableAPB
            if params.FastSearchPath && strcmp(params.PressureMap,'coupled')
                childVector = NAV_PBD_BlockCrossoverFast( ...
                    pop(i).Vector,donor,pressureObjective,trialCR,pressureMasks);
            elseif strcmp(params.PressureMap,'coupled')
                childVector = NAV_PBD_BlockCrossover( ...
                    pop(i).Vector,donor,pressureObjective,trialCR);
            else
                childVector = NAV_APDP_BlockCrossover( ...
                    pop(i).Vector,donor,pressureObjective,trialCR);
            end
        else
            childVector = localBinomialCrossover(pop(i).Vector,donor,trialCR);
        end
        if directPhysicalFE
            feAttempted = feAttempted + 1;
            if feEvaluated >= feLimit
                break;
            end
            feEvaluated = feEvaluated + 1;
            [child,ok] = localEvaluateVectorDirectPhysical( ...
                childVector,nVar,model,varMin,params.FastSearchPath);
        else
            [child,ok] = localEvaluateVector(childVector,nVar,costFunction, ...
                params.FastSearchPath);
        end
        if ~ok, break; end
        generatedCount = generatedCount + 1;
        generated(generatedCount,1) = child;
        sampledF(generatedCount,1) = trialF;
        sampledCR(generatedCount,1) = trialCR;
        sampledCell(generatedCount,1) = trialCell;
        sampledContext(generatedCount,1) = trialContext;
        % A clean parent has one target slot only. Fallback DQR can redirect
        % that replacement to an eligible, still-unoccupied direction; it
        % never creates an additional candidate or evaluation.
        targetIndex = i;
        if params.EnableDQR && localIsFeasible(child.Cost)
            eligible = eligibleDirections{i};
            if strcmp(params.DQRMode,'competitive')
                targetIndex = localCompetitiveDQRTarget(child.Cost,pop,i, ...
                    eligible,directionalQuota,weights,ideal,nadir, ...
                    params.NormalizeDecomposition);
                if isnan(targetIndex), continue; end
            elseif strcmp(params.DQRMode,'hybrid')
                direction = localAssociateDirection(child.Cost,weightsNormalized, ...
                    weights,ideal,nadir,params.FastDirectionAssociation);
                targetIndex = localHybridDQRTarget(child.Cost,pop,i,direction, ...
                    eligible,directionalQuota,weights,ideal,nadir, ...
                    params.NormalizeDecomposition);
                if isnan(targetIndex), continue; end
            elseif strcmp(params.DQRMode,'fallback')
                direction = localAssociateDirection(child.Cost,weightsNormalized, ...
                    weights,ideal,nadir,params.FastDirectionAssociation);
                if isfield(params,'UseCosineDCR') && params.UseCosineDCR
                    [targetIndex,~] = SUPP_DCR_TARGET(child.Cost,pop,i,direction, ...
                        eligible,directionalQuota,weights,ideal,nadir, ...
                        params.NormalizeDecomposition,@localBetter);
                else
                    targetIndex = localFallbackDQRTarget(child.Cost,pop,i,direction, ...
                        eligible,directionalQuota,weights,ideal,nadir, ...
                        params.NormalizeDecomposition);
                end
                if isnan(targetIndex), continue; end
            elseif strcmp(params.DQRMode,'nearest')
                direction = localAssociateDirection(child.Cost,weightsNormalized, ...
                    weights,ideal,nadir,params.FastDirectionAssociation);
                targetIndex = localNearestDQRTarget(child.Cost,pop,i,direction, ...
                    eligible,directionalQuota,weightsNormalized,weights,ideal, ...
                    nadir,params.NormalizeDecomposition);
                if isnan(targetIndex), continue; end
            else
                direction = localAssociateDirection(child.Cost,weightsNormalized, ...
                    weights,ideal,nadir,params.FastDirectionAssociation);
                if ismember(direction,eligible) && directionalQuota(direction)==0
                    targetIndex = direction;
                elseif directionalQuota(i)~=0
                    continue;
                end
            end
        end
        if params.EnableDQR && directionalQuota(targetIndex)~=0
            continue;
        end

        % Constraint dominance is applied before the standard raw
        % Tchebycheff subproblem comparison.
        oldTargetCost = pop(targetIndex).Cost;
        if localBetter(child.Cost,pop(targetIndex).Cost,weights(targetIndex,:), ...
                ideal,nadir,params.NormalizeDecomposition)
            if params.AdaptiveDE
                oldScore = localScalar(oldTargetCost,weights(targetIndex,:), ...
                    ideal,nadir,params.NormalizeDecomposition);
                newScore = localScalar(child.Cost,weights(targetIndex,:), ...
                    ideal,nadir,params.NormalizeDecomposition);
                delta = oldScore-newScore;
                if strcmp(controllerMode,'LEGACY')
                    if ~isfinite(delta) || delta<=0, delta=1; end
                    successCount = successCount + 1;
                    successF(successCount,1) = trialF;
                    successCR(successCount,1) = trialCR;
                    successWeight(successCount,1) = delta;
                else
                    if localIsFeasible(oldTargetCost) && localIsFeasible(child.Cost) && ...
                            isfinite(oldScore) && isfinite(newScore) && ...
                            isfinite(delta) && delta>0
                        learningEligible = true;
                        if strcmp(controllerMode,'GLOBAL_H5_FIR_CR_ARITH_ND')
                            [learningEligible,wasDominated,wasDuplicate] = ...
                                NAV_SHDE_PARETO_LEARNING_GATE(child.Cost,generationParetoQ,1e-12);
                            if wasDuplicate
                                ndGateDuplicateRejectCount = ndGateDuplicateRejectCount + 1;
                            elseif wasDominated
                                ndGateDominatedRejectCount = ndGateDominatedRejectCount + 1;
                            else
                                ndGatePassedCount = ndGatePassedCount + 1;
                            end
                        end
                        if learningEligible
                            successCount = successCount + 1;
                            successF(successCount,1) = trialF;
                            successCR(successCount,1) = trialCR;
                            successCell(successCount,1) = trialCell;
                            rawW = delta ./ max(abs(oldScore),1e-12);
                            if isfield(params, 'UseKFWeight') && params.UseKFWeight
                                kfBonus = exp(-max(0, child.Cost(4) - 0.025) / 0.02);
                                rawW = rawW * (0.5 + kfBonus);
                            end
                            successWeight(successCount,1) = rawW;
                            successContext(successCount,1) = trialContext;
                        else
                            excludedCreditCount = excludedCreditCount + 1;
                        end
                    else
                        excludedCreditCount = excludedCreditCount + 1;
                    end
                end
            end
            child.Weight = weights(targetIndex,:);
            pop(targetIndex) = child;
            if params.FastSearchPath
                popVectors(targetIndex,:) = child.Vector;
            end
            accepted = accepted + 1;
            if params.EnableDQR
                directionalQuota(targetIndex) = directionalQuota(targetIndex) + 1;
            end
        end
    end

    if strcmp(controllerMode,'LEGACY')
        if params.AdaptiveDE
            [adaptiveF,adaptiveCR] = localUpdateAdaptiveDE( ...
                adaptiveF,adaptiveCR,successF(1:successCount), ...
                successCR(1:successCount),successWeight(1:successCount));
        end
    else
        if useMultiMemoryCR
            for contextIndex = 1:controllerContexts
                useSuccess = successContext(1:successCount)==contextIndex;
                if any(useSuccess)
                    wCtx = successWeight(useSuccess);
                    cellsCtx = successCell(useSuccess);
                    FCtx = successF(useSuccess);
                    CRCtx = successCR(useSuccess);
                    cellPayoff = zeros(1, controllerH);
                    for k = 1:controllerH
                        cMatch = (cellsCtx == k);
                        if any(cMatch)
                            cellPayoff(k) = sum(wCtx(cMatch));
                            wCell = wCtx(cMatch); wCell = wCell / sum(wCell);
                            fCell = FCtx(cMatch); crCell = CRCtx(cMatch);
                            denF = sum(wCell .* fCell);
                            if denF > 0
                                memoryF(contextIndex, k) = min(1, max(0.1, sum(wCell .* fCell.^2) / denF));
                            end
                            memoryCR(contextIndex, k) = min(1, max(0, sum(wCell .* crCell)));
                        end
                    end
                    totPay = sum(cellPayoff);
                    if totPay > 0
                        pMin = 0.05;
                        if isfield(params, 'ControllerPMin') && ~isempty(params.ControllerPMin)
                            pMin = params.ControllerPMin;
                        end
                        rawP = cellPayoff / totPay;
                        cellProb(contextIndex, :) = (1 - alpha_p) * cellProb(contextIndex, :) + alpha_p * rawP;
                        cellProb(contextIndex, :) = max(pMin, cellProb(contextIndex, :));
                        cellProb(contextIndex, :) = cellProb(contextIndex, :) / sum(cellProb(contextIndex, :));
                    end
                end
            end
        else
            for contextIndex = 1:controllerContexts
                useSuccess = successContext(1:successCount)==contextIndex;
                if any(useSuccess)
                    [memoryF(contextIndex,:),memoryCR(contextIndex,:),memoryPointer(contextIndex)] = ...
                        NAV_SHDE_ADAPTIVE_UPDATE(memoryF(contextIndex,:),memoryCR(contextIndex,:), ...
                        memoryPointer(contextIndex),successF(useSuccess), ...
                        successCR(useSuccess),successWeight(useSuccess), ...
                        localCRUpdateMode(controllerMode));
                end
            end
        end
    end

    if generatedCount < numel(generated)
        generated = generated(1:generatedCount);
    end

    if directPhysicalFE
        setappdata(0,'NAV_FE_ATTEMPTED',feAttempted);
        setappdata(0,'NAV_FE_EVALUATED',feEvaluated);
    end

    % A trial remains eligible for the next archive refresh even when it did
    % not replace its MOEA/D parent. This is external-archive bookkeeping:
    % it changes neither the child formula nor the FE budget.
    pending=[pending;generated]; %#ok<AGROW>
    if mod(it,params.archiveStride)==0 || localRemainingFE()<=0
        [rep,archiveAudit]=localUpdateArchive(rep,[pop;pending],params);
        pending=repmat(localEmptyParticle(),0,1);
    end
    if isempty(rep)
        [rep,archiveAudit] = localUpdateArchive( ...
            repmat(localEmptyParticle(),0,1),pop,params);
    end
    best = NAV_SelectCompromiseSolution(rep,params.reportWeights);
    history.BestCost(it,:) = best.Cost(:)';
    history.RepSize(it) = numel(rep);
    history.Time(it) = toc(tStart);
    history.GeneratedCount(it) = generatedCount;
    history.AcceptedCount(it) = accepted;
    history.DirectionalReplacementCount(it,:) = directionalQuota(:)';
    history.AdaptiveF(it) = adaptiveF;
    history.AdaptiveCR(it) = adaptiveCR;
    history.AdaptiveSuccessCount(it) = successCount;
    history.MatingNeighborhoodProbability(it) = matingNeighborProbability;
    history.ControllerMode{it} = controllerMode;
    history.SampledFMean(it) = localFiniteMean(sampledF(1:generatedCount));
    history.SampledFSD(it) = localFiniteSD(sampledF(1:generatedCount));
    history.SampledCRMean(it) = localFiniteMean(sampledCR(1:generatedCount));
    history.SampledCRSD(it) = localFiniteSD(sampledCR(1:generatedCount));
    history.SampledF{it} = sampledF(1:generatedCount);
    history.SampledCR{it} = sampledCR(1:generatedCount);
    history.EligibleSuccessCount(it) = successCount;
    contextCounts=zeros(1,4);
    if successCount > 0
        contextCounts(1:controllerContexts)=accumarray(max(successContext(1:successCount),1), ...
            ones(successCount,1),[controllerContexts 1])';
    end
    history.ContextSuccessCount(it,:) = contextCounts;
    history.ActualSuccessCount(it) = successCount;
    history.SampledContext{it} = sampledContext(1:generatedCount);
    history.ExcludedCreditCount(it) = excludedCreditCount;
    history.NDCreditEligibleCount(it) = ndGatePassedCount;
    history.NDDominatedRejectCount(it) = ndGateDominatedRejectCount;
    history.NDDuplicateRejectCount(it) = ndGateDuplicateRejectCount;
    history.NoLearningUpdate(it) = (successCount==0);
    history.MemoryF{it} = memoryF;
    history.MemoryCR{it} = memoryCR;
    history.MemoryPointer{it} = memoryPointer;
    history = NAV_RecordConvergenceHistory(history,it,rep);
end
if ~isempty(pending)
    [rep,archiveAudit]=localUpdateArchive(rep,[pop;pending],params);
end
if isempty(rep)
    error('APDP:FinalArchive','The candidate returned an empty archive.');
end
best = NAV_SelectCompromiseSolution(rep,params.reportWeights);
history.RuntimeSec = toc(tStart);
history.CodexGuideUseTotal=codexGuideUseTotal;
history.Algorithm = 'ABDR-MOEA/D-DE';
history.CandidateVersion = 'ABDR-MOEA/D-DE';
history.EnableAPB = logical(params.EnableAPB);
history.EnableDQR = logical(params.EnableDQR);
history.AdaptiveDE = logical(params.AdaptiveDE);
history.ControllerMode = controllerMode;
history.ControllerH = controllerH;
history.ControllerContexts = controllerContexts;
if ismember(controllerMode,{'GLOBAL_H5_FIR_CR_ARITH','GLOBAL_H5_FIR_CR_ARITH_ND'})
    history.CRUpdateRule = 'WEIGHTED_ARITHMETIC';
elseif strcmp(controllerMode,'LEGACY')
    history.CRUpdateRule = 'LEGACY_WEIGHTED_ARITHMETIC_SMOOTHED';
else
    history.CRUpdateRule = 'WEIGHTED_LEHMER';
end
history.NDCreditGateActive = strcmp(controllerMode,'GLOBAL_H5_FIR_CR_ARITH_ND');
history.PressureMap = params.PressureMap;
history.NormalizeDecomposition = logical(params.NormalizeDecomposition);
history.DE = struct('F',params.deF,'CR',params.deCR, ...
    'AdaptiveDE',logical(params.AdaptiveDE), ...
    'SingleOffspringPerParent',true,'TotalCostSearchAcceptance',false);
history.NeighborhoodSize = params.neighborSize;
history.MatingScope = params.MatingScope;
history.NeighborMatingProbability = params.NeighborMatingProbability;
history.ArchiveStride = params.archiveStride;
history.DQRMode = params.DQRMode;
history.Weights = weights;
history.FastSearchPath = logical(params.FastSearchPath);
history.WeightCache = logical(params.UseWeightCache);
history.VectorReuse = logical(params.FastSearchPath);
history.FastDirectionAssociation = logical(params.FastDirectionAssociation);
history.SpeedOptimization = ternary(params.FastSearchPath, ...
    'fast PBD + cached pressure masks + generation vector reuse + preallocated buffers', ...
    'none');
history.SpeedOptimizationPreservesSearch = logical(params.FastSearchPath);
history.ArchiveDiversityMode = params.ArchiveDiversityMode;
history.ArchiveGridDivisions = params.ArchiveGridDivisions;
history.FinalArchiveAudit = archiveAudit;
end

function mode = localCRUpdateMode(controllerMode)
if ismember(controllerMode,{'GLOBAL_H5_FIR_CR_ARITH','GLOBAL_H5_FIR_CR_ARITH_ND'})
    mode='ARITH';
else
    mode='LEHMER';
end
end
function params = localDefaults(params)
if ~isfield(params,'nPop') || isempty(params.nPop), params.nPop = 24; end
if ~isfield(params,'nRep') || isempty(params.nRep), params.nRep = 36; end
if ~isfield(params,'MaxIt') || isempty(params.MaxIt), params.MaxIt = 83; end
if ~isfield(params,'EnableAPB') || isempty(params.EnableAPB), params.EnableAPB = true; end
if ~isfield(params,'EnableDQR') || isempty(params.EnableDQR), params.EnableDQR = false; end
if ~isfield(params,'DQRMode') || isempty(params.DQRMode), params.DQRMode = 'associate'; end
if ~isfield(params,'FastSearchPath') || isempty(params.FastSearchPath)
    params.FastSearchPath = false;
end
if ~isfield(params,'DirectPhysicalFE') || isempty(params.DirectPhysicalFE)
    params.DirectPhysicalFE = false;
end
if ~isfield(params,'FastDonorSampling') || isempty(params.FastDonorSampling)
    params.FastDonorSampling = false;
end
if ~isfield(params,'UseWeightCache') || isempty(params.UseWeightCache)
    params.UseWeightCache = true;
end
if ~isfield(params,'FastDirectionAssociation') || isempty(params.FastDirectionAssociation)
    params.FastDirectionAssociation = params.FastSearchPath;
end
if ~isfield(params,'PressureMap') || isempty(params.PressureMap), params.PressureMap = 'legacy'; end
if ~isfield(params,'NormalizeDecomposition') || isempty(params.NormalizeDecomposition)
    params.NormalizeDecomposition = false;
end
if ~isfield(params,'AdaptiveDE') || isempty(params.AdaptiveDE)
    params.AdaptiveDE = true;
end
if ~isfield(params,'ControllerMode') || isempty(params.ControllerMode), params.ControllerMode='GLOBAL_H5_FIR_CR_ARITH'; end
if ~isfield(params,'EnableAPB') || isempty(params.EnableAPB)
    params.EnableAPB = true;
end
if ~isfield(params,'EnableDQR') || isempty(params.EnableDQR)
    params.EnableDQR = true;
end
if ~isfield(params,'MultiMemoryCR') || isempty(params.MultiMemoryCR)
    params.MultiMemoryCR = true;
end
if ~isfield(params,'deF') || isempty(params.deF), params.deF = 0.50; end
if ~isfield(params,'deCR') || isempty(params.deCR), params.deCR = 0.50; end
if isfield(params, 'T') && ~isempty(params.T) && (~isfield(params, 'neighborSize') || isempty(params.neighborSize))
    params.neighborSize = params.T;
end
if ~isfield(params,'neighborSize') || isempty(params.neighborSize)
    params.neighborSize = 6; % Default topological neighborhood size T=6
end
if ~isfield(params,'archiveStride') || isempty(params.archiveStride)
    params.archiveStride=4;
end
if ~isfield(params,'ArchiveDiversityMode') || isempty(params.ArchiveDiversityMode)
    params.ArchiveDiversityMode='crowding';
end
if ~isfield(params,'ArchiveGridDivisions') || isempty(params.ArchiveGridDivisions)
    params.ArchiveGridDivisions=7;
end
if ~isfield(params,'MatingScope') || isempty(params.MatingScope)
    params.MatingScope='global';
end
if ~isfield(params,'NeighborMatingProbability') || isempty(params.NeighborMatingProbability)
    params.NeighborMatingProbability=0.90;
end
params.EnableAPB = logical(params.EnableAPB);
params.EnableDQR = logical(params.EnableDQR);
params.NormalizeDecomposition = logical(params.NormalizeDecomposition);
params.AdaptiveDE = logical(params.AdaptiveDE);
params.ControllerMode = upper(char(string(params.ControllerMode)));
params.ControllerH = 5;
params.ControllerContexts = 1 + 3*strcmp(params.ControllerMode,'CONTEXT_H5_FIR');
assert(ismember(params.ControllerMode,{'LEGACY','GLOBAL_H5_FIR','CONTEXT_H5_FIR', ...
    'GLOBAL_H5_FIR_CR_ARITH','GLOBAL_H5_FIR_CR_ARITH_ND'}), ...
    'APDP:ControllerMode','Unsupported ControllerMode');
params.FastSearchPath = logical(params.FastSearchPath);
params.DirectPhysicalFE = logical(params.DirectPhysicalFE);
params.FastDonorSampling = logical(params.FastDonorSampling);
params.UseWeightCache = logical(params.UseWeightCache);
params.FastDirectionAssociation = logical(params.FastDirectionAssociation);
params.PressureMap = lower(char(string(params.PressureMap)));
params.MatingScope = lower(char(string(params.MatingScope)));
params.DQRMode = lower(char(string(params.DQRMode)));
params.ArchiveDiversityMode = lower(char(string(params.ArchiveDiversityMode)));
assert(ismember(params.PressureMap,{'legacy','coupled'}), ...
    'APDP:PressureMap','PressureMap must be legacy or coupled.');
assert(ismember(params.MatingScope,{'global','neighborhood','hybrid','staged','pressure'}), ...
    'APDP:MatingScope','MatingScope must be global, neighborhood, hybrid, or staged.');
assert(ismember(params.DQRMode,{'associate','competitive','hybrid','fallback','nearest'}), ...
    'APDP:DQRMode','DQRMode must be associate, competitive, hybrid, fallback, or nearest.');
assert(ismember(params.ArchiveDiversityMode,{'crowding','grid-crowding'}), ...
    'APDP:ArchiveDiversityMode', ...
    'ArchiveDiversityMode must be crowding or grid-crowding.');
validateattributes(params.NeighborMatingProbability,{'numeric'}, ...
    {'scalar','real','finite','>=',0,'<=',1});
params.neighborSize = min(params.nPop,max(2,round(params.neighborSize)));
params.archiveStride=max(1,round(params.archiveStride));
params.ArchiveGridDivisions=max(2,round(params.ArchiveGridDivisions));
validateattributes(params.nPop,{'numeric'},{'scalar','integer','>=',4});
validateattributes(params.nRep,{'numeric'},{'scalar','integer','>=',1});
validateattributes(params.deF,{'numeric'},{'scalar','real','finite','positive','<=',2});
validateattributes(params.deCR,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
params.reportWeights = localGet(params,'reportWeights',[0.40 0.25 0.10 0.25]);
end

function p = localMatingProbability(params,it)
%LOCALMATINGPROBABILITY Return the neighborhood-parent probability.
%   `staged` is intentionally parameter-free: it linearly increases from
%   zero at the first generation to one at the last generation.  The other
%   scopes retain their fixed semantics for ablation and regression tests.
switch params.MatingScope
    case 'global'
        p = 0;
    case 'neighborhood'
        p = 1;
    case 'hybrid'
        p = params.NeighborMatingProbability;
    case 'staged'
        denom = max(double(params.MaxIt)-1,1);
        p = (double(it)-1)./denom;
        p = min(1,max(0,p));
    case 'pressure'
        % The probability is target-specific and is filled in by the main
        % loop from the current objective ranks.
        p = NaN;
    otherwise
        error('APDP:MatingScope','Unsupported mating scope: %s',params.MatingScope);
end
end

function [model,varSize,varMin,varMax,costFunction,nObj] = localProblem()
model = CreateModel();
varSize = [1 model.n];
[varMin,varMax] = NAV_NavigationBounds(model);
costFunction = @(x) MyCost(x,model,varMin);
nObj = 4;
end

function p = localEmptyParticle()
p = NAV_CopyEmptyParticle();
p.Position = []; p.Vector = []; p.Cost = [];
end

function p = localParticle(pos,cost)
p = localEmptyParticle();
p.Position = pos;
p.Vector = NAV_EncodePosition(pos);
p.Cost = double(cost(:));
end

function [particle,ok] = localEvaluateVector(vector,nVar,costFunction,reuseVector)
particle = localEmptyParticle();
ok = false;
if nargin < 4, reuseVector = false; end
try
    pos = NAV_DecodeVector(vector,nVar);
    [cost,ok] = NAV_FE_Evaluate(costFunction,pos);
    if ok && all(isfinite(cost))
        if reuseVector
            % The decoded vector is already the exact representation used
            % by DE/PBD. Avoid a second struct-to-vector encoding after the
            % FE call; this changes no objective, FE, or RNG semantics.
            particle = localEmptyParticle();
            particle.Position = pos;
            particle.Vector = double(vector(:)');
            particle.Cost = double(cost(:));
        else
            particle = localParticle(pos,cost);
        end
    else
        ok = false;
    end
catch
    ok = false;
end
end

function [particle,ok] = localEvaluateVectorDirectPhysical(vector,nVar,model,varMin,reuseVector)
%LOCALEVALUATEVECTORDIRECTPHYSICAL Exact physical_v2 child evaluation.
%   The caller increments the FE counters before entering this helper, so
%   no second budget guard is needed on the hot path.
particle = localEmptyParticle();
ok = false;
try
    pos = NAV_DecodeVector(vector,nVar);
    opts = localSearchOptionsFromAppData();
    cost = NAV_MyCost_PhysicalV2(pos,model,varMin,opts);
    if all(isfinite(cost))
        if reuseVector
            particle.Position = pos;
            particle.Vector = double(vector(:)');
            particle.Cost = double(cost(:));
        else
            particle = localParticle(pos,cost);
        end
        ok = true;
    end
catch
    ok = false;
end
end

function opts = localSearchOptionsFromAppData()
opts = struct();
try
    if isappdata(0,'NAV_SEARCH_FAST_VALIDATION') && ...
            logical(getappdata(0,'NAV_SEARCH_FAST_VALIDATION'))
        opts.FastTerrainValidation = true;
        opts.FastTerrainStepM = 5;
    end
    if isappdata(0,'NAV_FAST_THREAT_EVALUATION') && ...
            logical(getappdata(0,'NAV_FAST_THREAT_EVALUATION'))
        opts.FastThreatEvaluation = true;
    end
catch
end
end

function donor = localDECurrentToLocalBest(pop,i,guide,lb,ub,F,pool)
ids = pool(randperm(numel(pool),2));
xi = pop(i).Vector;
donor = xi + F.*(guide.Vector-xi) + ...
    F.*(pop(ids(1)).Vector-pop(ids(2)).Vector);
donor = min(ub,max(lb,donor));
end

function donor = localDECurrentToLocalBestVector(vectors,i,guideVector,lb,ub,F,pool)
% Vector-cache equivalent of localDECurrentToLocalBest for the fast path.
ids = pool(randperm(numel(pool),2));
xi = vectors(i,:);
donor = xi + F.*(guideVector-xi) + ...
    F.*(vectors(ids(1),:)-vectors(ids(2),:));
donor = min(ub,max(lb,donor));
end

function donor = localDECurrentToLocalBestVectorFast(vectors,i,guideVector,lb,ub,F,pool)
%LOCALDE...FAST Uniform two-parent draw without randperm allocation.
n = numel(pool);
if n < 2
    donor = localDECurrentToLocalBestVector(vectors,i,guideVector,lb,ub,F,pool);
    return;
end
a = randi(n);
b = randi(n-1);
if b >= a, b = b + 1; end
xi = vectors(i,:);
donor = xi + F.*(guideVector-xi) + ...
    F.*(vectors(pool(a),:)-vectors(pool(b),:));
donor = min(ub,max(lb,donor));
end

function vectors = localVectorMatrix(pop)
if isempty(pop)
    vectors=zeros(0,0);
    return;
end
nVector=numel(pop(1).Vector);
vectors=reshape([pop.Vector],nVector,[])';
end

function masks = localPressureMasks(nVar)
% Precompute deterministic coupled physical blocks once per run.
n=3*nVar;
masks=false(4,n);
masks(1,1:nVar)=true;
masks(2,1:2*nVar)=true;
masks(3,[1:nVar,2*nVar+1:3*nVar])=true;
masks(4,nVar+1:3*nVar)=true;
end

function pools = localParentPools(nPop,neighborhood,scope)
pools = cell(nPop,1);
allIndices = 1:nPop;
for i = 1:nPop
    if strcmp(scope,'neighborhood')
        p = unique(double(neighborhood(i,:)),'stable');
        p = p(p~=i & p>=1 & p<=nPop);
        % The current-to-local-best/1 donor needs two distinct difference
        % parents.  Keep a deterministic global fallback for tiny/degenerate
        % neighborhoods, although the formal nPop/neighbor settings never
        % trigger it.
        if numel(p)>=2
            pools{i}=p;
        else
            pools{i}=allIndices(allIndices~=i);
        end
    else
        pools{i} = allIndices(allIndices~=i);
    end
end
end

function eligible = localEligibleDirections(neighborhood)
eligible = cell(size(neighborhood,1),1);
for i = 1:size(neighborhood,1)
    eligible{i} = unique([i,neighborhood(i,:)]);
end
end

function remaining = localRemainingFE()
remaining = inf;
if ~isappdata(0,'NAV_FE_LIMIT')
    return;
end
limit = double(getappdata(0,'NAV_FE_LIMIT'));
evaluated = 0;
if isappdata(0,'NAV_FE_EVALUATED')
    evaluated = double(getappdata(0,'NAV_FE_EVALUATED'));
end
remaining = max(0,limit-evaluated);
end

function value = localAppDataNumber(name,defaultValue)
value = defaultValue;
try
    if isappdata(0,name)
        candidate = double(getappdata(0,name));
        if isscalar(candidate) && isfinite(candidate)
            value = candidate;
        end
    end
catch
end
end

function child = localBinomialCrossover(parent,donor,CR)
mask = rand(1,numel(parent)) < CR;
mask(randi(numel(parent))) = true;
child = parent;
child(mask) = donor(mask);
end

function m=localFiniteMean(x)
x=x(isfinite(x)); if isempty(x), m=nan; else, m=mean(x); end
end
function s=localFiniteSD(x)
x=x(isfinite(x)); if numel(x)<2, s=0; else, s=std(x,0); end
end

function [F,CR] = localSampleAdaptiveDE(memoryF,memoryCR)
%LOCAL_SAMPLEADAPTIVEDE Bounded success-history DE trial parameters.
%   The Gaussian perturbation scale follows the conventional 0.1
%   success-history DE setting.  Bounds prevent invalid DE controls and are
%   fixed by the operator definition, not tuned per scenario.
F = min(1,max(0.1,memoryF + 0.1*randn));
CR = min(1,max(0,memoryCR + 0.1*randn));
end

function [memoryF,memoryCR] = localUpdateAdaptiveDE(memoryF,memoryCR,F,CR,w)
%LOCAL_UPDATEADAPTIVEDE Update one shared memory cell per generation.
if isempty(F) || isempty(CR) || isempty(w), return; end
w = double(w(:)); F = double(F(:)); CR = double(CR(:));
valid = isfinite(w) & w>0 & isfinite(F) & isfinite(CR);
if ~any(valid), return; end
w = w(valid); F = F(valid); CR = CR(valid);
w = w./sum(w);
denom = sum(w.*F);
if denom > 0
    memoryF = min(1,max(0.1,sum(w.*F.^2)/denom));
end
memoryCR = min(1,max(0,sum(w.*CR)));
end

function ranks = localObjectiveRanks(costs)
n = size(costs,1);
ranks = zeros(n,size(costs,2));
for j = 1:size(costs,2)
    for i = 1:n
        % Equal values get equal rank, so only the objective-index rule,
        % rather than incidental particle order, resolves a pressure tie.
        ranks(i,j) = 1 + sum(costs(:,j) < costs(i,j));
    end
end
end

function objective = localPressureObjective(ranks)
[~,objective] = max(double(ranks(:)')); % First maximum resolves ties.
end

function index = localBestInNeighborhood(pop,neighbors,weight,ideal,nadir,normalize)
scores = inf(1,numel(neighbors));
for k = 1:numel(neighbors)
    scores(k) = localScalar(pop(neighbors(k)).Cost,weight,ideal,nadir,normalize);
end
[~,relative] = min(scores);
index = neighbors(relative);
end

function ok = localBetter(newCost,oldCost,weight,ideal,nadir,normalize)
newViolation = localViolation(newCost);
oldViolation = localViolation(oldCost);
tol = 1e-12;
if newViolation < oldViolation-tol
    ok = true;
    return;
elseif newViolation > oldViolation+tol
    ok = false;
    return;
elseif newViolation > tol
    ok = false;
    return;
end
ok = localScalar(newCost,weight,ideal,nadir,normalize) < ...
    localScalar(oldCost,weight,ideal,nadir,normalize)-tol;
end

function value = localScalar(cost,weight,ideal,nadir,normalize)
if localViolation(cost)>1e-12
    value = inf;
    return;
end
delta = max(0,double(cost(:)')-double(ideal(:)'));
if normalize
    delta = delta ./ max(double(nadir(:)')-double(ideal(:)'),1e-12);
end
value = max(max(double(weight(:)'),1e-12).*delta);
end

function value = localViolation(cost)
c = double(cost(:));
if numel(c)<4 || any(~isfinite(c(1:4)))
    value = inf;
else
    value = max(0,max(c(1:4))-1);
end
end

function tf = localIsFeasible(cost)
tf = localViolation(cost)<=1e-12;
end

function index = localAssociateDirection(cost,weightsNormalized,weights,ideal,nadir,fastAssociation)
% Associate a feasible child with the nearest normalized reference weight.
% The frozen generation ideal/nadir make this deterministic and parameter-free.
if nargin < 6, fastAssociation = false; end
if isempty(weightsNormalized)
    % WeightCache ablations deliberately rebuild the same normalization at
    % each association. This changes no search rule, only the work avoided.
    weightsNormalized = double(weights) ./ max(vecnorm(double(weights),2,2),1e-12);
end
f = max(0,double(cost(:)')-double(ideal(:)'));
f = f./max(double(nadir(:)')-double(ideal(:)'),1e-12);
f = f./max(norm(f),1e-12);
if fastAssociation
    % Every cached reference row is unit norm.  For unit-norm f, nearest
    % Euclidean direction is the same argmax dot product, avoiding a
    % temporary nPop-by-nObj distance matrix on every DQR child.
    [~,index] = max(weightsNormalized*f(:));
else
    [~,index] = min(sum((weightsNormalized-f).^2,2));
end
end

function ranks = localObjectiveRanksFast(costs)
% Vectorized equivalent of localObjectiveRanks with identical tie ranks.
ranks = zeros(size(costs));
for j = 1:size(costs,2)
    v = double(costs(:,j));
    ranks(:,j) = 1 + sum(bsxfun(@lt,v,v.'),1).';
end
end

function best = localBestNeighborhoodIndices(costs,neighborhood,weights, ...
    ideal,nadir,normalize)
% Reuse one generation's population scores for every target subproblem.
delta = max(0,double(costs)-double(ideal));
if normalize
    delta = delta ./ max(double(nadir)-double(ideal),1e-12);
end
invalid = any(~isfinite(costs),2) | ...
    max(double(costs(:,1:min(4,size(costs,2)))),[],2)>1+1e-12;
best = zeros(size(neighborhood,1),1);
for i = 1:size(neighborhood,1)
    score = max(delta .* max(double(weights(i,:)),1e-12),[],2);
    score(invalid) = inf;
    [~,relative] = min(score(neighborhood(i,:)));
    best(i) = neighborhood(i,relative);
end
end

function out = ternary(condition,yesValue,noValue)
if condition, out = yesValue; else, out = noValue; end
end

function targetIndex = localCompetitiveDQRTarget(childCost,pop,parentIndex, ...
    eligible,quota,weights,ideal,nadir,normalize)
% Select the unoccupied eligible direction with the largest scalar gain.
% A fallback to the source direction preserves ordinary MOEA/D progress.
targetIndex = NaN;
available = eligible(quota(eligible)==0);
bestGain = -inf;
for k = 1:numel(available)
    candidate = available(k);
    if ~localBetter(childCost,pop(candidate).Cost,weights(candidate,:), ...
            ideal,nadir,normalize)
        continue;
    end
    oldScore = localScalar(pop(candidate).Cost,weights(candidate,:), ...
        ideal,nadir,normalize);
    newScore = localScalar(childCost,weights(candidate,:),ideal,nadir,normalize);
    gain = oldScore-newScore;
    if isfinite(gain) && gain>bestGain
        bestGain = gain;
        targetIndex = candidate;
    end
end
if isnan(targetIndex) && quota(parentIndex)==0 && ...
        localBetter(childCost,pop(parentIndex).Cost,weights(parentIndex,:), ...
        ideal,nadir,normalize)
    targetIndex = parentIndex;
end
end

function targetIndex = localHybridDQRTarget(childCost,pop,parentIndex,direction, ...
    eligible,quota,weights,ideal,nadir,normalize)
% Preserve geometric association; compete only after its quota is occupied.
targetIndex = NaN;
if ismember(direction,eligible) && quota(direction)==0
    if localBetter(childCost,pop(direction).Cost,weights(direction,:), ...
            ideal,nadir,normalize)
        targetIndex = direction;
    elseif quota(parentIndex)==0 && localBetter(childCost,pop(parentIndex).Cost, ...
            weights(parentIndex,:),ideal,nadir,normalize)
        targetIndex = parentIndex;
    end
    return;
end
targetIndex = localCompetitiveDQRTarget(childCost,pop,parentIndex,eligible, ...
    quota,weights,ideal,nadir,normalize);
end

function targetIndex = localFallbackDQRTarget(childCost,pop,parentIndex,direction, ...
    eligible,quota,weights,ideal,nadir,normalize)
% Use geometric association first; if unavailable, use the first quota-free eligible direction in deterministic neighborhood order.
targetIndex = NaN;
if ismember(direction,eligible) && quota(direction)==0
    candidate = direction;
else
    available = eligible(quota(eligible)==0);
    if isempty(available)
        candidate = NaN;
    else
        candidate = available(1);
    end
end
if ~isnan(candidate) && localBetter(childCost,pop(candidate).Cost, ...
        weights(candidate,:),ideal,nadir,normalize)
    targetIndex = candidate;
elseif quota(parentIndex)==0 && localBetter(childCost,pop(parentIndex).Cost, ...
        weights(parentIndex,:),ideal,nadir,normalize)
    targetIndex = parentIndex;
end
end

function targetIndex = localNearestDQRTarget(childCost,pop,parentIndex,direction, ...
    eligible,quota,weightsNormalized,weights,ideal,nadir,normalize)
%LOCALNEARESTDQRTARGET Nearest-unoccupied reference-direction repair.
%   The original fallback uses the first available neighborhood direction,
%   which depends on neighborhood row order. This repair ranks all
%   unoccupied eligible directions by angular distance to the child and
%   tries them in that order. It still accepts at most one target and falls
%   back to the source direction under the same scalar MOEA/D rule.
targetIndex = NaN;
available = eligible(quota(eligible)==0);
if isempty(available), return; end

if isempty(weightsNormalized)
    weightsNormalized = double(weights) ./ ...
        max(vecnorm(double(weights),2,2),1e-12);
end
f = max(0,double(childCost(:)')-double(ideal(:)'));
f = f ./ max(double(nadir(:)')-double(ideal(:)'),1e-12);
f = f ./ max(norm(f),1e-12);
distance = 1 - weightsNormalized(available,:)*f(:);
% Stable deterministic tie-breaking by direction index.
[~,order] = sortrows([distance(:),double(available(:))],[1 2]);
available = available(order);

% Prefer the associated direction when it is among the unoccupied options,
% while retaining the geometric ordering for every other fallback.
if ismember(direction,available)
    available = [direction,available(available~=direction)];
end
for k=1:numel(available)
    candidate = available(k);
    if localBetter(childCost,pop(candidate).Cost,weights(candidate,:), ...
            ideal,nadir,normalize)
        targetIndex = candidate;
        return;
    end
end
if quota(parentIndex)==0 && localBetter(childCost,pop(parentIndex).Cost, ...
        weights(parentIndex,:),ideal,nadir,normalize)
    targetIndex = parentIndex;
end
end

function [archive,audit] = localUpdateArchive(oldArchive,candidates,params)
% Preserve constrained Pareto/archive semantics outside PBB, SHDE and DQR.
% An archive-policy comparison can therefore not silently become a search
% mechanism ablation or change the one-child-per-parent FE protocol.
pool=[oldArchive(:);candidates(:)];
pool=localUniqueFinite(pool);
audit=localEmptyArchiveAudit();
if isempty(pool)
    archive=pool;
    return;
end
costs=localCostMatrix(pool);
feasible=arrayfun(@(i) localViolation(costs(i,:))<=1e-12,1:size(costs,1))';
if any(feasible)
    pool=pool(feasible);
    costs=costs(feasible,:);
end
keep=localParetoMask(costs);
preTrim=pool(keep);
for i=1:numel(preTrim),preTrim(i).IsDominated=false;end
if numel(preTrim)<=params.nRep
    archive=preTrim;
    return;
end
if strcmp(params.ArchiveDiversityMode,'grid-crowding')
    archive=localGridCrowdingTrim(preTrim,params.nRep,params.ArchiveGridDivisions);
else
    archive=localCrowdingTrim(preTrim,params.nRep);
end
audit.PreTrimEligibleCount=NaN;
audit.StandardEligibleCount=NaN;
end

function keep=localParetoMask(costs)
n=size(costs,1);
keep=true(n,1);
tol=1e-12;
for i=1:n
    dominates=all(costs<=costs(i,:)+tol,2) & any(costs<costs(i,:)-tol,2);
    dominates(i)=false;
    if any(dominates),keep(i)=false;end
end
end

function archive=localCrowdingTrim(pool,nKeep)
if numel(pool)<=nKeep
    archive=pool;
    return;
end
costs=localCostMatrix(pool);
[distance,~] = localCrowdingDistance(costs);
n=size(costs,1);
[~,order]=sortrows([-distance,(1:n)'],[1 2]);
archive=pool(order(1:nKeep));
end

function archive=localGridCrowdingTrim(pool,nKeep,nGrid)
% Keep one representative per occupied normalized grid cell, explicitly protect
% extreme solutions of all 4 objectives and the normalized compromise solution,
% then fill/trim by normalized crowding distance.
if numel(pool)<=nKeep, archive=pool; return; end
costs=localCostMatrix(pool);
C=double(costs(:,1:min(4,size(costs,2))));
n=size(C,1); m=size(C,2);
lo=min(C,[],1); hi=max(C,[],1); span=max(hi-lo, [1e-4, 1e-4, 1e-4, 1e-4]);
normC=(C-lo)./span;
pad=(hi-lo)./max(2*(nGrid-1),1);
coords=zeros(n,m);
for j=1:m
    if hi(j)-lo(j)<=1e-14
        coords(:,j)=0;
    else
        coords(:,j)=round(nGrid*(C(:,j)-(lo(j)-pad(j))) ./ ...
            ((hi(j)-lo(j))+2*pad(j)));
        coords(:,j)=min(nGrid,max(0,coords(:,j)));
    end
end
[~,~,cellId]=unique(coords,'rows','stable');
selected=zeros(0,1);
cells=unique(cellId,'stable');
normScore = 0.65 * sum(C, 2) + 0.35 * sqrt(sum(normC.^2, 2));
for g=reshape(cells,1,[])
    ids=find(cellId==g);
    vals=normScore(ids);
    minVal=min(vals);
    best=min(ids(abs(vals-minVal)<=1e-12));
    selected(end+1,1)=best; %#ok<AGROW>
end

[~,idealBest]=min(sqrt(sum(normC.^2,2)));
[~,rawBest]=min(sum(C,2));
[~,extBest]=min(C,[],1);
mustKeep=unique([idealBest; rawBest; extBest(:)],'stable');
for k=1:numel(mustKeep)
    if ~ismember(mustKeep(k),selected)
        selected=[mustKeep(k); selected]; %#ok<AGROW>
    end
end

hybridC = 0.5 * C + 0.5 * normC;
if numel(selected)>nKeep
    distance=localCrowdingDistance(hybridC(selected,:));
    [~,order]=sortrows([-distance,selected],[1 2]);
    selected=selected(order(1:nKeep));
    for k=1:min(numel(mustKeep),nKeep)
        if ~ismember(mustKeep(k),selected)
            selected(end-k+1)=mustKeep(k);
        end
    end
    selected=unique(selected,'stable');
elseif numel(selected)<nKeep
    remaining=setdiff((1:n)',selected,'stable');
    if ~isempty(remaining)
        distance=localCrowdingDistance(hybridC(remaining,:));
        [~,order]=sortrows([-distance,remaining],[1 2]);
        take=min(nKeep-numel(selected),numel(remaining));
        selected=[selected;remaining(order(1:take))]; %#ok<AGROW>
    end
end
archive=pool(selected);
end

function [distance,orderByObjective]=localCrowdingDistance(costs)
n=size(costs,1);
distance=zeros(n,1);
orderByObjective=zeros(n,size(costs,2));
for j=1:size(costs,2)
    [~,order]=sort(costs(:,j),'ascend');
    orderByObjective(:,j)=order;
    if isempty(order), continue; end
    distance(order(1))=inf;
    distance(order(end))=inf;
    span=costs(order(end),j)-costs(order(1),j);
    if span<=eps,continue;end
    for k=2:n-1
        distance(order(k))=distance(order(k))+ ...
            (costs(order(k+1),j)-costs(order(k-1),j))/span;
    end
end
end

function archive=localUniqueFinite(archive)
archive=archive(:);
if isempty(archive),return;end
keep=false(numel(archive),1);
for i=1:numel(archive)
    keep(i)=~isempty(archive(i).Vector) && ~isempty(archive(i).Cost) && ...
        all(isfinite(archive(i).Vector)) && all(isfinite(archive(i).Cost));
end
archive=archive(keep);
if isempty(archive),return;end
nVector=numel(archive(1).Vector);
vectors=nan(numel(archive),nVector);
for i=1:numel(archive)
    if numel(archive(i).Vector)==nVector
        vectors(i,:)=round(double(archive(i).Vector(:)')*1e10)/1e10;
    end
end
valid=all(isfinite(vectors),2);
archive=archive(valid);
vectors=vectors(valid,:);
if isempty(archive),return;end
[~,uniqueIndex]=unique(vectors,'rows','stable');
archive=archive(uniqueIndex);
end

function costs = localCostMatrix(particles)
costs = reshape([particles.Cost],numel(particles(1).Cost),[])';
end

function audit = localEmptyArchiveAudit()
audit = struct('Triggered',false,'ProtectedPreIndex',NaN, ...
    'ReplacedStandardIndex',NaN,'PreTrimEligibleCount',0, ...
    'StandardEligibleCount',0,'NoReplacementAvailable',false);
end

function history = localHistory(maxIt,nObj,params)
history = struct('BestCost',nan(maxIt,nObj),'RepSize',nan(maxIt,1), ...
    'Time',nan(maxIt,1),'GeneratedCount',zeros(maxIt,1), ...
    'AcceptedCount',zeros(maxIt,1), ...
    'DirectionalReplacementCount',zeros(maxIt,params.nPop), ...
    'AdaptiveF',nan(maxIt,1),'AdaptiveCR',nan(maxIt,1), ...
    'AdaptiveSuccessCount',zeros(maxIt,1), ...
    'MatingNeighborhoodProbability',nan(maxIt,1), ...
    'ControllerMode',{cell(maxIt,1)},'SampledFMean',nan(maxIt,1), ...
    'SampledFSD',nan(maxIt,1),'SampledCRMean',nan(maxIt,1), ...
    'SampledCRSD',nan(maxIt,1),'SampledF',{cell(maxIt,1)}, ...
    'SampledCR',{cell(maxIt,1)},'SampledContext',{cell(maxIt,1)}, ...
    'EligibleSuccessCount',zeros(maxIt,1),'ActualSuccessCount',zeros(maxIt,1), ...
    'ContextSuccessCount',zeros(maxIt,4),'ExcludedCreditCount',zeros(maxIt,1), ...
    'NDCreditEligibleCount',zeros(maxIt,1),'NDDominatedRejectCount',zeros(maxIt,1), ...
    'NDDuplicateRejectCount',zeros(maxIt,1),'NoLearningUpdate',false(maxIt,1), ...
    'MemoryF',{cell(maxIt,1)},'MemoryCR',{cell(maxIt,1)}, ...
    'MemoryPointer',{cell(maxIt,1)});
if localGet(params,'StoreConvergenceHistory',false)
    history.ArchiveCost = cell(maxIt,1);
    history.FE = nan(maxIt,1);
    history.AttemptedFE = nan(maxIt,1);
end
end

function value = localGet(s,name,defaultValue)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    value = s.(name);
else
    value = defaultValue;
end
end








