function [F,CR,cellIndex] = NAV_SHDE_ADAPTIVE_SAMPLE(memoryF,memoryCR,contextIndex,cellProb)
% Sample a trial pair from one five-cell success-history context.
% Supports optional cell selection probability vector for multi-memory feedback.
if nargin >= 4 && ~isempty(cellProb)
    p = cellProb(contextIndex, :);
    cumP = cumsum(p);
    r = rand * cumP(end);
    cellIndex = find(r <= cumP, 1, 'first');
    if isempty(cellIndex), cellIndex = randi(size(memoryF, 2)); end
else
    cellIndex = randi(size(memoryF, 2));
end
muF = memoryF(contextIndex, cellIndex);
muCR = memoryCR(contextIndex, cellIndex);
F = muF + 0.1 * tan(pi * (rand - 0.5));
while F <= 0
    F = muF + 0.1 * tan(pi * (rand - 0.5));
end
F = min(F, 1);
CR = min(1, max(0, muCR + 0.1 * randn));
end
