function [lb, ub] = NAV_VectorBounds(nVar, VarMin, VarMax)
    lb = [repmat(VarMin.r, 1, nVar), repmat(VarMin.phi, 1, nVar), repmat(VarMin.psi, 1, nVar)];
    ub = [repmat(VarMax.r, 1, nVar), repmat(VarMax.phi, 1, nVar), repmat(VarMax.psi, 1, nVar)];
end
