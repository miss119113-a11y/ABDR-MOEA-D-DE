function [child,mask] = NAV_PBD_BlockCrossover(parent,donor,pressureObjective,CR)
%NAV_PBD_BLOCKCROSSOVER Pressure-based block recombination for PBD-MOEA/D.
%   The navigation vector is [r,phi,psi].  The selected pressure objective
%   forces the physically coupled decision blocks that can directly change
%   that objective:
%     F1 path efficiency  -> r
%     F2 threat exposure   -> r + phi (horizontal reach and heading)
%     F3 altitude deviation-> r + psi (segment reach and climb)
%     F4 turning           -> phi + psi (heading and climb changes)
%   The mapping is kinematic, contains no fitted threshold, and changes only
%   the crossover mask.  One random index is consumed in every call so the
%   parent and PBD ablation streams remain aligned.

validateattributes(parent,{'numeric'},{'vector','real','finite'});
validateattributes(donor,{'numeric'},{'vector','real','finite','numel',numel(parent)});
validateattributes(pressureObjective,{'numeric'}, ...
    {'scalar','integer','>=',1,'<=',4,'finite'});
validateattributes(CR,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});

parent = double(parent(:)');
donor = double(donor(:)');
assert(mod(numel(parent),3)==0 && numel(parent)>=3, ...
    'PBD:BlockVector','The navigation vector must have three equal blocks.');
nVar = numel(parent)/3;
mask = rand(1,numel(parent)) < CR;
unusedForcedIndex = randi(numel(parent)); %#ok<NASGU>

switch double(pressureObjective)
    case 1
        block = 1:nVar;
    case 2
        block = [1:nVar, nVar+1:2*nVar];
    case 3
        block = [1:nVar, 2*nVar+1:3*nVar];
    case 4
        block = nVar+1:3*nVar;
    otherwise
        error('PBD:PressureObjective','Unexpected pressure objective.');
end
mask(block) = true;
child = parent;
child(mask) = donor(mask);
end
