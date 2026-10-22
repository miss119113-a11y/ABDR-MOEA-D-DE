function [pop, fronts] = NAV_NonDominatedSort(pop)
    n = numel(pop);
    S = cell(n,1);
    nDom = zeros(n,1);
    fronts = {};
    fronts{1} = [];

    for p = 1:n
        S{p} = [];
        nDom(p) = 0;
        for q = 1:n
            if Dominates(pop(p), pop(q))
                S{p} = [S{p} q]; %#ok<AGROW>
            elseif Dominates(pop(q), pop(p))
                nDom(p) = nDom(p) + 1;
            end
        end
        if nDom(p) == 0 && all(isfinite(pop(p).Cost))
            pop(p).Rank = 1;
            fronts{1} = [fronts{1} p]; %#ok<AGROW>
        end
    end

    i = 1;
    while i <= numel(fronts) && ~isempty(fronts{i})
        Q = [];
        for p = fronts{i}
            for q = S{p}
                nDom(q) = nDom(q) - 1;
                if nDom(q) == 0
                    pop(q).Rank = i + 1;
                    Q = [Q q]; %#ok<AGROW>
                end
            end
        end
        i = i + 1;
        if ~isempty(Q)
            fronts{i} = Q; %#ok<AGROW>
        end
    end
end
