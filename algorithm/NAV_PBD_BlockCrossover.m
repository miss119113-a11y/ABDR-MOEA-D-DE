function [child,mask] = NAV_PBD_BlockCrossover(parent,donor,pressureObjective,CR)
% Block Inheritance for navigation vector [r,phi,psi].
% F1 -> r
% F2 -> r + phi
% F3 -> r + psi
% F4 -> phi + psi

validateattributes(parent,{'numeric'},{'vector','real','finite'});
validateattributes(donor,{'numeric'},{'vector','real','finite','numel',numel(parent)});
validateattributes(pressureObjective,{'numeric'},{'scalar','integer','>=',1,'<=',4});
validateattributes(CR,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});

parent = double(parent(:)');
donor = double(donor(:)');
assert(mod(numel(parent),3)==0,'BI:Vector','Decision vector must be [r,phi,psi].');
n = numel(parent)/3;

mask = rand(1,numel(parent)) < CR;
randi(numel(parent)); % retained for random-stream parity

switch double(pressureObjective)
    case 1
        block = 1:n;
    case 2
        block = [1:n,n+1:2*n];
    case 3
        block = [1:n,2*n+1:3*n];
    case 4
        block = n+1:3*n;
end

mask(block) = true;
child = parent;
child(mask) = donor(mask);
end
