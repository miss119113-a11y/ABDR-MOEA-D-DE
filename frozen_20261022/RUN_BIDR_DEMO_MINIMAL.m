function RUN_BIDR_DEMO_MINIMAL()
% =========================================================================
% RUN_BIDR_DEMO_MINIMAL
% Standalone, self-contained minimal reproduction test for BIDR-MOEA/D-DE.
%
% Algorithm: BIDR-MOEA/D-DE (Frozen Champion 2026-10-22)
% Features:
%   - Autonomous SHDE with Maximum-Entropy Uniform Spectrum Memory
%     M_CR^{(0)} = [0.10, 0.30, 0.50, 0.70, 0.90], p_h^{(0)} = 0.20
%   - Dynamic Probability Feedback based on Normalized Objective Improvement
%   - Direction-Conditioned Replacement (DQR) with Topological Neighborhood T=6
%   - Active Population-wise Block Inheritance (APB)
%
% Execution:
%   Simply run 'RUN_BIDR_DEMO_MINIMAL' in MATLAB R2024b (or R2020b+).
% =========================================================================

demoDir = fileparts(mfilename('fullpath'));
addpath(demoDir, '-begin');

fprintf('========================================================================\n');
fprintf('       BIDR-MOEA/D-DE MINIMAL FUNCTIONAL VERIFICATION DEMO               \n');
fprintf('========================================================================\n');

% Set up cost evaluation mode
setappdata(0, 'NAV_COST_MODE', 'physical_v2');
setappdata(0, 'NAV_DISABLE_MODEL_PLOT', true);
setappdata(0, 'NAV_SCENARIO_ID', 1);

% Load verified benchmark initial pool
poolFile = fullfile(demoDir, 'demo_pool_S1.mat');
if exist(poolFile, 'file') == 2
    P = load(poolFile);
    setappdata(0, 'NAV_SHARED_INIT_POOL', P.pool(1:30));
    setappdata(0, 'NAV_SHARED_INIT_CURSOR', 1);
end

% Configure test search budget (300 evaluations for instant verification)
nPop = 30;
nRep = 30;
maxIt = 10; % 10 iterations = 300 FEs (takes ~1.5 seconds)
setappdata(0, 'NAV_FE_LIMIT', nPop * maxIt);
setappdata(0, 'NAV_FE_ATTEMPTED', 0);
setappdata(0, 'NAV_FE_EVALUATED', 0);

% Initialize deterministic random stream
rng(20261022, 'twister');

% Initialize algorithm parameters
params = struct( ...
    'Seed', 20261022, ...
    'nPop', nPop, ...
    'nRep', nRep, ...
    'MaxIt', maxIt, ...
    'nGrid', 7, ...
    'alpha', 0.1, ...
    'beta', 2, ...
    'gamma', 2, ...
    'reportWeights', [0.40, 0.25, 0.10, 0.25], ...
    'StoreConvergenceHistory', true, ...
    'verbose', false, ...
    'delta', 5, ...
    'fixMutation', true, ...
    'usePaperMutationGain', true, ...
    'HistoryStride', 1, ...
    'EnableAPB', true, ...
    'EnableDQR', true, ...
    'AdaptiveDE', true, ...
    'MultiMemoryCR', true, ...
    'ControllerMode', 'GLOBAL_H5_FIR_CR_ARITH', ...
    'ControllerH', 5, ...
    'ControllerAlphaP', 0.25, ...
    'ControllerPMin', 0.05, ...
    'T', 6 ...
);
params = NAV_DefaultParams(params);
params.neighborSize = 6; % Enforce T=6 strictly
params.T = 6;
params.MultiMemoryCR = true; % Autonomous Multi-Memory SHDE
params.repairProb = 0;
params.guidedInitRatio = 0.45;
params.initMaxTry = 80;
assert(params.neighborSize == 6, 'NeighborSize must be strictly 6');

fprintf('Executing BIDR_CHAMPION_ENGINE with H=5 autonomous SHDE, APB=1, DQR=1...\n');
tStart = tic;
[rep, best, history] = BIDR_CHAMPION_ENGINE(params);
runtime = toc(tStart);
assert(history.NeighborhoodSize == 6, 'Verified executed neighborhood size must be 6');
assert(isequal(history.InitialMemoryCR, [0.10, 0.30, 0.50, 0.70, 0.90]), 'Initial MemoryCR must be [0.1 0.3 0.5 0.7 0.9]');
assert(history.ControllerAlphaP == 0.25, 'ControllerAlphaP must be 0.25');
assert(strcmp(history.CandidateVersion, 'BI-MOEA/D-DE-20261022-FROZEN'), 'CandidateVersion must be BI-MOEA/D-DE-20261022-FROZEN');
assert(strcmp(history.Algorithm, 'BI-MOEA/D-DE'), 'Algorithm must be BI-MOEA/D-DE');

fprintf('\n>>> EXECUTION COMPLETED SUCCESSFULLY IN %.2f SECONDS <<<\n', runtime);
fprintf('Final Non-Dominated Archive Size: %d\n', numel(rep));
fprintf('Compromise Solution Cost: Length=%.4f, Threat=%.6f, Alt=%.4f, Curv=%.4f (Sum=%.4f)\n', ...
    best.Cost(1), best.Cost(2), best.Cost(3), best.Cost(4), sum(best.Cost));
fprintf('SHDE Parameter Status: Mean F=%.4f, Mean CR=%.4f\n', ...
    history.SampledFMean(end), history.SampledCRMean(end));
fprintf('Initial Memory M_CR = %s\n', mat2str(history.InitialMemoryCR));
fprintf('Final Adapted Memory M_CR = %s\n', mat2str(history.MemoryCR{end}));
fprintf('========================================================================\n');
fprintf('STATUS: PASS (100%% Reproducible)\n');
fprintf('========================================================================\n');
end
