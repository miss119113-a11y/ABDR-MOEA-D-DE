function metrics=NAV_DAG_DeploymentMetricsMemoBatch(particles,model,action)
%NAV_DAG_DEPLOYMENTMETRICSMEMOBATCH Vector-keyed batch memoization for DAG.
%   Archive selectors already store encoded decision vectors. Processing a
%   whole particle array avoids thousands of scalar function calls and
%   repeated position encodings while retaining exact row verification.

persistent vectorRows metricCells vectorLength hashValues hashWeights

if nargin>=3 && strcmpi(char(action),'clear')
    vectorRows=zeros(0,0);
    metricCells=cell(0,1);
    vectorLength=0;
    hashValues=zeros(0,1);
    hashWeights=zeros(1,0);
    metrics=[];
    return;
end
if nargin<2
    error('NAV_DAG_DeploymentMetricsMemoBatch:Input', ...
        'Particles and model are required unless action is clear.');
end
if isempty(particles)
    metrics=repmat(localEmptyMetric(),0,1);
    return;
end

particles=particles(:);
n=numel(particles);
try
    nVector=numel(particles(1).Vector);
    X=reshape([particles.Vector],nVector,[])';
catch
    metrics=repmat(localEmptyMetric(),n,1);
    for i=1:n
        metrics(i)=NAV_DAG_DeploymentMetrics(particles(i).Position,model);
    end
    return;
end

if isempty(vectorLength) || vectorLength~=nVector
    vectorLength=nVector;
    vectorRows=zeros(0,vectorLength);
    metricCells=cell(0,1);
    hashValues=zeros(0,1);
    k=1:vectorLength;
    hashWeights=sin(k*12.9898)+cos(k*78.233);
end

rowHashes=X*hashWeights(:);
metrics=repmat(localEmptyMetric(),n,1);
for i=1:n
    candidates=find(hashValues==rowHashes(i));
    match=[];
    if ~isempty(candidates)
        localMatch=find(all(vectorRows(candidates,:)==X(i,:),2),1,'first');
        if ~isempty(localMatch),match=candidates(localMatch);end
    end
    if isempty(match)
        metric=NAV_DAG_DeploymentMetrics(particles(i).Position,model);
        vectorRows(end+1,:)=X(i,:); %#ok<AGROW>
        metricCells{end+1,1}=metric; %#ok<AGROW>
        hashValues(end+1,1)=rowHashes(i); %#ok<AGROW>
    else
        metric=metricCells{match};
    end
    metrics(i)=metric;
end
end

function metric=localEmptyMetric()
metric=struct('Eligible',false,'Violation',Inf,'MinSafetyMarginM',-Inf, ...
    'P95TurnDeg',Inf,'P95ClimbDeg',Inf,'WorstPairRisk',1);
end