function S=ABDR_Review_PX4(dataFile)
%ABDR_REVIEW_PX4 Read the paper's corrected mission-level PX4 table.
% Legacy U28 preflight results are intentionally not used by default.
if nargin<1 || isempty(dataFile)
    root=fileparts(fileparts(mfilename('fullpath')));
    dataFile=fullfile(root,'results','E06_PX4_Paper_Missions_120.csv.gz');
end
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
for k=1:numel(labels)
    t=T(T.Algorithm==labels(k),:);
    isTrue=@(x) strcmpi(string(x),'true') | string(x)=="1";
    completed=isTrue(t.MissionCompleted);
    tracking=isTrue(t.TrackingSuccess);
    safe=isTrue(t.SafetyCompletion);
    % Runtime metrics are pooled over completed flights, while rates use all missions.
    active=t(completed,:);
    xte=mean(double(active.XTE_RMSE_m),'omitnan');
    p95=mean(double(active.XTE_P95_m),'omitnan');
    clearance=mean(double(active.MinTerrainClearanceM),'omitnan');
    threat=mean(double(active.MinThreatMarginM),'omitnan');
    row=table(labels(k),height(t),sum(completed),sum(tracking),sum(safe),...
        xte,p95,clearance,threat,...
        'VariableNames',{'Algorithm','N','Completed','TrackingPassed','SafetyPassed',...
        'XTE_RMSE_m','XTE_P95_m','MinTerrainClearanceM','MinThreatMarginM'});
    S=[S;row]; %#ok<AGROW>
end
disp(S);
end
