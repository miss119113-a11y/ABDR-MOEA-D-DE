function [VarMin, VarMax, meta] = NAV_NavigationBounds(model)
%NAV_NAVIGATIONBOUNDS Frozen metre-scale navigation-variable bounds.
%   r is measured in metres. phi and psi remain angular increments in
%   radians. x/y fields are retained as grid-index compatibility metadata;
%   they are not optimized directly by the spherical encoding.

pixelSizeM = localGet(model, 'PixelSizeM', 5);
nVar = double(model.n);
if ~isscalar(nVar) || nVar < 1
    error('NAV:InvalidNavigationModel', 'model.n must be a positive scalar.');
end

legacyMode = localLegacyMode();
if legacyMode
    % Explicitly isolated compatibility mode for reproducing old result
    % packs. New/frozen experiments must never use this branch.
    startM = double(model.start(:));
    goalM = double(model.end(:));
    coordinateFrame = 'legacy_mixed_grid_xy_metre_z';
else
    startM = [(double(model.start(1))-1)*pixelSizeM; ...
              (double(model.start(2))-1)*pixelSizeM; ...
               double(model.start(3))];
    goalM = [(double(model.end(1))-1)*pixelSizeM; ...
             (double(model.end(2))-1)*pixelSizeM; ...
              double(model.end(3))];
    coordinateFrame = 'metre_relative';
end
directDistanceM = norm(goalM-startM);

VarMin.x = model.xmin; VarMax.x = model.xmax;
VarMin.y = model.ymin; VarMax.y = model.ymax;
VarMin.z = model.zmin; VarMax.z = model.zmax;
VarMax.r = 3*directDistanceM/nVar;
VarMin.r = VarMax.r/9;
angleRange = pi/4;
VarMin.psi = -angleRange; VarMax.psi = angleRange;
VarMin.phi = -angleRange; VarMax.phi = angleRange;

if nargout > 2
    meta = struct('PixelSizeM',pixelSizeM, 'CoordinateFrame',coordinateFrame, ...
        'StartRelativeM',startM(:)', 'GoalRelativeM',goalM(:)', ...
        'DirectDistanceM',directDistanceM, ...
        'MinSegmentLengthM',VarMin.r, ...
        'MaxSegmentLengthM',VarMax.r, ...
        'MaxTurnDeg',localGet(model,'MaxTurnDeg',45), ...
        'MaxClimbDeg',localGet(model,'MaxClimbDeg',45));
end

function tf = localLegacyMode()
mode='';
try
    if isappdata(0,'NAV_COST_MODE'), mode=char(string(getappdata(0,'NAV_COST_MODE'))); end
catch
end
if isempty(strtrim(mode))
    try, mode=getenv('NAV_COST_MODE'); catch, mode=''; end
end
tf=ismember(lower(strtrim(mode)),{'legacy','original','grid'});
end
end

function v = localGet(s, name, defaultValue)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    v = double(s.(name));
else
    v = defaultValue;
end
end