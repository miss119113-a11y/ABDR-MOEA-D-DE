function G = NAV_FEC_FlightEnvelopeMetrics(candidate, model, params)
%NAV_FEC_FLIGHTENVELOPEMETRICS Flight-envelope diagnostics for UAV paths.
% Accepts a particle/best struct, a Position struct, or an N-by-3 xyz path.
    if nargin < 3 || isempty(params), params = struct(); end
    [xyz,pathMeta] = localExtractXYZ(candidate, model);
    if isempty(xyz) || size(xyz,1) < 3
        G = localEmptyMetrics();
        return;
    end
    % Keep the planning path in map coordinates. NAV_RFLY_cleanXYZ is a
    % flight-log normalization helper that translates the first point to
    % the origin; applying it here corrupts terrain/threat coordinates.
    xyz = localCleanWithoutTranslation(xyz);
    seg = diff(xyz,1,1);
    L = sqrt(sum(seg.^2,2));
    h = sqrt(sum(seg(:,1:2).^2,2));
    climb = abs(atan2d(seg(:,3), max(h, eps)));
    turn = localTurnAngles(xyz);
    if numel(L) >= 2 && ~isempty(turn)
        curv = (turn(:) * pi/180) ./ max(0.5*(L(1:end-1)+L(2:end)), eps);
    else
        curv = NaN;
    end
    G = struct();
    G.XYZ = xyz;
    G.CoordinateFrame = 'meter_absolute';
    G.Path = pathMeta;
    G.NumPoints = size(xyz,1);
    G.PathLength = sum(L,'omitnan');
    G.PathLengthM = G.PathLength;
    G.MeanTurn = localMean(turn);
    G.P95Turn = localPrctile(turn,95);
    G.MaxTurn = localMax(turn);
    G.MeanClimb = localMean(climb);
    G.P95Climb = localPrctile(climb,95);
    G.MaxClimb = localMax(climb);
    G.MeanCurvature = localMean(curv);
    G.P95Curvature = localPrctile(curv,95);
    G.MaxCurvature = localMax(curv);
    G.TurnSmoothness = localMean(abs(diff(turn)));

    turnSoft = localGet(params,'TurnSoftLimitDeg',30);
    climbSoft = localGet(params,'ClimbSoftLimitDeg',15);
    curvSoft = localGet(params,'CurvatureSoftLimit',0.016);
    smoothSoft = localGet(params,'SmoothnessSoftLimit',0.28);
    G.TurnViolation = max(0, G.P95Turn - turnSoft) / max(turnSoft, eps);
    G.ClimbViolation = max(0, G.P95Climb - climbSoft) / max(climbSoft, eps);
    G.CurvatureViolation = max(0, G.P95Curvature - curvSoft) / max(curvSoft, eps);
    G.SmoothnessViolation = max(0, G.TurnSmoothness - smoothSoft) / max(smoothSoft, eps);
    G.RiskViolation = localCostViolation(candidate, 2);
    G.AltitudeViolation = localCostViolation(candidate, 3);
    G.EnvelopeViolation = G.TurnViolation + G.ClimbViolation + G.CurvatureViolation + G.SmoothnessViolation;
    G.Score = NAV_FEC_GeometryScore(G);
end

function xyz = localCleanWithoutTranslation(xyz)
    xyz = double(xyz);
    xyz = xyz(all(isfinite(xyz),2),:);
    if isempty(xyz), return; end
    distance = [Inf; sqrt(sum(diff(xyz,1,1).^2,2))];
    xyz = xyz(distance > 1e-7,:);
end

function score = NAV_FEC_GeometryScore(G)
% This nested public-style helper is intentionally duplicated as a subfunction.
    score = 0.26*G.MeanTurn + 0.32*G.P95Turn + ...
            3600*G.MeanCurvature + 2400*G.P95Curvature + ...
            12.0*G.TurnSmoothness + 3.5*G.MeanClimb + 2.0*G.P95Climb + ...
            20.0*G.RiskViolation + 8.0*G.AltitudeViolation + 6.0*G.EnvelopeViolation;
end

