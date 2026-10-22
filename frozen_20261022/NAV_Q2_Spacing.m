function [spacing, nnCV] = NAV_Q2_Spacing(A)
%NAV_Q2_SPACING Spacing and nearest-neighbour coefficient of variation.
%   SPACING uses the classical nearest-neighbour Manhattan-distance spread.
%   NNCV is retained as a secondary continuity check with the project's old
%   SpreadNN convention (Euclidean nearest-neighbour std/mean).

A = double(A);
A = A(all(isfinite(A),2),:);
n = size(A,1);
if n < 2
    spacing = NaN;
    nnCV = NaN;
    return;
end
D1 = inf(n,n);
D2 = inf(n,n);
for i = 1:n
    delta = A - A(i,:);
    D1(i,:) = sum(abs(delta),2)';
    D2(i,:) = sqrt(sum(delta.^2,2))';
end
D1(1:n+1:end) = Inf;
D2(1:n+1:end) = Inf;
d1 = min(D1,[],2);
d2 = min(D2,[],2);
spacing = sqrt(sum((d1-mean(d1)).^2) / max(1,n-1));
mu = mean(d2);
if mu <= eps
    nnCV = 0;
else
    nnCV = std(d2,0) / mu;
end
end
