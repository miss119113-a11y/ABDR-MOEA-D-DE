function [child,mask] = NAV_PBD_BlockCrossoverFast(parent,donor,pressureObjective,CR,forcedMasks)
%NAV_PBD_BLOCKCROSSOVERFAST Fast parity path for coupled PBD recombination.
%   This function intentionally keeps the random-call order of
%   NAV_PBD_BlockCrossover: one binomial mask draw followed by one randi
%   draw.  The second draw is retained for stream parity with the legacy
%   operator even though the coupled pressure block is forced explicitly.
%   Inputs are trusted internal optimizer vectors; the slower public
%   operator remains available for validation and unit tests.

parent = double(parent(:)');
donor = double(donor(:)');
nVar = numel(parent)/3;
mask = rand(1,numel(parent)) < CR;
unusedForcedIndex = randi(numel(parent)); %#ok<NASGU>

if nargin >= 5 && ~isempty(forcedMasks)
    % Cache deterministic physical block masks once per run. The random
    % draws above remain in the same order as the original fast operator.
    mask = mask | logical(forcedMasks(double(pressureObjective),:));
else
    switch double(pressureObjective)
        case 1
            block = 1:nVar;
        case 2
            block = [1:nVar,nVar+1:2*nVar];
        case 3
            block = [1:nVar,2*nVar+1:3*nVar];
        case 4
            block = nVar+1:3*nVar;
        otherwise
            error('PBD:PressureObjective','Unexpected pressure objective.');
    end
    mask(block) = true;
end
child = parent;
child(mask) = donor(mask);
end