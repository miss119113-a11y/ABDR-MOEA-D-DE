function [best, bestIndex, bestTotalCost] = NAV_SelectPaperTotalSolution(rep, weights)
%NAV_SELECTPAPERTOTALSOLUTION Select the reported representative path.
%
% This helper is for paper-facing experiment reporting only.  It does not
% change the search process of any algorithm.  After an algorithm returns its
% Pareto/archive set REP, the representative path written to result tables is
% selected by the same equal-weight scalar used in the paper-style TotalCost
% ranking:
%
%       TotalCost = F1 + F2 + F3 + F4
%
% If WEIGHTS is supplied, it uses sum_j WEIGHTS(j)*F_j.  The default is the
% equal-weight four-objective scalar.

    if nargin < 2 || isempty(weights)
        weights = [];
    end

    if isempty(rep)
        error('NAV_SelectPaperTotalSolution:EmptyRepository', ...
            'The returned repository/archive is empty; cannot select a representative solution.');
    end

    if ~isfield(rep, 'Cost')
        error('NAV_SelectPaperTotalSolution:MissingCost', ...
            'Repository members must contain a Cost field.');
    end

    nObj = numel(rep(1).Cost);
    if isempty(weights)
        weights = ones(1, nObj);
    else
        weights = weights(:)';
        if numel(weights) ~= nObj
            error('NAV_SelectPaperTotalSolution:BadWeights', ...
                'weights has %d elements but repository costs have %d objectives.', numel(weights), nObj);
        end
    end

    costs = reshape([rep.Cost], nObj, [])';
    finite = all(isfinite(costs), 2);
    score = inf(size(costs, 1), 1);
    score(finite) = costs(finite, :) * weights(:);

    if all(~isfinite(score))
        % Keep the failure explicit but still deterministic.  This case should
        % not occur in valid paper-facing runs.
        absCosts = abs(costs);
        absCosts(~isfinite(absCosts)) = realmax('double')/100;
        score = absCosts * abs(weights(:));
    end

    % Deterministic tie-breaker: if two candidates have numerically identical
    % TotalCost, prefer the lower risk, then lower smoothness, then shorter path.
    tie = zeros(size(score));
    if nObj >= 2, tie = tie + costs(:,2); end
    if nObj >= 4, tie = tie + 0.1*costs(:,4); end
    if nObj >= 1, tie = tie + 0.01*costs(:,1); end
    tie = 1e-12 * tie;
    tie(~isfinite(tie)) = 0;
    [bestTotalCost, bestIndex] = min(score + tie);
    best = rep(bestIndex);

    % Return the exact untied scalar as bestTotalCost.
    bestTotalCost = score(bestIndex);
end
