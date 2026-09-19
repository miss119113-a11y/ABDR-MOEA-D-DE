function [archive,best,history] = BI_MOEAD_Core(params)
%BI_MOEAD_CORE Compact paper-facing BI-MOEA/D search core.
%
% This file contains the principal search logic used by the manuscript:
%   1) fixed MOEA/D reference directions and neighborhoods;
%   2) current-to-local-best/1 differential donor;
%   3) population-relative objective pressure;
%   4) Block Inheritance (BI);
%   5) Direction-Compatible Replacement (DCR);
%   6) success-history DE parameter adaptation.
%
% The UAV geometry/evaluator and shared feasible-pool builder are intentionally
% kept outside this minimal private snapshot. Supply:
%   params.InitialPopulation : N-by-d decision matrix
%   params.EvaluateFcn       : @(x) -> 1-by-4 feasible objective vector
%                              or a 1-by-4 feasibility-priority vector
%   params.LB / params.UB    : decision bounds
%
% Paper defaults: N=30, MaxFEs=6000, Tnb=6, archive size=30,
% M_F=M_CR=0.5, sigma_DE=0.1, archive refresh stride=4.

params = localDefaults(params);
rng(params.Seed,'twister');

X = double(params.InitialPopulation);
[N,d] = size(X);
assert(N==params.nPop,'BI:Population','Initial population must contain nPop rows.');
assert(d==numel(params.LB) && d==numel(params.UB),'BI:Bounds','Bound size mismatch.');
assert(mod(d,3)==0,'BI:Encoding','Decision vector must be [r,phi,psi].');

F = nan(N,4);
for i=1:N
    F(i,:) = localEvaluate(params.EvaluateFcn,X(i,:));
end
FE = N;

W = NAV_GenerateWeights(N,4);
B = localNeighborhood(W,params.neighborSize);
archiveX = X;
archiveF = F;
[archiveX,archiveF] = localArchive(archiveX,archiveF,params.nRep);

MF = 0.5;
MCR = 0.5;
history.FE = [];
history.BestC = [];
history.MF = [];
history.MCR = [];

while FE < params.MaxFEs
    ideal = min(F,[],1);
    nadir = max(F,[],1);
    ranks = localRanks(F);
    quota = false(N,1);

    successF = [];
    successCR = [];
    successGain = [];

    order = randperm(N);
    for qq=1:numel(order)
        if FE>=params.MaxFEs, break; end
        i = order(qq);

        Fi = min(1,max(0.1,MF + params.sigmaDE*randn));
        CRi = min(1,max(0,MCR + params.sigmaDE*randn));

        % Local guide: all candidates are judged under source direction i.
        neigh = B(i,:);
        score = inf(size(neigh));
        for k=1:numel(neigh)
            j = neigh(k);
            score(k) = localScalar(F(j,:),W(i,:),ideal);
        end
        [~,kk] = min(score);
        bestIndex = neigh(kk);

        % Two distinct global differential parents, excluding the source.
        pool = setdiff(1:N,i,'stable');
        pick = pool(randperm(numel(pool),2));
        r1 = pick(1); r2 = pick(2);

        donor = X(i,:) ...
            + Fi*(X(bestIndex,:)-X(i,:)) ...
            + Fi*(X(r1,:)-X(r2,:));
        donor = min(params.UB,max(params.LB,donor));

        % Ordinal objective pressure: largest rank is the current weak target.
        [~,mstar] = max(ranks(i,:));

        % Block Inheritance after ordinary binomial crossover.
        child = NAV_PBD_BlockCrossover(X(i,:),donor,mstar,CRi);
        child = min(params.UB,max(params.LB,child));

        childF = localEvaluate(params.EvaluateFcn,child);
        FE = FE + 1;

        % DCR: associate feasible child with nearest normalized direction.
        eligible = unique([i,B(i,:)],'stable');
        a = localAssociate(childF,W,ideal,nadir);
        if ismember(a,eligible) && ~quota(a)
            target = a;
        else
            available = eligible(~quota(eligible));
            if isempty(available)
                continue;
            end
            target = available(1);
        end

        oldScore = localScalar(F(target,:),W(target,:),ideal);
        newScore = localScalar(childF,W(target,:),ideal);
        replaced = newScore < oldScore;

        % Source fallback when redirected replacement fails.
        if ~replaced && target~=i && ~quota(i)
            target = i;
            oldScore = localScalar(F(i,:),W(i,:),ideal);
            newScore = localScalar(childF,W(i,:),ideal);
            replaced = newScore < oldScore;
        end

        if replaced
            X(target,:) = child;
            F(target,:) = childF;
            quota(target) = true;

            gain = oldScore-newScore;
            if isfinite(gain) && gain>0
                successF(end+1,1) = Fi; %#ok<AGROW>
                successCR(end+1,1) = CRi; %#ok<AGROW>
                successGain(end+1,1) = gain; %#ok<AGROW>
            end
        end

        archiveX(end+1,:) = child; %#ok<AGROW>
        archiveF(end+1,:) = childF; %#ok<AGROW>
    end

    % Success-history DE update.
    if ~isempty(successF)
        w = successGain./sum(successGain);
        den = sum(w.*successF);
        if den>0
            MF = min(1,max(0.1,sum(w.*successF.^2)/den));
        end
        MCR = min(1,max(0,sum(w.*successCR)));
    end

    [archiveX,archiveF] = localArchive(archiveX,archiveF,params.nRep);

    history.FE(end+1,1) = FE;
    history.BestC(end+1,1) = min(sum(archiveF,2));
    history.MF(end+1,1) = MF;
    history.MCR(end+1,1) = MCR;
