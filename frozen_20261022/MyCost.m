function [cost, info] = MyCost(sol, model, varmin)
%MYCOST Standard UAV path cost entry used by all optimizers.
%
% Default mode:
%   physical_v2  - physically consistent meter-scale evaluation.
%
% Reproducibility mode:
%   legacy       - original grid-index evaluator used by earlier result packs.
%
% Mode can be changed without editing algorithms:
%   setappdata(0,'NAV_COST_MODE','legacy')
%   setappdata(0,'NAV_COST_MODE','physical_v2')
%
% or from batch/system environment:
%   NAV_COST_MODE=legacy

mode = localCostMode();

[evaluateNow, attempted, evaluated, limit] = localFECounterBeforeEvaluation();
if ~evaluateNow
    cost = repmat(1e6,4,1);
    if nargout > 1
        info = struct('Mode','fe_limit','IsFeasible',false, ...
            'FEAttempted',attempted,'FEEvaluated',evaluated,'FELimit',limit);
    end
    return;
end

switch lower(mode)
    case {'physical_v2','physical','v2','standard','mainstream'}
        searchOpts = localSearchOptions();
        if nargout > 1
            [cost, info] = NAV_MyCost_PhysicalV2(sol, model, varmin, searchOpts);
        else
            cost = NAV_MyCost_PhysicalV2(sol, model, varmin, searchOpts);
        end
    case {'legacy','original','grid'}
        if isstruct(sol) && all(isfield(sol,{'r','phi','psi'}))
            sol = SphericalToCart2(sol,model);
        end
        cost = NAV_MyCost_Legacy(sol, model, varmin);
        if nargout > 1
            info = struct('Mode', 'legacy');
        end
    otherwise
        error('MyCost:UnknownMode', 'Unknown NAV_COST_MODE: %s', mode);
end

function opts=localSearchOptions()
opts=struct();
try
    if isappdata(0,'NAV_SEARCH_FAST_VALIDATION') && logical(getappdata(0,'NAV_SEARCH_FAST_VALIDATION'))
        opts.FastTerrainValidation=true;
        opts.FastTerrainStepM=5;
    end
    if isappdata(0,'NAV_FAST_THREAT_EVALUATION') && ...
            logical(getappdata(0,'NAV_FAST_THREAT_EVALUATION'))
        opts.FastThreatEvaluation=true;
    end
catch
end
end

function [evaluateNow,attempted,evaluated,limit] = localFECounterBeforeEvaluation()
attempted = 0; evaluated = 0; limit = inf;
try
    if isappdata(0,'NAV_FE_ATTEMPTED'), attempted=double(getappdata(0,'NAV_FE_ATTEMPTED')); end
    if isappdata(0,'NAV_FE_EVALUATED'), evaluated=double(getappdata(0,'NAV_FE_EVALUATED')); end
    if isappdata(0,'NAV_FE_LIMIT'), limit=double(getappdata(0,'NAV_FE_LIMIT')); end
    attempted=attempted+1;
    setappdata(0,'NAV_FE_ATTEMPTED',attempted);
    evaluateNow = evaluated < limit;
    if evaluateNow
        evaluated=evaluated+1;
        setappdata(0,'NAV_FE_EVALUATED',evaluated);
    end
catch
    evaluateNow=true;
end
end
end

function mode = localCostMode()
mode = '';
try
    if isappdata(0, 'NAV_COST_MODE')
        mode = char(string(getappdata(0, 'NAV_COST_MODE')));
    end
catch
    mode = '';
end

if isempty(strtrim(mode))
    try
        mode = getenv('NAV_COST_MODE');
    catch
        mode = '';
    end
end

if isempty(strtrim(mode))
    mode = 'physical_v2';
end
mode = strtrim(mode);
end