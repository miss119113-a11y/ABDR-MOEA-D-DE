function [best, idx, score] = NAV_FEC_SelectCompromisePath(rep, params)
%NAV_FEC_SELECTCOMPROMISEPATH Select the paper's deterministic compromise.
%   Compatibility entry point retained for the active SPEA2 baseline.

if nargin < 2
    params = struct(); %#ok<NASGU>
end
if isempty(rep)
    error('NAV_FEC_SelectCompromisePath:EmptyArchive', 'Empty archive.');
end
if exist('NAV_SelectPaperTotalSolution', 'file') == 2
    [best, idx, score] = NAV_SelectPaperTotalSolution(rep);
    return;
end

nObj = numel(rep(1).Cost);
costs = localCostMatrix(rep, nObj);
score = sum(costs(:, 1:min(4, nObj)), 2);
score(~all(isfinite(costs), 2)) = Inf;
tie = zeros(size(score));
if nObj >= 2, tie = tie + costs(:, 2); end
if nObj >= 4, tie = tie + 0.1 * costs(:, 4); end
if nObj >= 1, tie = tie + 0.01 * costs(:, 1); end
[~, idx] = min(score + 1e-12 * tie);
best = rep(idx);
score = score(idx);
end

function costs = localCostMatrix(items, nObj)
costs = nan(numel(items), nObj);
for i = 1:numel(items)
    cost = items(i).Cost(:)';
    count = min(nObj, numel(cost));
    costs(i, 1:count) = cost(1:count);
end
end