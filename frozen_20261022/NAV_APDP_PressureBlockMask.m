function mask = NAV_APDP_PressureBlockMask(objectiveRanks,nVar)
%NAV_APDP_PRESSUREBLOCKMASK Select a native navigation block from pressure.
%   OBJECTIVERANKS contains one rank per minimization objective; a larger
%   rank means poorer current standing.  The lowest objective index resolves
%   ties deterministically.  The navigation vector is [r, phi, psi].
%
%   F1 -> r, F2 -> phi, F3 -> psi, F4 -> [phi psi].  This mapping is a
%   task-specific APB definition and has no tunable threshold or weight.

validateattributes(objectiveRanks,{'numeric'}, ...
    {'vector','numel',4,'real','finite'});
validateattributes(nVar,{'numeric'},{'scalar','integer','positive','finite'});

ranks = double(objectiveRanks(:)');
[~,objective] = max(ranks); % MATLAB returns the first maximum on ties.
mask = false(1,3*nVar);
switch objective
    case 1
        mask(1:nVar) = true;
    case 2
        mask(nVar+1:2*nVar) = true;
    case 3
        mask(2*nVar+1:3*nVar) = true;
    case 4
        mask(nVar+1:3*nVar) = true;
    otherwise
        error('APDP:PressureObjective','Unexpected pressure objective.');
end
end
