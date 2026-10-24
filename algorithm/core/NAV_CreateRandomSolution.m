function sol = NAV_CreateRandomSolution(VarSize, VarMin, VarMax)
    sol.r = VarMin.r + (VarMax.r - VarMin.r) .* rand(VarSize);
    sol.phi = VarMin.phi + (VarMax.phi - VarMin.phi) .* rand(VarSize);
    sol.psi = VarMin.psi + (VarMax.psi - VarMin.psi) .* rand(VarSize);
end
