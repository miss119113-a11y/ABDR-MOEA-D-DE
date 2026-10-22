function pos = NAV_CreateGuidedSolution(model, VarMin, VarMax, params)
% Straight-to-goal prior with mild angle noise.
    n = model.n;
    [~,~,boundsMeta] = NAV_NavigationBounds(model);
    dist = boundsMeta.DirectDistanceM;
    baseR = dist / (n + 1);

    pos.r = baseR * (0.90 + 0.20 * rand(1, n));
    pos.phi = params.guidedAngleStd * randn(1, n);
    pos.psi = params.guidedAngleStd * randn(1, n);

    avoidSign = sign(rand - 0.5);
    if avoidSign == 0
        avoidSign = 1;
    end
    mid = max(2, round(n/2));
    pos.phi(max(1,mid-2):min(n,mid+2)) = pos.phi(max(1,mid-2):min(n,mid+2)) + avoidSign * (0.06 + 0.08*rand);

    pos = NAV_ClampPosition(pos, VarMin, VarMax);
end