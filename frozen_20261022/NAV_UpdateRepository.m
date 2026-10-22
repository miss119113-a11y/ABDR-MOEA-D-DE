function [rep, Grid] = NAV_UpdateRepository(rep, pop, nRep, nGrid, alpha, gamma)
    if isempty(rep)
        rep = pop;
    else
        rep = [rep; pop(:)]; %#ok<AGROW>
    end

    rep = DetermineDomination(rep);
    rep = rep(~[rep.IsDominated]);
    finiteMask = arrayfun(@(p) all(isfinite(p.Cost)), rep);
    rep = rep(finiteMask);

    if isempty(rep)
        Grid = [];
        return;
    end

    Grid = CreateGrid(rep, nGrid, alpha);
    for i = 1:numel(rep)
        rep(i) = FindGridIndex(rep(i), Grid);
    end

    while numel(rep) > nRep
        rep = DeleteOneRepMember(rep, gamma);
    end

    Grid = CreateGrid(rep, nGrid, alpha);
    for i = 1:numel(rep)
        rep(i) = FindGridIndex(rep(i), Grid);
    end
end