function [bestPos, bestCost] = NAV_CreateFeasibleSolution(model, VarSize, VarMin, VarMax, CostFunction, params)
    bestScore = inf;
    bestPos = [];
    bestCost = [];

    [sharedPos,hasShared] = localSharedInitialPosition();
    if hasShared
        [sharedCost, sharedOK] = NAV_FE_Evaluate(CostFunction, sharedPos);
        if ~sharedOK, return; end
        if localIsFeasibleCost(sharedCost)
            bestPos=sharedPos;
            bestCost=sharedCost;
            return;
        end
    end

    for a = 1:params.initMaxTry
        if a <= 5 || rand < params.guidedInitRatio
            pos = NAV_CreateGuidedSolution(model, VarMin, VarMax, params);
        else
            pos = NAV_CreateRandomSolution(VarSize, VarMin, VarMax);
        end

        [cost, evalOK] = NAV_FE_Evaluate(CostFunction, pos);
        if ~evalOK, break; end
        score = NAV_InitCostScore(cost);
        if score < bestScore
            bestScore = score;
            bestPos = pos;
            bestCost = cost;
        end
        if localIsFeasibleCost(cost)
            return;
        end
    end

    base = bestPos;
    for a = 1:ceil(params.initMaxTry/2)
        pos = base;
        pos.r = pos.r .* (0.86 + 0.28 * rand(size(pos.r)));
        pos.phi = pos.phi + 0.16 * randn(size(pos.phi));
        pos.psi = pos.psi + 0.16 * randn(size(pos.psi));
        pos = NAV_ClampPosition(pos, VarMin, VarMax);
        [cost, evalOK] = NAV_FE_Evaluate(CostFunction, pos);
        if ~evalOK, break; end
        score = NAV_InitCostScore(cost);
        if score < bestScore
            bestScore = score;
            bestPos = pos;
            bestCost = cost;
        end
        if localIsFeasibleCost(cost)
            return;
        end
    end

    % Deterministic dog-leg templates prevent seed-specific collapse when
    % dense cylindrical threats make straight-biased initialization empty.
    [fallbackPos,fallbackCost] = NAV_CreateDeterministicFeasibleSolution( ...
        model,VarMin,VarMax,CostFunction);
    if localIsFeasibleCost(fallbackCost)
        bestPos=fallbackPos;
        bestCost=fallbackCost;
    end
end

function tf = localIsFeasibleCost(cost)
c=double(cost(:));
tf=numel(c)>=4 && all(isfinite(c(1:4))) && all(c(1:4)<=1+1e-12);
end

function [pos,tf] = localSharedInitialPosition()
pos=[]; tf=false;
try
    if ~isappdata(0,'NAV_SHARED_INIT_POOL'), return; end
    pool=getappdata(0,'NAV_SHARED_INIT_POOL');
    if isempty(pool), return; end
    cursor=1;
    if isappdata(0,'NAV_SHARED_INIT_CURSOR')
        cursor=max(1,round(double(getappdata(0,'NAV_SHARED_INIT_CURSOR'))));
    end
    if cursor>numel(pool), return; end
    if iscell(pool), pos=pool{cursor}; else, pos=pool(cursor); end
    setappdata(0,'NAV_SHARED_INIT_CURSOR',cursor+1);
    tf=isstruct(pos) && all(isfield(pos,{'r','phi','psi'}));
catch
    pos=[]; tf=false;
end
end