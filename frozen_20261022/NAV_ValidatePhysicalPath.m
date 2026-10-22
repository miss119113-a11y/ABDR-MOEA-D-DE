function V = NAV_ValidatePhysicalPath(path, model, varmin, opts)
%NAV_VALIDATEPHYSICALPATH Frozen hard-feasibility checks in physical units.
%   The terrain clearance extremum is evaluated exactly for the piecewise
%   bilinear DEM surface along every straight 3-D path segment: each segment
%   is split at grid-cell boundaries and the quadratic clearance inside each
%   cell is minimized analytically.

if nargin < 3 || isempty(varmin), varmin = struct(); end
if nargin < 4 || isempty(opts), opts = struct(); end
if ~isstruct(path) || ~isfield(path,'AbsoluteM') || ~isfield(path,'RelativeM')
    path = NAV_ConvertPath(path,model);
end

pixelSizeM = localGet(opts,'PixelSizeM',localGet(model,'PixelSizeM',5));
minSegmentM = localGet(opts,'MinSegmentLengthM',localGet(varmin,'r',NaN));
if ~isfinite(minSegmentM)
    [boundsMin,~] = NAV_NavigationBounds(model);
    minSegmentM = boundsMin.r;
end
maxTurnDeg = localGet(opts,'MaxTurnDeg',localGet(model,'MaxTurnDeg',45));
maxClimbDeg = localGet(opts,'MaxClimbDeg',localGet(model,'MaxClimbDeg',45));
minClearanceM = localGet(opts,'MinTerrainClearanceM',double(model.zmin));
droneSizeM = localGet(opts,'DroneSizeM',localGet(model,'DroneSizeM',1));
tolerance = localGet(opts,'Tolerance',1e-8);

P = double(path.AbsoluteM);
seg = diff(P,1,1);
segmentLengthM = sqrt(sum(seg.^2,2));
horizontalLengthM = sqrt(sum(seg(:,1:2).^2,2));
climbDeg = abs(atan2d(seg(:,3),horizontalLengthM));
turnDeg = localHorizontalTurnAngles(seg(:,1:2));

precomputedThreat=localGetStruct(opts,'PrecomputedThreatCollision',struct());
if isfield(precomputedThreat,'MinCollisionMarginM') && ...
        isfield(precomputedThreat,'CollisionSegmentCount')
    minCollisionMarginM=double(precomputedThreat.MinCollisionMarginM);
    collisionSegments=double(precomputedThreat.CollisionSegmentCount);
else
    [minCollisionMarginM,collisionSegments] = ...
        localThreatCollisionMargin(P(:,1:2),model.threats,pixelSizeM,droneSizeM);
end

relativeNodes = double(path.RelativeM(:,3));
altitudeBoundsOK = all(relativeNodes >= double(model.zmin)-tolerance & ...
    relativeNodes <= double(model.zmax)+tolerance);
segmentLengthOK = ~isempty(segmentLengthM) && all(segmentLengthM >= minSegmentM-tolerance);
climbOK = isempty(climbDeg) || all(climbDeg <= maxClimbDeg+tolerance);
turnOK = isempty(turnDeg) || all(turnDeg <= maxTurnDeg+tolerance);
collisionOK = isinf(minCollisionMarginM) || minCollisionMarginM > tolerance;
terrainCheckPerformed = altitudeBoundsOK && segmentLengthOK && climbOK && turnOK && collisionOK;
if terrainCheckPerformed
    if logical(localGet(opts,'FastTerrainValidation',false))
        fastStepM=localGet(opts,'FastTerrainStepM',pixelSizeM);
        [minTerrainClearanceM,maxTerrainClearanceM] = ...
            localSampledTerrainExtrema(P,model.H,pixelSizeM,fastStepM);
    else
        [minTerrainClearanceM,maxTerrainClearanceM] = ...
            localContinuousTerrainExtrema(P,model.H,pixelSizeM);
    end
    terrainOK = isfinite(minTerrainClearanceM) && minTerrainClearanceM >= minClearanceM-tolerance;
else
    % The path is already hard-infeasible. Avoid the expensive exact DEM
    % extremum audit, while keeping the earlier failure reason explicit.
    minTerrainClearanceM = NaN;
    maxTerrainClearanceM = NaN;
    terrainOK = true;
end

