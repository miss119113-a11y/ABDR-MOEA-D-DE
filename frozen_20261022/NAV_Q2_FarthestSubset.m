function idx = NAV_Q2_FarthestSubset(X, k)
%NAV_Q2_FARTHESTSUBSET Deterministic maximin subset in objective space.
%   The subset protects objective-wise extrema and then greedily maximizes
%   the minimum Euclidean distance to the selected set. This avoids the
%   file-order bias of evenly sampling row indices.

X = double(X);
n = size(X,1);
if n == 0 || k <= 0
    idx = zeros(0,1);
    return;
end
k = min(n, round(k));
if n <= k
    idx = (1:n)';
    return;
end

% Canonical row order makes the result independent of task-file ordering.
[Xs, order] = sortrows(X, 1:size(X,2));
selected = false(n,1);
seed = [];
for j = 1:size(Xs,2)
    [~, iMin] = min(Xs(:,j));
    [~, iMax] = max(Xs(:,j));
    seed = [seed; iMin; iMax]; %#ok<AGROW>
end
[~, iCenter] = min(sum((Xs - median(Xs,1)).^2,2));
seed = [seed; iCenter];
seed = unique(seed, 'stable');
seed = seed(1:min(numel(seed),k));
selected(seed) = true;

minDist2 = inf(n,1);
for s = seed(:)'
    d2 = sum((Xs - Xs(s,:)).^2,2);
    minDist2 = min(minDist2, d2);
end
minDist2(selected) = -Inf;
while nnz(selected) < k
    [~, next] = max(minDist2);
    selected(next) = true;
    d2 = sum((Xs - Xs(next,:)).^2,2);
    minDist2 = min(minDist2, d2);
    minDist2(selected) = -Inf;
end
idxSorted = find(selected);
idx = order(idxSorted);
idx = idx(:);
end