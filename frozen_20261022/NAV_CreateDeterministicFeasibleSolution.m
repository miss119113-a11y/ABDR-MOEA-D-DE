function [bestPos,bestCost] = NAV_CreateDeterministicFeasibleSolution(model,VarMin,VarMax,CostFunction)
%NAV_CREATEDETERMINISTICFEASIBLESOLUTION Seed-independent feasible fallback.
%   Symmetric dog-leg templates are evaluated through the same frozen cost
%   entry. No constraint is relaxed and no scene-specific waypoint is used.

[~,~,meta]=NAV_NavigationBounds(model);
n=model.n;
baseR=meta.DirectDistanceM/(n+1);
angleSet=[0.15 0.25 0.35 0.45 0.60 0.75];
scaleSet=[0.85 1.00 1.15];
switchSet=unique(max(2,min(n,round(linspace(2,n,7)))));
bestPos=struct('r',baseR*ones(1,n),'phi',zeros(1,n),'psi',zeros(1,n));
bestPos=NAV_ClampPosition(bestPos,VarMin,VarMax);
bestCost=inf(4,1); bestTotal=inf;

for angle=angleSet
    for switchIndex=switchSet
        for scale=scaleSet
            for direction=[-1 1]
                pos=struct('r',baseR*scale*ones(1,n),'phi',zeros(1,n),'psi',zeros(1,n));
                pos.phi(1)=direction*angle;
                pos.phi(switchIndex)=-direction*angle;
                pos=NAV_ClampPosition(pos,VarMin,VarMax);
                [cost, evalOK]=NAV_FE_Evaluate(CostFunction,pos);
                if ~evalOK, return; end
                if localIsFeasibleCost(cost)
                    total=sum(cost(1:min(4,numel(cost))));
                    if total<bestTotal
                        bestPos=pos; bestCost=cost; bestTotal=total;
                    end
                    % A low-cost template is sufficient as an initializer;
                    % continuing the full grid only wastes evaluations.
                    if total<=0.35, return; end
                end
            end
        end
    end
end
end

function tf=localIsFeasibleCost(cost)
c=double(cost(:));
tf=numel(c)>=4 && all(isfinite(c(1:4))) && all(c(1:4)<=1+1e-12);
end