V = struct();
V.IsFeasible = altitudeBoundsOK && segmentLengthOK && climbOK && turnOK && terrainOK && collisionOK;
V.AltitudeBoundsOK = altitudeBoundsOK;
V.SegmentLengthOK = segmentLengthOK;
V.ClimbOK = climbOK;
V.TurnOK = turnOK;
V.TerrainClearanceOK = terrainOK;
V.TerrainCheckPerformed = terrainCheckPerformed;
V.CollisionFree = collisionOK;
V.SegmentLengthM = segmentLengthM;
V.MinSegmentLengthM = localMin(segmentLengthM);
V.RequiredMinSegmentLengthM = minSegmentM;
V.ClimbDeg = climbDeg;
V.MaxClimbDeg = localMax(climbDeg);
V.AllowedMaxClimbDeg = maxClimbDeg;
V.TurnDeg = turnDeg;
V.MaxTurnDeg = localMax(turnDeg);
V.AllowedMaxTurnDeg = maxTurnDeg;
V.MinTerrainClearanceM = minTerrainClearanceM;
V.MaxTerrainClearanceM = maxTerrainClearanceM;
V.RequiredMinTerrainClearanceM = minClearanceM;
V.MinCollisionMarginM = minCollisionMarginM;
V.CollisionSegmentCount = collisionSegments;
V.DroneSizeM = droneSizeM;
V.FastTerrainValidation = logical(localGet(opts,'FastTerrainValidation',false));
V.FailureReasons = localFailureReasons(V);
end

function [minimumClearance,maximumClearance]=localSampledTerrainExtrema(P,H,pixelSizeM,stepM)
minimumClearance=inf; maximumClearance=-inf;
stepM=max(double(stepM),pixelSizeM);
for i=1:size(P,1)-1
    a=P(i,:); b=P(i+1,:); n=max(1,ceil(norm(b-a)/stepM));
    t=(0:n)'/n;
    clearance=localClearance(a,b,t,H,pixelSizeM);
    minimumClearance=min(minimumClearance,min(clearance));
    maximumClearance=max(maximumClearance,max(clearance));
end
end

function turnDeg = localHorizontalTurnAngles(horizontalSegments)
if size(horizontalSegments,1)<2, turnDeg=zeros(0,1); return; end
turnDeg = nan(size(horizontalSegments,1)-1,1);
for i=1:numel(turnDeg)
    a=horizontalSegments(i,:); b=horizontalSegments(i+1,:);
    if norm(a)<=eps || norm(b)<=eps
        turnDeg(i)=180;
    else
        turnDeg(i)=acosd(max(-1,min(1,dot(a,b)/(norm(a)*norm(b)))));
    end
end
end

function [minimumClearance,maximumClearance] = localContinuousTerrainExtrema(P,H,pixelSizeM)
minimumClearance=inf; maximumClearance=-inf;
Hd=double(H);
for i=1:size(P,1)-1
    a=P(i,:); b=P(i+1,:);
    g0=a(1:2)/pixelSizeM+1;
    g1=b(1:2)/pixelSizeM+1;
    t=localCellBoundaryParameters(g0,g1,size(Hd));
    left=t(1:end-1); right=t(2:end); middle=0.5*(left+right);
    nInterval=numel(left);
    sampled=localClearance(a,b,[left;middle;right],Hd,pixelSizeM);
    c0=sampled(1:nInterval);
    cm=sampled(nInterval+(1:nInterval));
    c1=sampled(2*nInterval+(1:nInterval));
    minimumClearance=min([minimumClearance;c0(:);cm(:);c1(:)]);
    maximumClearance=max([maximumClearance;c0(:);cm(:);c1(:)]);
    qa=2*(c1+c0-2*cm);
    qb=c1-c0-qa;
    tau=-qb./(2*qa);
    valid=isfinite(tau) & abs(qa)>1e-12 & tau>0 & tau<1;
    if any(valid)
        % Clearance is quadratic inside each bilinear DEM cell. Evaluate
        % its stationary value from the already computed coefficients
        % instead of performing a fourth terrain interpolation.
        cv=c0(valid)-qb(valid).^2./(4*qa(valid));
        minimumClearance=min(minimumClearance,min(cv));
        maximumClearance=max(maximumClearance,max(cv));
    end
end
end

