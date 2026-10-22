function [sdValue, occupiedCells] = NAV_Q2_GridDistribution(A, M)
%NAV_Q2_GRIDDISTRIBUTION Reference-paper-compatible solution distribution.
%   sd = n_p / n_o, where n_p is the number of non-dominated solutions and
%   n_o is the number of occupied hypergrid cells. Lower is better and the
%   theoretical best value is 1. The grid follows the padded range and
%   nearest-integer coordinate construction used by the NMOPSO paper.

if nargin<2 || isempty(M),M=7;end
validateattributes(M,{'numeric'},{'scalar','integer','>=',2});
A=double(A);
A=A(all(isfinite(A),2),:);
n=size(A,1);
if n==0
    sdValue=NaN;occupiedCells=0;return;
end
if n==1
    sdValue=1;occupiedCells=1;return;
end
lo=min(A,[],1);hi=max(A,[],1);span=hi-lo;
pad=span./(2*(M-1));
% A zero-range objective carries no distribution information. Give it one
% stable cell instead of dividing by zero.
zero=span<=1e-14;
GL=lo-pad;GU=hi+pad;
coord=ones(size(A));
for j=1:size(A,2)
    if zero(j),continue;end
    coord(:,j)=round(M*(A(:,j)-GL(j))/(GU(j)-GL(j)));
    coord(:,j)=min(M,max(0,coord(:,j)));
end
occupiedCells=size(unique(coord,'rows'),1);
sdValue=n/max(1,occupiedCells);
end
