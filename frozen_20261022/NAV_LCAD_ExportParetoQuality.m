function outDir = NAV_LCAD_ExportParetoQuality(formalDir, outDir)
%NAV_LCAD_EXPORTPARETOQUALITY Export archive-level Pareto quality tables.
% Metrics are normalized per scenario and computed from task MAT archives:
% HV_MC (higher is better), IGD (lower is better), SpreadNN, archive sizes.

if nargin < 1 || isempty(formalDir), formalDir = fullfile(pwd,'results','E01_Main_Formal_Comparison_4Scen_20Run_300It_80Pop'); end
if nargin < 2 || isempty(outDir), outDir = fullfile(formalDir,'pareto_quality'); end
if exist(outDir,'dir')~=7, mkdir(outDir); end
if exist(fullfile(formalDir,'tasks'),'dir')~=7, error('Task directory not found: %s', fullfile(formalDir,'tasks')); end

files = dir(fullfile(formalDir,'tasks','*.mat'));
if isempty(files), error('No task MAT files found in %s', fullfile(formalDir,'tasks')); end

raw = struct('Scenario',{},'Run',{},'Method',{},'Costs',{});
for i=1:numel(files)
    fp = fullfile(files(i).folder, files(i).name);
    try
        S = load(fp);
        [sc,run,method] = parseTaskMeta(S, files(i).name);
        C = extractCosts(S);
        if isempty(C), continue; end
        raw(end+1).Scenario = sc; %#ok<AGROW>
        raw(end).Run = run;
        raw(end).Method = char(displayMethod(method));
        raw(end).Costs = C;
    catch ME
        warning('ARCMOVWO:ParetoQuality:SkipTask','Skip %s: %s', files(i).name, ME.message);
    end
end
if isempty(raw), error('No valid archive costs extracted.'); end

scenarioList = unique([raw.Scenario]);
rows = {};
refPoint = [1.05 1.05 1.05 1.05];
rng(20260610,'twister');
mcSamples = 20000;
U = rand(mcSamples,4).*refPoint;

for si = 1:numel(scenarioList)
    sc = scenarioList(si);
    idxSc = find([raw.Scenario] == sc);
    allC = [];
    for k=idxSc(:)'
        allC = [allC; raw(k).Costs(:,1:4)]; %#ok<AGROW>
    end
    allC = allC(all(isfinite(allC),2),:);
    if isempty(allC), continue; end
    cmin = min(allC,[],1); cmax = max(allC,[],1);
    span = max(cmax-cmin, 1e-12);
    allN = min(max((allC-cmin)./span,0),1);
    refFront = nondominatedRows(allN);
    if size(refFront,1) > 1000
        refFront = refFront(round(linspace(1,size(refFront,1),1000)),:);
    end

    methods = unique(string({raw(idxSc).Method}),'stable');
    for mi=1:numel(methods)
        mth = methods(mi);
        idxM = idxSc(strcmp(string({raw(idxSc).Method}),mth));
        for kk=idxM(:)'
            C = raw(kk).Costs(:,1:4);
            C = C(all(isfinite(C),2),:);
            if isempty(C), continue; end
            CN = min(max((C-cmin)./span,0),1);
            ND = nondominatedRows(CN);
            hv = hvMonteCarlo(ND, U);
            igd = igdMetric(refFront, ND);
            sp = spreadNN(ND);
            stats = costStats(C);
            rows(end+1,:) = [{sc, raw(kk).Run, char(mth), size(C,1), size(ND,1), hv, igd, sp}, stats]; %#ok<AGROW>
        end
    end
end

varNames = {'Scenario','Run','Method','ArchiveSize','NDArchiveSize','HV_MC','IGD','SpreadNN', ...
            'F1Min','F2Min','F3Min','F4Min','F1Mean','F2Mean','F3Mean','F4Mean','F1Std','F2Std','F3Std','F4Std'};
T = cell2table(rows,'VariableNames',varNames);
writetable(T, fullfile(outDir,'pareto_quality_all_runs.csv'));
S = summarizePQ(T); writetable(S, fullfile(outDir,'pareto_quality_summary_by_method.csv'));
SS = summarizePQScenario(T); writetable(SS, fullfile(outDir,'pareto_quality_summary_by_scenario.csv'));
save(fullfile(outDir,'pareto_quality.mat'),'T','S','SS');
writeReadme(outDir, formalDir);
fprintf('ARCMOVWO Pareto quality tables exported to %s\n', outDir);
end

function [sc,run,method] = parseTaskMeta(S, name)
sc = NaN; run = NaN; method = "unknown";
if isfield(S,'taskMeta')
    tm = S.taskMeta;
    if isfield(tm,'Scenario'), sc = tm.Scenario; end
    if isfield(tm,'Run'), run = tm.Run; end
    if isfield(tm,'Method'), method = string(tm.Method); end
elseif isfield(S,'scenario') && isfield(S,'runId') && isfield(S,'method')
    sc = S.scenario; run = S.runId; method = string(S.method);