function t = localCellBoundaryParameters(g0,g1,mapSize)
t=[0;1];
for d=1:2
    lo=max(1,min(g0(d),g1(d)));
    hi=min(mapSize(3-d),max(g0(d),g1(d)));
    boundaries=(floor(lo)+1):(ceil(hi)-1);
    delta=g1(d)-g0(d);
    if abs(delta)>eps && ~isempty(boundaries)
        td=(boundaries(:)-g0(d))/delta;
        t=[t;td(td>0 & td<1)]; %#ok<AGROW>
    end
end
t=sort(t);
if numel(t)>1
    t=t([true;diff(t)~=0]);
end
end

function clearance = localClearance(a,b,t,H,pixelSizeM)
t=t(:);
p=a+t.*(b-a);
gx=min(max(p(:,1)/pixelSizeM+1,1),size(H,2));
gy=min(max(p(:,2)/pixelSizeM+1,1),size(H,1));
% Direct bilinear lookup is mathematically equivalent to interp2(...,
% 'linear') on this regular DEM, but avoids its repeated setup overhead in
% the inner exact-clearance loop.
nx=size(H,2); ny=size(H,1);
x0=floor(gx); y0=floor(gy);
x1=min(x0+1,nx); y1=min(y0+1,ny);
dx=gx-x0; dy=gy-y0;
Hd=double(H);
idx00=y0+(x0-1)*ny;
idx10=y0+(x1-1)*ny;
idx01=y1+(x0-1)*ny;
idx11=y1+(x1-1)*ny;
h00=Hd(idx00);
h10=Hd(idx10);
h01=Hd(idx01);
h11=Hd(idx11);
terrain=(1-dx).*(1-dy).*h00+dx.*(1-dy).*h10+ ...
    (1-dx).*dy.*h01+dx.*dy.*h11;
clearance=p(:,3)-terrain;
end

function [minimumMargin,collisionSegments] = localThreatCollisionMargin(horizontalM,threats,pixelSizeM,droneSizeM)
if isempty(threats), minimumMargin=inf; collisionSegments=0; return; end
minimumMargin=inf; collisionSegments=0;
for j=1:size(horizontalM,1)-1
    segmentCollision=false;
    for k=1:size(threats,1)
        center=(double(threats(k,1:2))-1)*pixelSizeM;
        radius=double(threats(k,4))*pixelSizeM+droneSizeM;
        margin=localPointSegmentDistance(center,horizontalM(j,:),horizontalM(j+1,:))-radius;
        minimumMargin=min(minimumMargin,margin);
        segmentCollision=segmentCollision || margin<=0;
    end
    collisionSegments=collisionSegments+double(segmentCollision);
end
end

function d=localPointSegmentDistance(p,a,b)
ab=b-a; den=dot(ab,ab);
if den<=eps, d=norm(p-a); return; end
t=min(max(dot(p-a,ab)/den,0),1);
d=norm(p-(a+t*ab));
end

function reasons=localFailureReasons(V)
reasons=strings(0,1);
if ~V.AltitudeBoundsOK, reasons(end+1)="relative_altitude_bounds"; end %#ok<AGROW>
if ~V.SegmentLengthOK, reasons(end+1)="minimum_segment_length"; end %#ok<AGROW>
if ~V.ClimbOK, reasons(end+1)="maximum_climb_angle"; end %#ok<AGROW>
if ~V.TurnOK, reasons(end+1)="maximum_turn_angle"; end %#ok<AGROW>
if ~V.TerrainClearanceOK, reasons(end+1)="continuous_terrain_clearance"; end %#ok<AGROW>
if ~V.CollisionFree, reasons(end+1)="cylindrical_threat_collision"; end %#ok<AGROW>
end

function v=localGet(s,name,defaultValue)
if isstruct(s)&&isfield(s,name)&&~isempty(s.(name)), v=double(s.(name)); else, v=defaultValue; end
end
function v=localGetStruct(s,name,defaultValue)
if isstruct(s)&&isfield(s,name)&&isstruct(s.(name)),v=s.(name);else,v=defaultValue;end
end
function v=localMin(x), x=x(isfinite(x)); if isempty(x),v=NaN;else,v=min(x);end,end
function v=localMax(x), x=x(isfinite(x)); if isempty(x),v=NaN;else,v=max(x);end,end