function [objective,contributions]=TRIAD_PRESSURE(cost,weight,ideal,fallback)
% Active component of the SAME raw Tchebycheff used for acceptance.
contributions=max(double(weight(:)'),1e-12).*max(0,double(cost(:)')-double(ideal(:)'));
assert(numel(contributions)==4&&all(isfinite(contributions)));
if max(contributions)<=0,objective=fallback;else,[~,objective]=max(contributions);end
end