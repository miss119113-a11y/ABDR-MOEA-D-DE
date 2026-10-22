function cost = NAV_MyCost_Legacy(sol, model, varmin)
%NAV_MYCOST_LEGACY Original grid-index UAV path cost kept for reproducibility.
%   This is the former implementation of MyCost.m.  It is retained so older
%   E01/E02/E18 results can still be reproduced by setting NAV_COST_MODE to
%   "legacy".  New experiments should use MyCost.m in its default
%   physical_v2 mode.

    J_inf = inf;
    n = model.n;
    H = model.H;
    
    x = sol.x;
    y = sol.y;
    z = sol.z;
    
    xs = model.start(1);
    ys = model.start(2);
    zs = model.start(3);
    
    xf = model.end(1);
    yf = model.end(2);
    zf = model.end(3);
    
    x_all = [xs x xf];
    y_all = [ys y yf];
    z_all = [zs z zf];
    
    N = size(x_all, 2);
    
    z_abs = zeros(1, N);
    for i = 1:N
        z_abs(i) = z_all(i) + H(round(y_all(i)), round(x_all(i)));
    end
    
    Traj = 0;
    for i = 1:N-1
        diff = [x_all(i+1) - x_all(i); y_all(i+1) - y_all(i); z_abs(i+1) - z_abs(i)];
        if norm(diff) <= varmin.r
            Traj = 0;
            break;
        end
        Traj = Traj + norm(diff);
    end
    PP = norm([xf yf zf] - [xs ys zs]);
    J1 = abs(1 - PP / Traj);

    threats = model.threats;
    threat_num = size(threats, 1);
    
    drone_size = 1;
    danger_dist = 10 * drone_size;
    
    J2 = 0;
    n2 = 0;
    for i = 1:threat_num
        threat = threats(i, :);
        threat_x = threat(1);
        threat_y = threat(2);
        threat_radius = threat(4);
        for j = 1:N-1
            dist = DistP2S([threat_x threat_y], [x_all(j) y_all(j)], [x_all(j+1) y_all(j+1)]);
            if dist > (threat_radius + drone_size + danger_dist)
                threat_cost = 0;
            elseif dist < (threat_radius + drone_size)
                threat_cost = J_inf;
            else
                threat_cost = 1 - (dist - drone_size - threat_radius) / danger_dist;
            end
            n2 = n2 + 1;
            J2 = J2 + threat_cost;
        end
    end
    J2 = J2 / n2;

    zmax = model.zmax;
    zmin = model.zmin;
    J3 = 0;
    n3 = 0;
    for i = 1:n
        if z(i) < 0
            J3_node = J_inf;
        else
            J3_node = abs(z(i) - (zmax + zmin) / 2);
        end
        J3_node = J3_node / ((zmax - zmin) / 2);
        n3 = n3 + 1;
        J3 = J3 + J3_node;
    end
    J3 = J3 / n3;

    J4 = 0;
    n4 = 0;
    for i = 1:N-2
        for j = i:-1:1
             segment1 = [x_all(j+1); y_all(j+1); z_abs(j+1)] - [x_all(j); y_all(j); z_abs(j)];
             if nnz(segment1) ~= 0
                 break;
             end
        end
        
        for j = i:N-2
            segment2 = [x_all(j+2); y_all(j+2); z_abs(j+2)] - [x_all(j+1); y_all(j+1); z_abs(j+1)];
             if nnz(segment2) ~= 0
                 break;
             end
        end

        heading_angle = atan2(norm(cross(segment1, segment2)), dot(segment1, segment2));
        heading_angle = abs(heading_angle) / pi;
        n4 = n4 + 1;
        J4 = J4 + abs(heading_angle);
    end
    J4 = J4 / n4;

    cost = [J1; J2; J3; J4];
end