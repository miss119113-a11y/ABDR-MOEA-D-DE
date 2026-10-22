function D=NAV_TBRV4_DiagnosePosition(position,model)
%NAV_TBRV4_DIAGNOSEPOSITION Geometry-only local repairability diagnosis.
% No objective function is called and no FE is consumed.
D=localEmpty();
if ~isstruct(position) || ~all(isfield(position,{'r','phi','psi'})),return;end
try
    path=NAV_ConvertPath(position,model);
catch
    return;
end
q=double(path.AbsoluteM);
if size(q,1)<2,return;end
nVar=numel(position.r);
pixel=localGet(model,'PixelSizeM',5);
drone=localGet(model,'DroneSizeM',pixel);
safety=localGet(model,'SafetyDistM',10*pixel);
threats=localThreats(model);

% Risk repairability: virtual lateral shifts on both sides of each unsafe
% segment. The score rewards a larger safety-margin gain with less offset.
for j=1:size(q,1)-1
    a=q(j,1:2); b=q(j+1,1:2);
    [margin,idx,center,projection,direction]= ...
        localSegmentMargin(a,b,threats,pixel,drone);
    if idx<=0 || margin>=safety,continue;end
    pressure=min(1,max(0,(safety-margin)/max(safety,eps)));
    segLen=max(norm(b-a),eps);
    normal=[-direction(2),direction(1)];
    required=max(0.25*safety,safety-margin);
    offset=min(safety,required);
    sideScores=zeros(1,2);
    signs=[-1 1];
    for s=1:2
        shift=signs(s)*offset*normal;
        if ~localInsideBounds([a+shift;b+shift],model,pixel),continue;end
        shiftedMargin=localSegmentMargin(a+shift,b+shift,threats,pixel,drone);
        gain=shiftedMargin-margin;
        sideScores(s)=pressure*max(0,gain)/max(safety,eps) / ...
            (1+offset/segLen);
    end
    [score,s]=max(sideScores);
    if score>D.RiskScore
        D.RiskScore=score;
        D.RiskSegmentIndex=j;
        D.RiskVariableIndex=min(nVar,max(1,j));
        D.ThreatIndex=idx;
        D.Center=center;
        D.Projection=projection;
        D.Direction=direction;
        D.RiskPressure=pressure;
        D.BestSide=signs(s);
        D.CurrentCollisionMarginM=margin;
    end
end

% Contract repairability: a local shortcut must save length, reduce a turn,
% and remain collision-free before it is considered for one FE evaluation.
for j=1:size(q,1)-2
    a=q(j,:); b=q(j+1,:); c=q(j+2,:);
    l1=norm(b-a); l2=norm(c-b); direct=norm(c-a);
    localLen=l1+l2;
    saving=localLen-direct;
    if saving<=1e-10 || l1<=eps || l2<=eps,continue;end
    angle=atan2(norm(cross(b-a,c-b)),dot(b-a,c-b));
    directMargin=localSegmentMargin(a(1:2),c(1:2),threats,pixel,drone);
    if directMargin<=0,continue;end
    clearance=min(1,max(0,directMargin/max(safety,eps)));
    score=(saving/localLen+angle/pi)*clearance;
    if score>D.ContractScore
        D.ContractScore=score;
        D.ContractVariableIndex=min(nVar,max(1,j));
        D.ContractPathIndex=j;
        D.ContractDirectMarginM=directMargin;
    end
end
D.Valid=true;
end

function [margin,idx,center,projection,direction]=localSegmentMargin(a,b,threats,pixel,drone)
margin=inf;idx=0;center=[nan nan];projection=[nan nan];
direction=b-a;
if norm(direction)<=eps,direction=[1 0];else,direction=direction/norm(direction);end
for k=1:size(threats,1)
    c=(double(threats(k,1:2))-1)*pixel;
    radius=double(threats(k,4))*pixel+drone;
    [dist,proj]=localPointSegment(c,a,b);
    m=dist-radius;
    if m<margin
        margin=m;idx=k;center=c;projection=proj;
    end
end
end

function tf=localInsideBounds(P,model,pixel)
xBounds=([double(model.xmin),double(model.xmax)]-1)*pixel;
yBounds=([double(model.ymin),double(model.ymax)]-1)*pixel;
tf=all(P(:,1)>=xBounds(1) & P(:,1)<=xBounds(2) & ...
       P(:,2)>=yBounds(1) & P(:,2)<=yBounds(2));
end

function [d,projection]=localPointSegment(point,a,b)
ab=b-a;den=dot(ab,ab);
if den<=eps,projection=a;d=norm(point-a);return;end
t=min(1,max(0,dot(point-a,ab)/den));
projection=a+t*ab;d=norm(point-projection);
end

function T=localThreats(model)
if isstruct(model)&&isfield(model,'threats')&&~isempty(model.threats)
    T=double(model.threats);
else
    T=zeros(0,4);
end
end

function D=localEmpty()
D=struct('Valid',false,'RiskScore',0,'RiskSegmentIndex',0, ...
    'RiskVariableIndex',0,'ThreatIndex',0,'Center',[nan nan], ...
    'Projection',[nan nan],'Direction',[nan nan],'RiskPressure',0, ...
    'BestSide',0,'CurrentCollisionMarginM',inf,'ContractScore',0, ...
    'ContractVariableIndex',0,'ContractPathIndex',0, ...
    'ContractDirectMarginM',inf);
end
function v=localGet(s,name,defaultValue)
if isstruct(s)&&isfield(s,name)&&~isempty(s.(name)),v=double(s.(name));else,v=defaultValue;end
end