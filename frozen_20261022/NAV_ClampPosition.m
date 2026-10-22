function pos = NAV_ClampPosition(pos, VarMin, VarMax)
    pos.r = max(VarMin.r, min(VarMax.r, pos.r));
    pos.phi = max(VarMin.phi, min(VarMax.phi, pos.phi));
    pos.psi = max(VarMin.psi, min(VarMax.psi, pos.psi));
end