end

archive = struct('X',archiveX,'F',archiveF);
[~,ibest] = min(sum(archiveF,2));
best = struct('X',archiveX(ibest,:),'F',archiveF(ibest,:), ...
    'C',sum(archiveF(ibest,:)));
end

function params = localDefaults(params)
if nargin<1 || isempty(params), params=struct(); end
params = localSet(params,'nPop',30);
params = localSet(params,'MaxFEs',6000);
params = localSet(params,'neighborSize',6);
params = localSet(params,'nRep',30);
params = localSet(params,'sigmaDE',0.1);
params = localSet(params,'Seed',1);
required = {'InitialPopulation','EvaluateFcn','LB','UB'};
for k=1:numel(required)
    assert(isfield(params,required{k}), ...
        'BI:MissingInput','Missing params.%s',required{k});
end
params.LB = double(params.LB(:)');
params.UB = double(params.UB(:)');
end

function s = localSet(s,name,value)
if ~isfield(s,name) || isempty(s.(name)), s.(name)=value; end
end

function f = localEvaluate(fun,x)
f = double(fun(x));
f = f(:)';
assert(numel(f)==4 && all(isfinite(f)),'BI:Evaluator','Evaluator must return four finite values.');
end

function B = localNeighborhood(W,T)
N=size(W,1);
D=zeros(N,N);
for i=1:N
    q=W-W(i,:);
    D(i,:)=sqrt(sum(q.^2,2));
end
B=zeros(N,T);
for i=1:N
    [~,ord]=sort(D(i,:),'ascend');
    ord(ord==i)=[];
    B(i,:)=ord(1:T);
end
end

function ranks = localRanks(F)
N=size(F,1);
M=size(F,2);
ranks=ones(N,M);
for i=1:N
    for m=1:M
        ranks(i,m)=1+sum(F(:,m)<F(i,m))-1;
    end
end
end

function g = localScalar(f,w,ideal)
delta=max(0,double(f(:)')-double(ideal(:)'));
g=max(max(double(w(:)'),1e-12).*delta);
end

function a = localAssociate(f,W,ideal,nadir)
v=max(0,double(f(:)')-double(ideal(:)'));
v=v./max(double(nadir(:)')-double(ideal(:)'),1e-12);
v=v./max(norm(v),1e-12);
WN=double(W)./max(vecnorm(double(W),2,2),1e-12);
dist=sum((WN-v).^2,2);
[~,a]=min(dist);
end

function [X,F] = localArchive(X,F,nKeep)
% Feasible nondominated archive with deterministic crowding truncation.
[X,ia]=unique(round(X*1e10)/1e10,'rows','stable');
F=F(ia,:);
n=size(F,1);
keep=true(n,1);
tol=1e-12;
for i=1:n
    dom=all(F<=F(i,:)+tol,2) & any(F<F(i,:)-tol,2);
    dom(i)=false;
    if any(dom), keep(i)=false; end
end
X=X(keep,:); F=F(keep,:);
if size(F,1)<=nKeep, return; end

crowd=zeros(size(F,1),1);
for m=1:size(F,2)
    [~,ord]=sort(F(:,m));
    crowd(ord([1 end]))=inf;
    span=F(ord(end),m)-F(ord(1),m);
    if span<=eps, continue; end
    for k=2:numel(ord)-1
        crowd(ord(k))=crowd(ord(k)) + ...
            (F(ord(k+1),m)-F(ord(k-1),m))/span;
    end
end
[~,ord]=sortrows([-crowd,(1:numel(crowd))'],[1 2]);
ord=ord(1:nKeep);
X=X(ord,:); F=F(ord,:);
end
