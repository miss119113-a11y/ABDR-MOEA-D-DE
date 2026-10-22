function ok = NAV_FeasibilityBetter(newCost, oldCost, weight, zIdeal, epsRisk)
    if any(~isfinite(newCost))
        ok = false;
        return;
    end
    if any(~isfinite(oldCost))
        ok = true;
        return;
    end

    newRisk = newCost(2);
    oldRisk = oldCost(2);
    newFeas = newRisk <= epsRisk;
    oldFeas = oldRisk <= epsRisk;

    if newFeas && ~oldFeas
        ok = true;
    elseif ~newFeas && oldFeas
        ok = false;
    elseif ~newFeas && ~oldFeas
        ok = newRisk < oldRisk;
    else
        ok = NAV_Tchebycheff(newCost, weight, zIdeal) <= NAV_Tchebycheff(oldCost, weight, zIdeal);
    end
end