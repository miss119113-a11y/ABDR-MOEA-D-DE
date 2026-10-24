function S=ABDR_Review_PX4(csvFile)
%ABDR_REVIEW_PX4 Distinguish mission completion and safety checks.
if nargin<1 || isempty(csvFile)
    root=fileparts(fileparts(mfilename('fullpath')));
    csvFile=fullfile(root,'results','E06_PX4_Gazebo_SITL_120_Missions.csv');
end
T=readtable(csvFile,'TextType','string');
labels=unique(T.Algorithm,'stable');
S=table();
for k=1:numel(labels)
    t=T(T.Algorithm==labels(k),:);
    completed=strcmpi(string(t.MissionCompleted),'true') | string(t.MissionCompleted)=="1";
    tracking=strcmpi(string(t.TrackingSuccess),'true') | string(t.TrackingSuccess)=="1";
    safe=strcmpi(string(t.SafetyCompletion),'true') | string(t.SafetyCompletion)=="1";
    row=table(labels(k),height(t),sum(completed),sum(tracking),sum(safe), ...
        'VariableNames',{'Algorithm','N','Completed','TrackingPassed','SafetyPassed'});
    S=[S;row]; %#ok<AGROW>
end
disp(S);
end
