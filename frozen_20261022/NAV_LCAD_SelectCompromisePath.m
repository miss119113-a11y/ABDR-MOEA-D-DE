function [best, idx, score] = NAV_LCAD_SelectCompromisePath(rep, params)
%NAV_LCAD_SELECTCOMPROMISEPATH Aligned representative path selection.
% Decision rule: argmin(F1+F2+F3+F4).  Geometry is not used to override
% TotalCost; it can only break exact numerical ties through F2/F4 ordering.
    if nargin < 2, params = struct(); end %#ok<NASGU>
    if isempty(rep), error('NAV_LCAD_SelectCompromisePath:EmptyArchive','Empty archive.'); end
    if exist('NAV_SelectPaperTotalSolution','file') == 2
        [best, idx, score] = NAV_SelectPaperTotalSolution(rep);
        return;
    end
    nObj = numel(rep(1).Cost);
    C = nan(numel(rep), nObj);
    for i=1:numel(rep)
        c = rep(i).Cost(:)';
        C(i,1:min(nObj,numel(c))) = c(1:min(nObj,numel(c)));
    end
    score = sum(C(:,1:min(4,nObj)),2);
    score(~all(isfinite(C),2)) = Inf;
    tie = zeros(size(score));
    if nObj>=2, tie = tie + C(:,2); end
    if nObj>=4, tie = tie + 0.1*C(:,4); end
    if nObj>=1, tie = tie + 0.01*C(:,1); end
    [~, idx] = min(score + 1e-12*tie);
    best = rep(idx);
    score = score(idx);
end