end
if isnan(sc) || isnan(run) || method=="unknown"
    tok = regexp(name,'S(\d+)_R(\d+)_(.+)\.mat','tokens','once');
    if ~isempty(tok)
        sc = str2double(tok{1}); run = str2double(tok{2}); method = normalizeMethodName(string(tok{3}));
    end
end
end
function method = normalizeMethodName(method)
s = upper(char(method));
s = strrep(s,'MOEA_D','MOEA/D');
s = strrep(s,'NSGA_II','NSGA-II');
s = strrep(s,'NSGAII','NSGA-II');
s = strrep(s,'NSGA_III','NSGA-III');
method = string(s);
end
function method = displayMethod(method)
method = string(method);
end
function C = extractCosts(S)
C = [];
if isfield(S,'rep'), C = [C; costsFromStruct(S.rep)]; end
if isfield(S,'best'), C = [C; costsFromStruct(S.best)]; end
if isempty(C) && isfield(S,'row')
    try
        r = S.row;
        C = [double(r.F1) double(r.F2) double(r.F3) double(r.F4)];
    catch
    end
end
C = double(C);
if ~isempty(C), C = C(:,1:min(4,size(C,2))); end
if size(C,2)<4, C=[]; end
end
function C = costsFromStruct(A)
C = [];
if isempty(A), return; end
if isstruct(A)
    A = A(:);
    for i=1:numel(A)
        if isfield(A(i),'Cost') && ~isempty(A(i).Cost)
            c = double(A(i).Cost(:)');
            if numel(c)>=4 && all(isfinite(c(1:4)))
                C(end+1,:) = c(1:4); %#ok<AGROW>
            end
        end
    end
end
end
function ND = nondominatedRows(C)
C = unique(C,'rows','stable'); n = size(C,1); keep = true(n,1);
for i=1:n
    if ~keep(i), continue; end
    for j=1:n
        if i==j, continue; end
        if all(C(j,:) <= C(i,:)) && any(C(j,:) < C(i,:)), keep(i)=false; break; end
    end
end
ND = C(keep,:);
end
function hv = hvMonteCarlo(ND,U)
if isempty(ND), hv=NaN; return; end
covered = false(size(U,1),1);
for i=1:size(ND,1), covered = covered | all(U >= ND(i,:),2); end
hv = mean(covered) * prod(max(U,[],1));
end
function v = igdMetric(R,A)
if isempty(R) || isempty(A), v=NaN; return; end
D = pdist2safe(R,A); v = mean(min(D,[],2),'omitnan');
end
function v = spreadNN(A)
if size(A,1)<=2, v=NaN; return; end
D = pdist2safe(A,A); D(1:size(D,1)+1:end) = Inf;
nn = min(D,[],2); mu = mean(nn,'omitnan');
if mu<=eps, v=0; else, v=std(nn,'omitnan')/mu; end
end
function D = pdist2safe(A,B)
D = zeros(size(A,1),size(B,1));
for i=1:size(A,1), dif = B - A(i,:); D(i,:) = sqrt(sum(dif.^2,2)); end
end
function stats = costStats(C)
stats = num2cell([min(C,[],1), mean(C,1,'omitnan'), std(C,0,1,'omitnan')]);
end
function S = summarizePQ(T)
methods = unique(T.Method,'stable'); rows={};
for i=1:numel(methods)
    X = T(strcmp(T.Method,methods{i}),:);
    rows(end+1,:) = {methods{i},height(X),mean(X.HV_MC,'omitnan'),std(X.HV_MC,0,'omitnan'),mean(X.IGD,'omitnan'),mean(X.SpreadNN,'omitnan'),mean(X.ArchiveSize,'omitnan'),mean(X.NDArchiveSize,'omitnan')}; %#ok<AGROW>
end
S = cell2table(rows,'VariableNames',{'Method','N','MeanHV_MC','StdHV_MC','MeanIGD','MeanSpreadNN','MeanArchiveSize','MeanNDArchiveSize'});
if height(S)>0, S = sortrows(S, {'MeanHV_MC','MeanIGD'}, {'descend','ascend'}); end
end
function S = summarizePQScenario(T)
scens = unique(T.Scenario); methods = unique(T.Method,'stable'); rows={};
for s=scens(:)'
    for i=1:numel(methods)
        X = T(T.Scenario==s & strcmp(T.Method,methods{i}),:);
        rows(end+1,:) = {s,methods{i},height(X),mean(X.HV_MC,'omitnan'),mean(X.IGD,'omitnan'),mean(X.SpreadNN,'omitnan'),mean(X.NDArchiveSize,'omitnan')}; %#ok<AGROW>
    end
end
S = cell2table(rows,'VariableNames',{'Scenario','Method','N','MeanHV_MC','MeanIGD','MeanSpreadNN','MeanNDArchiveSize'});
end
function writeReadme(outDir, formalDir)
fid = fopen(fullfile(outDir,'README_pareto_quality.md'),'w'); if fid<0, return; end
fprintf(fid,'# ARCMOVWO Pareto Quality Export\n\n');
fprintf(fid,'Source formal directory: `%s`\n\n', formalDir);
fprintf(fid,'Metrics are computed from task archives and normalized within each scenario.\n');
fclose(fid);
end


