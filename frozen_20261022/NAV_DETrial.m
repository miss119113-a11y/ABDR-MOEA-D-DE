function trial = NAV_DETrial(particle, i, bestIdx, pool, VarMin, VarMax, params, it)
    n = numel(particle(i).Position.r);
    if numel(pool) < 4
        pool = 1:numel(particle);
    end
    pool = unique(pool(:)');
    pool(pool == i) = [];
    if numel(pool) < 3
        pool = setdiff(1:numel(particle), i);
    end
    rp = pool(randperm(numel(pool), min(3, numel(pool))));
    while numel(rp) < 3
        rp = [rp pool(randi(numel(pool)))]; %#ok<AGROW>
    end

    progress = it / max(params.MaxIt, 1);
    F = params.Fmax - (params.Fmax - params.Fmin) * progress;
    F = F * (0.85 + 0.30 * rand);
    CR = params.CRmin + (params.CRmax - params.CRmin) * progress;

    x = particle(i).Position;
    xb = particle(bestIdx).Position;
    xr1 = particle(rp(1)).Position;
    xr2 = particle(rp(2)).Position;
    xr3 = particle(rp(3)).Position;

    donor.r = x.r + F*(xb.r-x.r) + F*(xr1.r-xr2.r);
    donor.phi = x.phi + F*(xb.phi-x.phi) + F*(xr1.phi-xr2.phi);
    donor.psi = x.psi + F*(xb.psi-x.psi) + F*(xr1.psi-xr2.psi);

    if rand < 0.22 * (1-progress)
        donor.r = xr1.r + F*(xr2.r-xr3.r);
        donor.phi = xr1.phi + F*(xr2.phi-xr3.phi);
        donor.psi = xr1.psi + F*(xr2.psi-xr3.psi);
    end

    trial = x;
    mask = rand(1,n) < CR; if ~any(mask), mask(randi(n)) = true; end
    trial.r(mask) = donor.r(mask);
    mask = rand(1,n) < CR; if ~any(mask), mask(randi(n)) = true; end
    trial.phi(mask) = donor.phi(mask);
    mask = rand(1,n) < CR; if ~any(mask), mask(randi(n)) = true; end
    trial.psi(mask) = donor.psi(mask);
    trial = NAV_ClampPosition(trial, VarMin, VarMax);
end