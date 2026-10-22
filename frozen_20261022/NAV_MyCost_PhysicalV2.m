function [cost, info] = NAV_MyCost_PhysicalV2(sol, model, varmin, opts)
%NAV_MYCOST_PHYSICALV2 NMOPSO-aligned four-objective physical evaluator.
%   F1-F4 follow Eqs. (3)-(9) of Duong et al. (2025): path efficiency,
%   the equal mean over every threat-segment pair, relative-height deviation,
%   and mean normalized 3-D turn angle. NAV_ConvertPath supplies the common
%   metre-scale geometry. Additional decoded-path checks are shared hard
%   feasibility constraints; they do not redefine the four objectives.

if nargin < 3 || isempty(varmin)
    varmin = struct();
end
if nargin < 4 || isempty(opts)
    opts = struct();
end

pixelSizeM = localGet(opts, 'PixelSizeM', localGet(model, 'PixelSizeM', 5));
droneSizeM = localGet(opts, 'DroneSizeM', localGet(model, 'DroneSizeM', pixelSizeM));
safetyDistM = localGet(opts, 'SafetyDistM', localGet(model, 'SafetyDistM', 10 * pixelSizeM));
collisionPenalty = localGet(opts, 'CollisionPenalty', inf);

n = model.n;
path = NAV_ConvertPath(sol,model);
qM = path.AbsoluteM;
xM = qM(:,1)';
yM = qM(:,2)';
zRel = path.MiddleRelativeM(:,3)';
zRelAll = path.RelativeM(:,3)';
ground = path.GroundM(:)';
N = size(qM,1);

segLen = sqrt(sum(diff(qM, 1, 1).^2, 2));
pathLen = sum(segLen);
straightLen = norm(qM(end,:) - qM(1,:));
J1 = 1 - straightLen / max(pathLen,eps);

if isfield(opts,'FastThreatEvaluation') && ...
        logical(opts.FastThreatEvaluation)
    [J2, riskInfo] = localThreatCostVectorized(model.threats, xM, yM, ...
        pixelSizeM, droneSizeM, safetyDistM, collisionPenalty);
else
    [J2, riskInfo] = localThreatCost(model.threats, xM, yM, pixelSizeM, ...
        droneSizeM, safetyDistM, collisionPenalty);
end

zmax = double(model.zmax);
zmin = double(model.zmin);
href = (zmax + zmin) / 2;
if n == 0 || isempty(zRel)
    J3 = 0;
else
    zNodes = zRel(1:min(n, numel(zRel)));
    if any(zNodes < zmin | zNodes > zmax)
        J3 = inf;
    else
        J3 = mean(abs(zNodes - href) ./ max((zmax - zmin) / 2, eps));
    end
end

if N < 3
    J4 = 0;
else
    angles = nan(N - 2, 1);
    for i = 1:N-2
        v1 = qM(i+1,:) - qM(i,:);
        v2 = qM(i+2,:) - qM(i+1,:);
        if norm(v1) <= eps || norm(v2) <= eps
            angles(i) = 0;
        else
            angles(i) = atan2(norm(cross(v1, v2)), dot(v1, v2)) / pi;
        end
    end
    J4 = mean(abs(angles), 'omitnan');
end

validationOpts=opts;
validationOpts.PrecomputedThreatCollision=struct( ...
    'MinCollisionMarginM',riskInfo.MinCollisionMarginM, ...
    'CollisionSegmentCount',riskInfo.CollisionPathSegmentCount);
feasibility = NAV_ValidatePhysicalPath(path,model,varmin,validationOpts);
if feasibility.IsFeasible
    cost = [J1; J2; J3; J4];
else
    % Deb-style feasibility ordering encoded without adding a fifth search
    % objective. Feasible objectives remain unchanged in [0,1]. Every
    % infeasible path receives the same value >1 in all four components;
    % lower aggregate violation therefore dominates higher violation.
    constraintViolation = localConstraintViolation(path,feasibility,model,droneSizeM,safetyDistM);
    cost = repmat(1 + constraintViolation,4,1);
end

