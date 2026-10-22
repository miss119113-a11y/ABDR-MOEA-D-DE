function B = NAV_Neighborhood(W, T)
    n = size(W, 1);
    T = min(T, n);
    D = zeros(n, n);
    for i = 1:n
        diff = W - W(i,:);
        D(i,:) = sqrt(sum(diff.^2, 2));
    end
    [~, idx] = sort(D, 2, 'ascend');
    B = idx(:, 1:T);
end