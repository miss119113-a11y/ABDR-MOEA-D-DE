function G = NAV_FDEPV2_CommonGrid(C,M)
%NAV_FDEPV2_COMMONGRID Common normalized fixed-grid archive distribution.
% Unlike the NMOPSO-compatible local-range grid, every method and run uses
% exactly the same cells. The output reports coverage and redundancy
% separately so a tiny archive cannot be declared diverse from sd alone.

if nargin<2 || isempty(M),M=7;end
validateattributes(M,{'numeric'},{'scalar','integer','>=',2});
C=double(C);
C=C(all(isfinite(C),2),:);
if isempty(C)
    G=struct('NP',0,'OccupiedCells',0,'Redundancy',NaN, ...
        'Efficiency',NaN,'GlobalCoverage',0,'GridDivisions',M);
    return;
end
C=C(:,1:min(4,size(C,2)));
if size(C,2)<4
    error('NAV_FDEPV2_CommonGrid:FourObjectives','Four objectives are required.');
end
C=min(1,max(0,C));
coord=min(M,max(1,floor(C*M)+1));
coord(C>=1)=M;
occupied=size(unique(coord,'rows'),1);
np=size(C,1);
G=struct( ...
    'NP',np, ...
    'OccupiedCells',occupied, ...
    'Redundancy',np/max(1,occupied), ...
    'Efficiency',occupied/max(1,np), ...
    'GlobalCoverage',occupied/(M^4), ...
    'GridDivisions',M);
end