function cfg = NAV_ConfigureExactSearchFE(cfg)
%NAV_CONFIGUREEXACTSEARCHFE Apply the frozen exact-2000 search-FE protocol.
%   CFG = NAV_CONFIGUREEXACTSEARCHFE(CFG) preserves the caller's experiment
%   configuration and existing per-method overrides, then installs:
%
%     FELimit              = 2000
%     RequireExactSearchFE = true
%     BudgetProtocol       = 'SEARCH-FE-EXACT-2000-V1'
%
%   The retained PDMOEA/D family and one-offspring framework comparators use
%   MaxIt=83 for the historical nPop=24 protocol. MOEA/D-DE keeps the
%   frozen MaxIt=52 schedule associated with its historical paper label.
%   Traditional baselines are not modified. Existing override fields are
%   retained.

if nargin < 1 || isempty(cfg) || ~isstruct(cfg) || ~isscalar(cfg)
    error('NAV:ExactSearchFEConfig', ...
        'A scalar experiment configuration struct is required.');
end
if ~isfield(cfg,'Methods') || isempty(cfg.Methods)
    error('NAV:ExactSearchFEMethods', ...
        'cfg.Methods is required by the exact search-FE configurator.');
end

if ~isfield(cfg,'ParamOverrides') || isempty(cfg.ParamOverrides)
    overrides = struct();
elseif isstruct(cfg.ParamOverrides) && isscalar(cfg.ParamOverrides)
    overrides = cfg.ParamOverrides;
else
    error('NAV:ExactSearchFEOverrides', ...
        'cfg.ParamOverrides must be an empty value or a scalar struct.');
end

methods = reshape(string(cfg.Methods),1,[]);
for i = 1:numel(methods)
    method = strtrim(char(methods(i)));
    key = upper(method);
    if strcmp(key,'MOEA/D-DE')
        % MOEA/D-DE is the paper rename of the frozen E01 method originally
        % labelled MOEA/D.  Preserve its original FINAL-MO MaxIt=52.
        maxIt = 52;
    elseif ismember(key,{'PDMOEA/D','MOEA/D-AWA','MOEA-2DE'}) || ...
            startsWith(key,'PBA-DQRF-DIVERSE-DFE')
        % These retained population algorithms evaluate one offspring per
        % member; nPop=24 reaches Exact-2000 during iteration 83.
        maxIt = 83;
    else
        continue;
    end

    field = matlab.lang.makeValidName(method);
    if isfield(overrides,field)
        methodOverride = overrides.(field);
        if isempty(methodOverride)
            methodOverride = struct();
        elseif ~isstruct(methodOverride) || ~isscalar(methodOverride)
            error('NAV:ExactSearchFEMethodOverride', ...
                'ParamOverrides.%s must be an empty value or scalar struct.',field);
        end
    else
        methodOverride = struct();
    end
    methodOverride.MaxIt = maxIt;
    overrides.(field) = methodOverride;
end

cfg.FELimit = 2000;
cfg.RequireExactSearchFE = true;
cfg.BudgetProtocol = 'SEARCH-FE-EXACT-2000-V1';
cfg.ParamOverrides = overrides;
end
