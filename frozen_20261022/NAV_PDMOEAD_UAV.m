function [rep,best,history] = NAV_PDMOEAD_UAV(params)
%NAV_PDMOEAD_UAV Paper-name entry for the frozen proposed method.
%   PDMOEA/D is the concise paper label for the frozen
%   PBA-DQRF-DIVERSE-DFE implementation. Search behavior is unchanged.
if nargin < 1 || isempty(params), params = struct(); end
[rep,best,history] = NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV(params);
history.InternalAlgorithm = 'PBA-DQRF-DIVERSE-DFE';
history.Algorithm = 'PDMOEA/D';
history.PaperMethod = 'PDMOEA/D';
history.PaperNameAliasOnly = true;
end
