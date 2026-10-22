function [bestPos, bestCost] = NAV_TargetedRepair(pos, cost, model, VarMin, VarMax, CostFunction, params, it)
% Segment-aware repair: shorten, detour, smooth, or altitude-pull the worst local part.
    bestPos = pos;
    bestCost = cost;
    epsRisk = NAV_RiskEpsilon(params, it);

    for tr = 1:params.repairTries
        scores = NAV_PathSegmentScores(bestPos, model);
        [~, j] = max(scores.total + 0.05*rand(size(scores.total)));
        cand = bestPos;
        mode = rand;

        if mode < 0.35
            ids = max(1,j-1):min(numel(cand.r),j+1);
            rate = params.contractRate * (0.55 + 0.45*rand);
            cand.r(j) = cand.r(j) * (1 - rate);
            cand.phi(ids) = cand.phi(ids) * (1 - 0.35*rate);
            cand.psi(ids) = cand.psi(ids) * (1 - 0.55*rate);
        elseif mode < 0.60
            side = sign(cand.phi(j));
            if side == 0
                side = sign(rand - 0.5);
                if side == 0, side = 1; end
            end
            cand.phi(j) = cand.phi(j) + side * (0.05 + 0.10*rand);
            cand.psi(j) = cand.psi(j) * (0.85 + 0.10*rand);
        elseif mode < 0.82
            ids = max(1,j-1):min(numel(cand.r),j+1);
            cand.phi(ids) = cand.phi(ids) * (1 - params.smoothRate);
            cand.psi(ids) = cand.psi(ids) * (1 - params.smoothRate);
        else
            cand.phi(j) = cand.phi(j) * (0.75 + 0.10*rand);
            cand.r(j) = cand.r(j) * (0.96 + 0.08*rand);
        end

        cand.r = cand.r .* (1 + params.jitterScale * randn(size(cand.r)));
        cand = NAV_ClampPosition(cand, VarMin, VarMax);
        if ~NAV_FE_HasBudget(), break; end
        [candCost, evalOK] = NAV_FE_Evaluate(CostFunction, cand);
        if ~evalOK, break; end

        riskOK = candCost(2) <= max(bestCost(2), epsRisk) + 1e-12;
        f1OK = candCost(1) <= bestCost(1) * (1 + params.f1Tolerance) + 1e-12;
        f3OK = candCost(3) <= bestCost(3) * (1 + params.f3Tolerance) + 1e-12;
        f4OK = candCost(4) <= bestCost(4) * (1 + params.f4Tolerance) + 1e-12;
        gain = sum(candCost([1 2 4]) .* [0.45; 0.30; 0.25]) < sum(bestCost([1 2 4]) .* [0.45; 0.30; 0.25]);

        if all(isfinite(candCost)) && riskOK && f1OK && f3OK && f4OK && (Dominates(candCost, bestCost) || gain)
            bestPos = cand;
            bestCost = candCost;
        end
    end
end