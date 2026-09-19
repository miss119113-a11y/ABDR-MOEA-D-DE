function results = RUN_MAIN_BIMOEAD_EXACT6000(problemFactory)
%RUN_MAIN_BIMOEAD_EXACT6000 Main manuscript experiment for BI-MOEA/D only.
%
% This deliberately excludes all comparison algorithms, ablations, transfer
% terrain studies, runtime batches and PX4/Gazebo experiments.
%
% INPUT
%   problemFactory : function handle. Example:
%       problemFactory = @(scenario,seed) buildProblem(scenario,seed);
%
% The returned problem struct must contain:
%   InitialPopulation : 30-by-d ordered feasible shared initial population
%   EvaluateFcn       : @(x) -> four-objective feasibility-priority vector
%   LB, UB            : 1-by-d bounds
%
% Formal main experiment:
%   S1-S4, 30 independent paired runs, population 30, Exact-6000 FE.

if nargin<1
    error('Provide the project UAV problem factory used by the manuscript.');
end

scenarios = 1:4;
runs = 1:30;
seedBase = 260825000;

rows = cell(numel(scenarios)*numel(runs),1);
p = 0;

for s = scenarios
    for r = runs
        p = p+1;
        seed = seedBase + 100*s + r;
        problem = problemFactory(s,seed);

        params = struct();
        params.Seed = seed;
        params.nPop = 30;
        params.MaxFEs = 6000;
        params.neighborSize = 6;
        params.nRep = 30;
        params.sigmaDE = 0.1;
        params.InitialPopulation = problem.InitialPopulation;
        params.EvaluateFcn = problem.EvaluateFcn;
        params.LB = problem.LB;
        params.UB = problem.UB;

        [archive,best,history] = BI_MOEAD_UAV(params);

        rows{p} = struct( ...
            'Scenario',s, ...
            'Run',r, ...
            'Seed',seed, ...
            'F1',best.F(1), ...
            'F2',best.F(2), ...
            'F3',best.F(3), ...
            'F4',best.F(4), ...
            'C',best.C, ...
            'ArchiveSize',size(archive.F,1), ...
            'FinalFE',history.FE(end));
    end
end

results = struct2table(vertcat(rows{:}));
writetable(results,'BI_MOEAD_MAIN_EXACT6000_results.csv');
end
