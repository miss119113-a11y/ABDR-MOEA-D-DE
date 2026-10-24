function M = NAV_DAG_DeploymentMetrics(position,model)
%NAV_DAG_DEPLOYMENTMETRICS Lightweight deployment diagnostics.
%   These metrics do not alter the NMOPSO-aligned F1-F4 objectives and do
%   not increment the FE counter. They are used only to guide archive
%   retention and leader selection inside ARCMOVWO-DAG.
%
% Preferred deployment envelope:
%   minimum safety-buffer margin >= 0 m
%   95th-percentile 3-D turn angle <= 30 deg
%   95th-percentile climb angle <= 15 deg

M = struct('Eligible',false,'Violation',Inf,'MinSafetyMarginM',-Inf, ...
    'P95TurnDeg',Inf,'P95ClimbDeg',Inf,'WorstPairRisk',1);

try
    path = NAV_ConvertPath(position,model);
    q = double(path.AbsoluteM);
catch
    return;
end
if size(q,1)<2 || any(~isfinite(q(:)))
    return;
end

pixel = localGet(model,'PixelSizeM',5);
drone = localGet(model,'DroneSizeM',pixel);
safety = localGet(model,'SafetyDistM',10*pixel);

minSafety = inf;
worstRisk = 0;
if isfield(model,'threats') && ~isempty(model.threats)
    for k=1:size(model.threats,1)
        center=[(double(model.threats(k,1))-1)*pixel, ...
                (double(model.threats(k,2))-1)*pixel];
        radius=double(model.threats(k,4))*pixel;
        for j=1:size(q,1)-1
            d=localPointSegmentDistance(center,q(j,1:2),q(j+1,1:2));
            collisionMargin=d-(radius+drone);
            safetyMargin=collisionMargin-safety;
            minSafety=min(minSafety,safetyMargin);
            if collisionMargin<=0
                risk=1;
            elseif safetyMargin<0
                risk=1-collisionMargin/max(safety,eps);
            else
                risk=0;
            end
            worstRisk=max(worstRisk,risk);
        end
    end
end
if isinf(minSafety)
    minSafety=realmax('double');
end

turn=zeros(max(0,size(q,1)-2),1);
for j=1:numel(turn)
    a=q(j+1,:)-q(j,:);
    b=q(j+2,:)-q(j+1,:);
    if norm(a)>eps && norm(b)>eps
        turn(j)=atan2(norm(cross(a,b)),dot(a,b))*180/pi;
    end
end

seg=diff(q,1,1);
horizontal=sqrt(sum(seg(:,1:2).^2,2));
climb=abs(atan2(seg(:,3),max(horizontal,eps))*180/pi);

p95Turn=localPercentile(turn,95);
p95Climb=localPercentile(climb,95);

safetyViolation=max(0,-minSafety/max(safety,eps));
turnViolation=max(0,p95Turn/30-1);
climbViolation=max(0,p95Climb/15-1);

% Safety is the dominant deployment deficiency observed in E70P.
violation=safetyViolation+0.25*turnViolation+0.25*climbViolation;

M.Eligible=violation<=1e-12;
M.Violation=violation;
M.MinSafetyMarginM=minSafety;
M.P95TurnDeg=p95Turn;
M.P95ClimbDeg=p95Climb;
M.WorstPairRisk=worstRisk;
end

function d=localPointSegmentDistance(p,a,b)
ab=b-a;
den=dot(ab,ab);
if den<=eps
    d=norm(p-a);
    return;
end
t=dot(p-a,ab)/den;
t=min(1,max(0,t));
projection=a+t*ab;
d=norm(p-projection);
end

function p=localPercentile(x,q)
x=sort(double(x(isfinite(x))));
if isempty(x)
    p=0;
    return;
end
pos=1+(numel(x)-1)*q/100;
lo=floor(pos);hi=ceil(pos);
if lo==hi
    p=x(lo);
else
    p=x(lo)+(pos-lo)*(x(hi)-x(lo));
end
end

function value=localGet(s,name,defaultValue)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    value=double(s.(name));
else
    value=double(defaultValue);
end
end
