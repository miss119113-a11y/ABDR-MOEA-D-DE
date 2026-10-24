function Q = NAV_SHDE_FREEZE_PARETO_Q(repCosts,popCosts,repFeasible,popFeasible)
% Assemble generation-start feasible set for D learning credit only.
assert(islogical(repFeasible)&&islogical(popFeasible),'SHDE:NDMaskLogical','Feasibility masks must be logical.');
assert(size(repCosts,1)==numel(repFeasible)&&size(popCosts,1)==numel(popFeasible), ...
    'SHDE:NDMaskShape','Feasibility mask sizes do not match cost rows.');
assert(size(repCosts,2)==size(popCosts,2),'SHDE:NDObjectiveShape','rep/pop objective dimensions differ.');
Q=[double(repCosts(repFeasible,:));double(popCosts(popFeasible,:))];
end
