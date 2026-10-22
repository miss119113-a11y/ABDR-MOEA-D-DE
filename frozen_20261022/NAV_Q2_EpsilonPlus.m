function value = NAV_Q2_EpsilonPlus(referenceFront, approximation)
%NAV_Q2_EPSILONPLUS Unary additive epsilon indicator for minimization.
%   Returns the smallest additive translation epsilon such that the shifted
%   approximation weakly dominates every point in the reference set:
%       I_eps+(A,R) = max_r min_a max_j (a_j-r_j).
%   Lower is better; zero means the approximation weakly covers R.

R = double(referenceFront);
A = double(approximation);
R = R(all(isfinite(R),2),:);
A = A(all(isfinite(A),2),:);
if isempty(R) || isempty(A)
    value = NaN;
    return;
end
if size(R,2) ~= size(A,2)
    error('NAV_Q2_EpsilonPlus:DimensionMismatch','Reference and approximation dimensions differ.');
end
bestForR = inf(size(R,1),1);
for i = 1:size(A,1)
    epsToR = max(A(i,:) - R, [], 2);
    bestForR = min(bestForR, epsToR);
end
value = max(bestForR);
end