function [eligible,dominated,duplicate] = NAV_SHDE_PARETO_LEARNING_GATE(cost,Q,tol)
% Generation-frozen feasible Pareto learning gate. Does not affect acceptance.
if nargin<3||isempty(tol),tol=1e-12;end
c=double(cost(:)');Q=double(Q);
if isempty(Q),eligible=true;dominated=false;duplicate=false;return;end
assert(size(Q,2)==numel(c),'SHDE:NDShape','Q and cost dimensions differ.');
assert(all(isfinite(c))&&all(isfinite(Q(:))),'SHDE:NDFinite','Gate inputs must be finite.');
duplicate=any(all(abs(Q-c)<=tol,2));
dominated=any(all(Q<=c+tol,2)&any(Q<c-tol,2));
eligible=~dominated&&~duplicate;
end