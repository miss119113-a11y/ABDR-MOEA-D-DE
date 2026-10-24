function score = NAV_InitCostScore(cost)
    c = cost(:)';
    bad = ~isfinite(c);
    c(bad) = 10;
    score = [1.0 4.0 0.5 1.0] * c(:) + 100 * sum(bad);
end
