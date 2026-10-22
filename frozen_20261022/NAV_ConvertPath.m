function path = NAV_ConvertPath(solution, model)
%NAV_CONVERTPATH Single frozen conversion pipeline for planning paths.
%
% navigation variables (r in metres)
%   -> metre-scale relative Cartesian waypoints
%   -> DEM-grid coordinates only for lookup/plotting
%   -> metre-scale absolute Cartesian path
%
% The returned arrays include start and goal. Existing Cartesian inputs are
% interpreted as intermediate [grid-x, grid-y, relative-height] waypoints.

if nargin < 2 || ~isstruct(model) || ~isfield(model,'H')
    error('NAV:InvalidPathModel', 'A model containing H, start and end is required.');
end
pixelSizeM = localGet(model,'PixelSizeM',5);

if localIsNavigation(solution)
    middleRelativeM = localDecodeNavigationMetres(solution,model,pixelSizeM);
    sourceType = 'navigation_metre';
elseif isstruct(solution) && all(isfield(solution,{'x','y','z'}))
    middleGrid = [double(solution.x(:)),double(solution.y(:)),double(solution.z(:))];
    middleRelativeM = localGridToRelativeMetres(middleGrid,pixelSizeM);
    sourceType = 'grid_relative';
elseif isnumeric(solution) && ismatrix(solution) && (size(solution,2)==3 || size(solution,1)==3)
    middleGrid = double(solution);
    if size(middleGrid,2) ~= 3, middleGrid = middleGrid'; end
    middleRelativeM = localGridToRelativeMetres(middleGrid,pixelSizeM);
    sourceType = 'grid_relative_numeric';
else
    error('NAV:UnsupportedPathInput', 'Path input must be navigation variables or grid-relative xyz waypoints.');
end

startRelativeM = localGridPointToRelativeMetres(model.start,pixelSizeM);
goalRelativeM = localGridPointToRelativeMetres(model.end,pixelSizeM);
relativeM = [startRelativeM; middleRelativeM; goalRelativeM];
gridRelative = relativeM;
gridRelative(:,1:2) = relativeM(:,1:2)/pixelSizeM + 1;

groundM = localTerrain(model.H,gridRelative(:,1),gridRelative(:,2));
absoluteM = relativeM;
absoluteM(:,3) = relativeM(:,3) + groundM;
gridAbsolute = gridRelative;
gridAbsolute(:,3) = absoluteM(:,3);

path = struct();
path.SourceType = sourceType;
path.PixelSizeM = pixelSizeM;
path.GridRelative = gridRelative;
path.GridAbsolute = gridAbsolute;
path.RelativeM = relativeM;
path.AbsoluteM = absoluteM;
path.GroundM = groundM;
path.MiddleGridRelative = gridRelative(2:end-1,:);
path.MiddleRelativeM = relativeM(2:end-1,:);
path.MiddleAbsoluteM = absoluteM(2:end-1,:);
path.x = path.MiddleGridRelative(:,1)';
path.y = path.MiddleGridRelative(:,2)';
path.z = path.MiddleGridRelative(:,3)';
end

function tf = localIsNavigation(s)
tf = isstruct(s) && all(isfield(s,{'r','phi','psi'}));
end

function middleM = localDecodeNavigationMetres(solution,model,pixelSizeM)
r = double(solution.r(:)');
phi = double(solution.phi(:)');
psi = double(solution.psi(:)');
n = double(model.n);
if numel(r)~=n || numel(phi)~=n || numel(psi)~=n
    error('NAV:NavigationSizeMismatch', 'r, phi and psi must each contain model.n elements.');
end

startM = localGridPointToRelativeMetres(model.start,pixelSizeM);
goalM = localGridPointToRelativeMetres(model.end,pixelSizeM);
direction = goalM-startM;
heading0 = atan2(direction(2),direction(1));
climb0 = atan2(direction(3),norm(direction(1:2)));

start = eye(4);
start(1:3,4) = startM(:);
startPose = start*TransfomationMatrix(0,heading0,climb0);

xBoundsM = ([double(model.xmin),double(model.xmax)]-1)*pixelSizeM;
yBoundsM = ([double(model.ymin),double(model.ymax)]-1)*pixelSizeM;
zBoundsM = [double(model.zmin),double(model.zmax)];
middleM = zeros(n,3);
T = eye(4);
for i=1:n
    T = T*TransfomationMatrix(r(i),phi(i),psi(i));
    pose = startPose*T;
    middleM(i,:) = pose(1:3,4)';
    middleM(i,1) = min(max(middleM(i,1),xBoundsM(1)),xBoundsM(2));
    middleM(i,2) = min(max(middleM(i,2),yBoundsM(1)),yBoundsM(2));
    middleM(i,3) = min(max(middleM(i,3),zBoundsM(1)),zBoundsM(2));
end
end

function pointM = localGridPointToRelativeMetres(point,pixelSizeM)
p = double(point(:)');
if numel(p) ~= 3, error('NAV:InvalidModelPoint','Model points must have three coordinates.'); end
pointM = [(p(1)-1)*pixelSizeM,(p(2)-1)*pixelSizeM,p(3)];
end

function relativeM = localGridToRelativeMetres(gridRelative,pixelSizeM)
if size(gridRelative,2) ~= 3
    error('NAV:InvalidCartesianPath','Cartesian paths must have three columns.');
end
relativeM = double(gridRelative);
relativeM(:,1:2) = (relativeM(:,1:2)-1)*pixelSizeM;
end

function terrain = localTerrain(H,x,y)
x = min(max(double(x),1),size(H,2));
y = min(max(double(y),1),size(H,1));
% Direct regular-grid bilinear interpolation is mathematically identical to
% interp2(...,'linear') here, but avoids rebuilding interpolation machinery
% for every objective evaluation.
Hd = double(H);
ny = size(Hd,1);
nx = size(Hd,2);
x0 = floor(x);
y0 = floor(y);
x1 = min(x0+1,nx);
y1 = min(y0+1,ny);
dx = x-x0;
dy = y-y0;
idx00 = y0+(x0-1)*ny;
idx10 = y0+(x1-1)*ny;
idx01 = y1+(x0-1)*ny;
idx11 = y1+(x1-1)*ny;
h00 = Hd(idx00);
h10 = Hd(idx10);
h01 = Hd(idx01);
h11 = Hd(idx11);
terrain = ((1-dx).*(1-dy).*h00+dx.*(1-dy).*h10+ ...
    (1-dx).*dy.*h01+dx.*dy.*h11);
terrain = terrain(:);
end

function v = localGet(s,name,defaultValue)
if isfield(s,name) && ~isempty(s.(name)), v=double(s.(name)); else, v=defaultValue; end
end