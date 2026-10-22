function params = NAV_DefaultParams(params)
% Shared defaults for navigation-variable UAV optimizers.
    if nargin < 1
        params = struct();
    end

    defaults.MaxIt = 100;
    defaults.nPop = 60;
    defaults.nRep = 50;
    defaults.nGrid = 7;
    defaults.alpha = 0.1;
    defaults.beta = 2;
    defaults.gamma = 2;
    defaults.verbose = false;

    defaults.riskEps0 = 0.02;
    defaults.riskEpsFinal = 1e-10;
    defaults.reportWeights = [0.40 0.25 0.10 0.25];

    defaults.guidedInitRatio = 0.45;
    defaults.initMaxTry = 80;
    defaults.guidedAngleStd = 0.08;

    defaults.repairProb = 0.70;
    defaults.repairTries = 4;
    defaults.contractRate = 0.28;
    defaults.smoothRate = 0.22;
    defaults.jitterScale = 0.025;
    defaults.f1Tolerance = 0.06;
    defaults.f3Tolerance = 0.80;
    defaults.f4Tolerance = 0.08;

    defaults.Fmin = 0.35;
    defaults.Fmax = 0.78;
    defaults.CRmin = 0.55;
    defaults.CRmax = 0.95;
    if isfield(params, 'T') && ~isempty(params.T)
        defaults.neighborSize = params.T;
    elseif isfield(params, 'neighborSize') && ~isempty(params.neighborSize)
        defaults.neighborSize = params.neighborSize;
    else
        defaults.neighborSize = 6; % Frozen BIDR default neighborhood T=6
    end
    defaults.neighborSelectProb = 0.90;
    defaults.maxReplace = 2;

    defaults.rimeExploreProb = 0.40;
    defaults.rimeSoftProb = 0.70;
    defaults.rimeMutationProb = 0.25;

    defaults.crossoverProb = 0.9;
    defaults.mutationProb = 0.25;
    defaults.mutationScale = 0.08;

    if isfield(params, 'ControllerAlphaP') && ~isempty(params.ControllerAlphaP)
        defaults.ControllerAlphaP = params.ControllerAlphaP;
        defaults.CustomAlphaP = params.ControllerAlphaP;
    elseif isfield(params, 'CustomAlphaP') && ~isempty(params.CustomAlphaP)
        defaults.ControllerAlphaP = params.CustomAlphaP;
        defaults.CustomAlphaP = params.CustomAlphaP;
    else
        defaults.ControllerAlphaP = 0.25;
        defaults.CustomAlphaP = 0.25;
    end
    defaults.ControllerPMin = 0.05;

    names = fieldnames(defaults);
    for k = 1:numel(names)
        if ~isfield(params, names{k})
            params.(names{k}) = defaults.(names{k});
        end
    end
end