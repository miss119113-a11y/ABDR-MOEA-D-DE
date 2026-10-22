function hv = NAV_Q2_HypervolumeExact(P, refPoint)
%NAV_Q2_HYPERVOLUMEEXACT Exact dominated hypervolume for minimization.
%   HV = NAV_Q2_HypervolumeExact(P, REFPOINT) computes the Lebesgue measure
%   dominated by the non-dominated approximation P and bounded by REFPOINT.
%   The recursive slicing implementation is intended for the four-objective
%   UAV archives in this project (normally <= 50 points).
%
%   Points that do not strictly dominate REFPOINT in every objective cannot
%   contribute a positive hyper-rectangle and are discarded.

P = double(P);
refPoint = double(refPoint(:)');
if isempty(P)
    hv = 0;
    return;
end
if size(P,2) ~= numel(refPoint)
    error('NAV_Q2_HypervolumeExact:DimensionMismatch', ...
        'P has %d objectives but refPoint has %d.', size(P,2), numel(refPoint));
end
P = P(all(isfinite(P),2),:);
P = P(all(P < refPoint,2),:);
if isempty(P)
    hv = 0;
    return;
end
P = NAV_Q2_Nondominated(P);
hv = localHV(P, refPoint);
hv = max(0, double(hv));
end

function value = localHV(P, refPoint)
d = size(P,2);
if isempty(P)
    value = 0;
    return;
end
if d == 1
    value = max(0, refPoint(1) - min(P(:,1)));
    return;
end

% Sweep the first objective. On [x_i,x_{i+1}), the cross-section is the
% hypervolume dominated by all points whose first coordinate <= x_i.
x = unique(P(:,1));
x = x(x < refPoint(1));
if isempty(x)
    value = 0;
    return;
end
x = sort(x, 'ascend');
value = 0;
for i = 1:numel(x)
    xLeft = x(i);
    if i < numel(x)
        xRight = min(x(i+1), refPoint(1));
    else
        xRight = refPoint(1);
    end
    width = xRight - xLeft;
    if width <= 0, continue; end
    active = P(P(:,1) <= xLeft + 1e-14, 2:end);
    active = NAV_Q2_Nondominated(active);
    value = value + width * localHV(active, refPoint(2:end));
end
end