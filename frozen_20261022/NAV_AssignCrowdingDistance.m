function pop = NAV_AssignCrowdingDistance(pop, idx)
    if isempty(idx)
        return;
    end
    costs = reshape([pop(idx).Cost], numel(pop(idx(1)).Cost), [])';
    m = size(costs,2);
    d = zeros(numel(idx),1);

    for j = 1:m
        [~, order] = sort(costs(:,j));
        d(order(1)) = inf;
        d(order(end)) = inf;
        cmin = costs(order(1),j);
        cmax = costs(order(end),j);
        if cmax - cmin < eps
            continue;
        end
        for k = 2:numel(idx)-1
            d(order(k)) = d(order(k)) + (costs(order(k+1),j)-costs(order(k-1),j))/(cmax-cmin);
        end
    end

    for k = 1:numel(idx)
        pop(idx(k)).CrowdingDistance = d(k);
    end
end