if nargout > 1
    info = riskInfo;
    info.Mode = 'physical_nmopso_objectives_metre_v4';
    info.Path = path;
    info.Feasibility = feasibility;
    info.IsFeasible = feasibility.IsFeasible;
    info.FailureReasons = feasibility.FailureReasons;
    info.PixelSizeM = pixelSizeM;
    info.PathLengthM = pathLen;
    info.StraightLengthM = straightLen;
    info.MinRelativeClearanceM = min(zRelAll);
    info.MinGroundM = min(ground);
    info.MaxGroundM = max(ground);
    info.MeanSegmentLengthM = mean(segLen, 'omitnan');
    info.MinSegmentLengthM = min(segLen,[],'omitnan');
    info.MaxTurnDeg = feasibility.MaxTurnDeg;
    info.MaxClimbDeg = feasibility.MaxClimbDeg;
    info.MinTerrainClearanceM = feasibility.MinTerrainClearanceM;
    info.MinCollisionMarginM = feasibility.MinCollisionMarginM;
    info.RawObjectives = [J1; J2; J3; J4];
    if feasibility.IsFeasible
        info.ConstraintViolation = 0;
    else
        info.ConstraintViolation = cost(1)-1;
    end
end
end

function cv = localConstraintViolation(path,V,model,droneSizeM,safetyDistM)
cv = 0;
z = double(path.RelativeM(:,3));
zmin = double(model.zmin); zmax = double(model.zmax);
zspan = max(zmax-zmin,eps);
cv = cv + sum(max(0,zmin-z)./zspan) + sum(max(0,z-zmax)./zspan);

requiredSegment = max(double(V.RequiredMinSegmentLengthM),eps);
if ~isempty(V.SegmentLengthM)
    cv = cv + sum(max(0,requiredSegment-double(V.SegmentLengthM))./requiredSegment);
end
if ~isempty(V.ClimbDeg)
    cv = cv + sum(max(0,double(V.ClimbDeg)-double(V.AllowedMaxClimbDeg)) ./ ...
        max(double(V.AllowedMaxClimbDeg),eps));
end
if ~isempty(V.TurnDeg)
    cv = cv + sum(max(0,double(V.TurnDeg)-double(V.AllowedMaxTurnDeg)) ./ ...
        max(double(V.AllowedMaxTurnDeg),eps));
end
if V.TerrainCheckPerformed && isfinite(V.MinTerrainClearanceM)
    cv = cv + max(0,double(V.RequiredMinTerrainClearanceM)-double(V.MinTerrainClearanceM)) ./ ...
        max(double(V.RequiredMinTerrainClearanceM),eps);
end
if isfinite(V.MinCollisionMarginM)
    cv = cv + max(0,-double(V.MinCollisionMarginM)) ./ ...
        max(droneSizeM+safetyDistM,eps);
end
if ~isfinite(cv) || cv<=1e-12
    cv = 1e-6;
end
end

function [J2, info] = localThreatCost(threats, xM, yM, pixelSizeM, droneSizeM, safetyDistM, collisionPenalty)
N = numel(xM);
if isempty(threats) || N < 2
    J2 = 0;
    info = localThreatInfo();
    return;
end

pairCostSum = 0;
pairCount = 0;
hasCollision = false;
minCollisionMargin = inf;
minSafetyMargin = inf;
softSegmentCount = 0;
collisionSegmentCount = 0;
collisionPathSegments = false(1,max(0,N-1));

for k = 1:size(threats, 1)
    for j = 1:N-1
        c = [(double(threats(k,1)) - 1) * pixelSizeM, ...
             (double(threats(k,2)) - 1) * pixelSizeM];
        radiusM = double(threats(k,4)) * pixelSizeM;
        a = [xM(j), yM(j)];
        b = [xM(j+1), yM(j+1)];
        dist = localDistPointSegment(c, a, b);
        collisionMargin = dist - (radiusM + droneSizeM);
        safetyMargin = dist - (radiusM + droneSizeM + safetyDistM);
        minCollisionMargin = min(minCollisionMargin, collisionMargin);
        minSafetyMargin = min(minSafetyMargin, safetyMargin);
        if collisionMargin <= 0
            threatCost = collisionPenalty;
            hasCollision = true;
            collisionSegmentCount = collisionSegmentCount + 1;
            collisionPathSegments(j) = true;
        elseif safetyMargin < 0
            threatCost = 1 - collisionMargin / max(safetyDistM, eps);
            softSegmentCount = softSegmentCount + 1;
        else
            threatCost = 0;
        end
        pairCostSum = pairCostSum + threatCost;
        pairCount = pairCount + 1;
    end
