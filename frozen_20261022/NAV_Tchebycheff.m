function g = NAV_Tchebycheff(cost, weight, zIdeal)
    c = cost(:)';
    w = max(weight(:)', 1e-6);
    if any(~isfinite(c))
        g = inf;
    else
        g = max(w .* abs(c - zIdeal));
    end
end
