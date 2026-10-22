function position = NAV_SphericalToCartLegacy(solution,model)
%NAV_SPHERICALTOCARTLEGACY Original mixed-unit decoder, isolated for replay.
r=solution.r; phi=solution.phi; psi=solution.psi;
start=[1,0,0,model.start(1);0,1,0,model.start(2); ...
       0,0,1,model.start(3);0,0,0,1];
direction=model.end-model.start;
heading=atan2(direction(2),direction(1));
climb=atan2(direction(3),norm(direction(1:2)));
startPosition=start*TransfomationMatrix(0,heading,climb);
x=zeros(1,model.n); y=x; z=x; T=eye(4);
for i=1:model.n
    T=T*TransfomationMatrix(r(i),phi(i),psi(i));
    pose=startPosition*T;
    x(i)=min(max(pose(1,4),model.xmin),model.xmax);
    y(i)=min(max(pose(2,4),model.ymin),model.ymax);
    z(i)=min(max(pose(3,4),model.zmin),model.zmax);
end
position=struct('x',x,'y',y,'z',z,'CoordinateFrame','legacy_mixed');
end