function [xyz,pathMeta] = localExtractXYZ(candidate, model)
    xyz = [];
    pathMeta = struct();
    if nargin < 2, model = []; end
    if isempty(candidate), return; end
    if isnumeric(candidate) && ismatrix(candidate)
        if ~isempty(model)
            try
                pathMeta = NAV_ConvertPath(candidate,model);
                xyz = pathMeta.AbsoluteM; return;
            catch
            end
        end
        if size(candidate,2)==3 && size(candidate,1)>=3, xyz = double(candidate); return; end
        if size(candidate,1)==3 && size(candidate,2)>=3, xyz = double(candidate'); return; end
    end
    if ~isstruct(candidate), return; end
    if isfield(candidate,'Position') && isstruct(candidate.Position) && isfield(candidate.Position,'r') && ~isempty(model)
        try
            pathMeta = NAV_ConvertPath(candidate.Position,model);
            xyz = pathMeta.AbsoluteM; return;
        catch
        end
    end
    if isfield(candidate,'r') && isfield(candidate,'phi') && isfield(candidate,'psi') && ~isempty(model)
        try
            pathMeta = NAV_ConvertPath(candidate,model);
            xyz = pathMeta.AbsoluteM; return;
        catch
        end
    end
    [ok,x,y,z] = localStructXYZ(candidate);
    if ok
        if ~isempty(model)
            try
                pathMeta = NAV_ConvertPath(struct('x',x,'y',y,'z',z),model);
                xyz = pathMeta.AbsoluteM; return;
            catch
            end
        end
        xyz = [x(:),y(:),z(:)]; return;
    end
    subs = {'Sol','sol','Path','path','Best','best'};
    for i=1:numel(subs)
        if isfield(candidate,subs{i})
            [xyz,pathMeta] = localExtractXYZ(candidate.(subs{i}), model);
            if ~isempty(xyz), return; end
        end
    end
end

function [ok,x,y,z] = localStructXYZ(A)
    ok=false; x=[]; y=[]; z=[];
    if ~isstruct(A), return; end
    fn=fieldnames(A); norm=lower(regexprep(string(fn),'[^a-zA-Z0-9]',''));
    xi=find(norm=="x" | norm=="xs" | norm=="xcoord" | norm=="xcoords",1);
    yi=find(norm=="y" | norm=="ys" | norm=="ycoord" | norm=="ycoords",1);
    zi=find(norm=="z" | norm=="zs" | norm=="zcoord" | norm=="zcoords" | norm=="alt" | norm=="height",1);
    if ~isempty(xi)&&~isempty(yi)&&~isempty(zi)
        try
            x=double(A.(fn{xi})); y=double(A.(fn{yi})); z=double(A.(fn{zi}));
            ok = numel(x)==numel(y) && numel(y)==numel(z) && numel(x)>=3;
        catch
            ok=false; x=[]; y=[]; z=[];
        end
    end
end

function turn = localTurnAngles(P)
    if exist('NAV_RFLY_turnAngles','file') == 2
        turn = NAV_RFLY_turnAngles(P); return;
    end
    if size(P,1) < 3, turn = NaN; return; end
    A = diff(P,1,1);
    turn = nan(size(A,1)-1,1);
    for i=1:numel(turn)
        a=A(i,:); b=A(i+1,:);
        na=norm(a); nb=norm(b);
        if na<eps || nb<eps, continue; end
        c=max(-1,min(1,dot(a,b)/(na*nb)));
        turn(i)=acosd(c);
    end
end

function G = localEmptyMetrics()
    G = struct('XYZ',[],'CoordinateFrame','meter_absolute','Path',struct(),'NumPoints',0,'PathLength',NaN,'PathLengthM',NaN,'MeanTurn',NaN,'P95Turn',NaN,'MaxTurn',NaN, ...
        'MeanClimb',NaN,'P95Climb',NaN,'MaxClimb',NaN,'MeanCurvature',NaN,'P95Curvature',NaN, ...
        'MaxCurvature',NaN,'TurnSmoothness',NaN,'TurnViolation',Inf,'ClimbViolation',Inf, ...
        'CurvatureViolation',Inf,'SmoothnessViolation',Inf,'RiskViolation',Inf,'AltitudeViolation',Inf, ...
        'EnvelopeViolation',Inf,'Score',Inf);
end

function v = localCostViolation(candidate, idx)
    v = 0;
    try
        if isstruct(candidate) && isfield(candidate,'Cost') && numel(candidate.Cost)>=idx
            c = candidate.Cost(idx);
            if ~isfinite(c), v = Inf; else, v = max(0,c); end
        end
    catch
        v = Inf;
    end
end
function v=localGet(s,f,d), if isfield(s,f)&&~isempty(s.(f)), v=s.(f); else, v=d; end, end
function v=localMean(x), x=x(isfinite(x)); if isempty(x), v=NaN; else, v=mean(x); end, end
function v=localMax(x), x=x(isfinite(x)); if isempty(x), v=NaN; else, v=max(x); end, end
function v=localPrctile(x,p), x=x(isfinite(x)); if isempty(x), v=NaN; else, v=prctile(x,p); end, end
