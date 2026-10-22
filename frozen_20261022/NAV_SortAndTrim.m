function pop = NAV_SortAndTrim(pop, nKeep)
    finiteMask = arrayfun(@(p) all(isfinite(p.Cost)), pop);
    pop = pop(finiteMask);
    if isempty(pop)
        return;
    end
    [pop, fronts] = NAV_NonDominatedSort(pop);
    selected = [];
    for f = 1:numel(fronts)
        idx = fronts{f};
        if isempty(idx), continue; end
        pop = NAV_AssignCrowdingDistance(pop, idx);
        if numel(selected) + numel(idx) <= nKeep
            selected = [selected idx]; %#ok<AGROW>
        else
            [~, ord] = sort([pop(idx).CrowdingDistance], 'descend');
            need = nKeep - numel(selected);
            selected = [selected idx(ord(1:need))]; %#ok<AGROW>
            break;
        end
    end
    pop = pop(selected);
end
