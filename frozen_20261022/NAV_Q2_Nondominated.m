function ND = NAV_Q2_Nondominated(C, tol)
%NAV_Q2_NONDOMINATED Return unique non-dominated rows for minimization.
%   ND = NAV_Q2_Nondominated(C) removes non-finite rows, merges numerical
%   duplicates, and returns the Pareto non-dominated objective vectors.
%
%   This function is evaluation-only. It does not alter any optimizer.

if nargin < 2 || isempty(tol), tol = 1e-12; end
C = double(C);
if isempty(C)
    ND = zeros(0, size(C,2));
    return;
end
C = C(all(isfinite(C),2),:);
if isempty(C)
    ND = zeros(0, size(C,2));
    return;
end

% Quantized uniqueness prevents nearly identical floating-point copies from
% inflating archive size and set indicators.
scale = max(1, max(abs(C),[],1));
Q = round(C ./ (tol .* scale)) .* (tol .* scale);
[~, ia] = unique(Q, 'rows', 'stable');
C = C(sort(ia),:);

n = size(C,1);
keep = true(n,1);
for i = 1:n
    if ~keep(i), continue; end
    % j dominates i if j is no worse in all objectives and strictly better
    % in at least one objective, allowing a small numerical tolerance.
    noWorse = all(C <= C(i,:) + tol, 2);
    strictlyBetter = any(C < C(i,:) - tol, 2);
    dom = noWorse & strictlyBetter;
    dom(i) = false;
    if any(dom), keep(i) = false; end
end
ND = C(keep,:);
ND = sortrows(ND, 1:size(ND,2));
end