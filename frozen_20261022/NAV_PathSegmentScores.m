function scores = NAV_PathSegmentScores(pos, model)
% Heuristic segment diagnostics in the frozen metre-scale path frame.
    path = NAV_ConvertPath(pos,model);
    xyz = path.AbsoluteM;
    x = xyz(:,1)'; y = xyz(:,2)'; z = xyz(:,3)';
    n = numel(pos.r);

    len = zeros(1,n);
    risk = zeros(1,n);
    turn = abs(pos.psi) + 0.65 * abs(pos.phi);
    alt = abs(path.MiddleRelativeM(:,3)' - (model.zmin + model.zmax)/2) ./ ((model.zmax-model.zmin)/2);

    threats = model.threats;
    for j = 1:n
        len(j) = norm([x(j+1)-x(j), y(j+1)-y(j), z(j+1)-z(j)]);
        for k = 1:size(threats,1)
            center = (double(threats(k,1:2))-1)*path.PixelSizeM;
            d = DistP2S(center, [x(j) y(j)], [x(j+1) y(j+1)]);
            margin = d - double(threats(k,4))*path.PixelSizeM;
            risk(j) = max(risk(j), 1 / max(margin, 1));
        end
    end

    scores.length = len ./ (max(len) + eps);
    scores.risk = risk ./ (max(risk) + eps);
    scores.turn = turn ./ (max(turn) + eps);
    scores.altitude = alt ./ (max(alt) + eps);
    scores.total = 0.42*scores.length + 0.28*scores.risk + 0.10*scores.altitude + 0.20*scores.turn;
end