end

if pairCount == 0
    J2 = inf;
else
    J2 = pairCostSum / pairCount;
end

info = localThreatInfo();
info.HasPhysicalCollision = hasCollision;
info.MinCollisionMarginM = minCollisionMargin;
info.MinSafetyMarginM = minSafetyMargin;
info.SoftThreatSegmentCount = softSegmentCount;
info.CollisionSegmentCount = collisionSegmentCount;
info.CollisionPathSegmentCount = sum(collisionPathSegments);
info.ThreatSegmentPairCount = pairCount;
info.ThreatAggregation = 'nmopso_equal_pair_mean';
end

function [J2, info] = localThreatCostVectorized(threats, xM, yM, pixelSizeM, ...
        droneSizeM, safetyDistM, collisionPenalty)
%LOCALTHREATCOSTVECTORIZED Exact matrix form of the scalar threat loop.
%   Rows are threats and columns are path segments. The degenerate-segment
%   branch is kept explicitly so the geometric result matches the scalar
%   point-to-segment implementation, while implicit expansion removes the
%   nested MATLAB loops from every FE.
N = numel(xM);
K = size(threats,1);
S = max(0,N-1);
if isempty(threats) || S==0
    J2 = 0;
    info = localThreatInfo();
    return;
end

cx = (double(threats(:,1))-1)*pixelSizeM;
cy = (double(threats(:,2))-1)*pixelSizeM;
radius = double(threats(:,4))*pixelSizeM;
x0 = double(xM(1:end-1));
y0 = double(yM(1:end-1));
dx = double(xM(2:end))-x0;
dy = double(yM(2:end))-y0;
den = dx.^2 + dy.^2;

apx = cx - x0;
apy = cy - y0;
t = (apx.*dx + apy.*dy) ./ max(den,eps);
t(:,den<=eps) = 0;
t = min(1,max(0,t));
projX = x0 + t.*dx;
projY = y0 + t.*dy;
dist = hypot(cx-projX,cy-projY);

collisionMargin = dist - (radius + droneSizeM);
safetyMargin = collisionMargin - safetyDistM;
collision = collisionMargin <= 0;
soft = ~collision & safetyMargin < 0;
softCost = 1 - collisionMargin(soft) ./ max(safetyDistM,eps);
collisionCount = nnz(collision);
if collisionCount == 0
    pairCostSum = sum(softCost,'all');
elseif isinf(collisionPenalty)
    pairCostSum = inf;
else
    pairCostSum = sum(softCost,'all') + collisionCount*collisionPenalty;
end
pairCount = K*S;
J2 = pairCostSum / pairCount;

info = localThreatInfo();
info.HasPhysicalCollision = any(collision,'all');
info.MinCollisionMarginM = min(collisionMargin,[],'all');
info.MinSafetyMarginM = min(safetyMargin,[],'all');
info.SoftThreatSegmentCount = nnz(soft);
info.CollisionSegmentCount = nnz(collision);
info.CollisionPathSegmentCount = nnz(any(collision,1));
info.ThreatSegmentPairCount = pairCount;
info.ThreatAggregation = 'nmopso_equal_pair_mean';
end

function info = localThreatInfo()
info = struct('HasPhysicalCollision', false, ...
    'MinCollisionMarginM', inf, ...
    'MinSafetyMarginM', inf, ...
    'SoftThreatSegmentCount', 0, ...
    'CollisionSegmentCount', 0, ...
    'CollisionPathSegmentCount', 0, ...
    'ThreatSegmentPairCount', 0, ...
    'ThreatAggregation', 'nmopso_equal_pair_mean');
end

function d = localDistPointSegment(p, a, b)
ab = b - a;
den = dot(ab, ab);
if den <= eps
    d = norm(p - a);
    return;
end
t = dot(p - a, ab) / den;
t = min(max(t, 0), 1);
proj = a + t * ab;
d = norm(p - proj);
end

function v = localGet(s, name, defaultValue)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defaultValue;
end
end
