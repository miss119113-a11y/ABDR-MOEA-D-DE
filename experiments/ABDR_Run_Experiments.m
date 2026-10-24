function T = ABDR_Run_Experiments(kind,opts)
%ABDR_RUN_EXPERIMENTS Proposed-method tasks; no comparator source required.
% kind: 'main' (120), 'ablation' (960), 'runtime' (120),
%       'crater' (360), or 'mount' (360) proposed-method tasks.
% Data from this runner require the original shared pools and terrain.
if nargin<1, kind='main'; end
if nargin<2, opts=struct(); end
kind=lower(char(kind));
if ~isfield(opts,'PoolDir') || isempty(opts.PoolDir)
    error('ABDR:PoolRequired','Specify opts.PoolDir for the shared initial pools.');
end
if ~isfield(opts,'OutputDir'),opts.OutputDir=fullfile(pwd,'abdr_results');end
switch kind
    case {'main','runtime','ablation'}
        scenarios=1:4;
    case {'crater','mount'}
        scenarios=[1:4 105:112]; % External terrain scenarios in the supplied paper results.
        if ~isfield(opts,'TerrainFile') || isempty(opts.TerrainFile)
            error('ABDR:TerrainRequired','Specify actual external DEM in opts.TerrainFile.');
        end
    otherwise
        error('ABDR:Kind','Unknown experiment kind %s.',kind);
end
if strcmp(kind,'ablation')
    variants=logical([1 1 1;0 1 1;1 0 1;1 1 0;0 0 1;1 0 0;0 1 0;0 0 0]);
else
    variants=logical([1 1 1]);
end
if strcmp(kind,'runtime'),maxNumCompThreads(1);end
rows=struct([]);
for v=1:size(variants,1)
    for s=scenarios
        for r=1:30
            runOpts=opts;
            runOpts.BI=variants(v,1);
            runOpts.DQR=variants(v,2);
            runOpts.SHDE=variants(v,3);
            runOpts.OutputDir=fullfile(opts.OutputDir,kind,sprintf('variant_%d',v));
            if isfield(opts,'ReferenceDir') && ~isempty(opts.ReferenceDir)
                runOpts.ReferenceFile=fullfile(opts.ReferenceDir,sprintf('reference_S%d.mat',s));
            end
            row=ABDR_Run_One(s,r,runOpts);
            row.Variant=sprintf('V%d',v);
            row.Experiment=string(kind);
            if isempty(rows),rows=row;else,rows(end+1,1)=row;end %#ok<AGROW>
        end
    end
end
T=struct2table(rows);
if ~isfolder(opts.OutputDir),mkdir(opts.OutputDir);end
writetable(T,fullfile(opts.OutputDir,sprintf('ABDR_%s_results.csv',kind)));
end
