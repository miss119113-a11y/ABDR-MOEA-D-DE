function x = NAV_EncodePosition(pos)
    x = [pos.r(:)' pos.phi(:)' pos.psi(:)'];
end
