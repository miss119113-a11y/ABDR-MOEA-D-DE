function [cost,ok] = NAV_FE_Evaluate(CostFunction,position)
%NAV_FE_EVALUATE Evaluate one candidate only while FE budget remains.
% This prevents post-budget calls from reaching MyCost under exact-FE runs.
cost = inf(4,1);
ok = false;
if nargin < 2 || isempty(CostFunction) || ~NAV_FE_HasBudget()
    return;
end
try
    cost = CostFunction(position);
    if isempty(cost)
        cost = inf(4,1);
    else
        cost = cost(:);
    end
    ok = true;
catch
    cost = inf(4,1);
end
end
