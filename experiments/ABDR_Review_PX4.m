function S=ABDR_Review_PX4(dataFile)
%ABDR_REVIEW_PX4 Paper-cohort PX4 summary: rates, means, and minima.
% Metric population: completed missions only; outcome denominator: all 20.
if nargin<1 || isempty(dataFile)
    root=fileparts(fileparts(mfilename('fullpath')));
    dataFile=fullfile(root,'results','E06_PX4_Paper_Missions_120.csv.gz');
end
root=fileparts(fileparts(mfilename('fullpath')));
continuous=readtable(fullfile(root,'results','E06_PX4_Continuous_Clearance_40.csv'),'TextType','string');
if endsWith(string(dataFile),".gz")
    tempDir=tempname;
    mkdir(tempDir);
    cleanTemp=onCleanup(@()rmdir(tempDir,'s')); %#ok<NASGU>
    expanded=gunzip(dataFile,tempDir);
    T=readtable(expanded{1},'TextType','string');
else
    T=readtable(dataFile,'TextType','string');
end
labels=unique(T.Algorithm,'stable');
S=table();
isTrue=@(x) strcmpi(string(x),'true') | string(x)=="1";
for k=1:numel(labels)
    t=T(T.Algorithm==labels(k),:);
    complete=isTrue(t.MissionCompleted);
    track=isTrue(t.TrackingSuccess);
    safe=isTrue(t.SafetyCompletion);
    active=t(complete,:);
    [tf,loc]=ismember(active.MissionID,continuous.MissionID);
    clearance=double(active.MinTerrainClearanceM);
    clearance(tf)=double(continuous.ContinuousMinTerrainClearanceM(loc(tf)));
    xte=mean(double(active.XTE_RMSE_m),'omitnan');
    p95=mean(double(active.XTE_P95_m),'omitnan');
    minTerrain=min(clearance);
    minThreat=min(double(active.MinThreatMarginM));
    entry=table(labels(k),height(t),sum(complete),sum(track),sum(safe),...
        xte,p95,minTerrain,minThreat,...
        'VariableNames',{'Algorithm','N','Completed','TrackingPassed','SafetyPassed',...
        'XTE_RMSE_m','XTE_P95_m','MinTerrainClearanceM','MinThreatMarginM'});
    S=[S;entry]; %#ok<AGROW>
end
disp(S);
end
