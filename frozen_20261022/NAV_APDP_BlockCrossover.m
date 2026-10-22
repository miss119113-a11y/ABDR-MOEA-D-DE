function [child,mask] = NAV_APDP_BlockCrossover(parent,donor,pressureObjective,CR)
%NAV_APDP_BLOCKCROSSOVER APB crossover with one forced physical block.
%   The selected F1/F2/F3/F4 pressure objective forces the corresponding
%   native decision block from DONOR; every remaining coordinate follows
%   ordinary binomial crossover at CR.  One random index is sampled even
%   under APB so ablation variants consume an aligned random draw.

validateattributes(parent,{'numeric'},{'vector','real','finite'});
validateattributes(donor,{'numeric'},{'vector','real','finite','numel',numel(parent)});
validateattributes(pressureObjective,{'numeric'}, ...
    {'scalar','integer','>=',1,'<=',4,'finite'});
validateattributes(CR,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});

parent = double(parent(:)');
donor = double(donor(:)');
assert(mod(numel(parent),3)==0 && numel(parent)>=3, ...
    'APDP:BlockVector','The navigation vector must have three equal blocks.');
nVar = numel(parent)/3;
mask = rand(1,numel(parent)) < CR;
unusedForcedIndex = randi(numel(parent)); %#ok<NASGU>
block = NAV_APDP_PressureBlockMask( ...
    double(pressureObjective==1:4),nVar);
mask(block) = true;
child = parent;
child(mask) = donor(mask);
end
