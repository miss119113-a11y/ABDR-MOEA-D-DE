function tf = Dominates(x, y)
%DOMINATES Strict Pareto dominance for legacy baseline compatibility.
%   Active NMOPSO, SPEA2, and repository helpers use this conventional
%   two-argument entry point.  It intentionally accepts either Cost vectors
%   or particle structs carrying a Cost field.

if isstruct(x)
    x = x.Cost;
end
if isstruct(y)
    y = y.Cost;
end

x = x(:);
y = y(:);
tf = all(x <= y) && any(x < y) && all(x < inf);
end
