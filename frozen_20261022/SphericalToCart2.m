function position = SphericalToCart2(solution,model)
%SPHERICALTOCART2 Compatibility wrapper around the frozen physical decoder.
%   Navigation transforms now run entirely in metres. The legacy x/y/z
%   output remains DEM-grid x/y plus metre relative height so older callers
%   continue to work while sharing NAV_ConvertPath as the only decoder.
if localLegacyMode()
    position = NAV_SphericalToCartLegacy(solution,model);
    return;
end
path = NAV_ConvertPath(solution,model);
position.x = path.x;
position.y = path.y;
position.z = path.z;
position.CoordinateFrame = 'grid_relative';
position.PixelSizeM = path.PixelSizeM;
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
