function value = NAV_Q2_IGDPlus(referenceFront, approximation)
%NAV_Q2_IGDPLUS Weakly Pareto-compliant inverted generational distance plus.
%   For minimization, d+(r,a)=sqrt(sum(max(a-r,0).^2)). The indicator is the
%   mean distance from every reference point to its closest approximation.

R = double(referenceFront);
A = double(approximation);
R = R(all(isfinite(R),2),:);
A = A(all(isfinite(A),2),:);
if isempty(R) || isempty(A)
    value = NaN;
    return;
end
if size(R,2) ~= size(A,2)
    error('NAV_Q2_IGDPlus:DimensionMismatch','Reference and approximation dimensions differ.');
end
mins = inf(size(R,1),1);
for i = 1:size(A,1)
    D = max(A(i,:) - R, 0);
    di = sqrt(sum(D.^2,2));
    mins = min(mins, di);
end
value = mean(mins, 'omitnan');
end