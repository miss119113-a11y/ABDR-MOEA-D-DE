function best = NAV_SelectCompromiseSolution(rep, weights)
    if nargin < 2 || isempty(weights)
        weights = [0.40 0.25 0.10 0.25];
    end
    costs = reshape([rep.Cost], numel(rep(1).Cost), [])';
    cmin = min(costs, [], 1);
    cmax = max(costs, [], 1);
    normCost = (costs - cmin) ./ (cmax - cmin + eps);
    score = normCost * weights(:);
    risk = costs(:,2);
    score = score + 2.0 * risk;
    [~, idx] = min(score);
    best = rep(idx);
end