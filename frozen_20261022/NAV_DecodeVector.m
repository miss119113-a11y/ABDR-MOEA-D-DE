function pos = NAV_DecodeVector(x, nVar)
    pos.r = x(1:nVar);
    pos.phi = x(nVar+1:2*nVar);
    pos.psi = x(2*nVar+1:3*nVar);
end