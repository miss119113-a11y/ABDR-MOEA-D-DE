function [rep,best,history] = NAV_PBA_DQRF_DIVERSE_DFE_NO_PBB_MOEAD_DE_UAV(params)
%NAV_PBA_DQRF_DIVERSE_DFE_NO_PBB_MOEAD_DE_UAV Final-consistent no-PBB ablation.
%   This entry is identical to PBA-DQRF-DIVERSE-DFE except that the
%   pressure-based block (PBB; legacy parameter name EnableAPB) is disabled.
if nargin < 1 || isempty(params), params = struct(); end
params.EnableAPB = false;                 % ONLY search-mechanism removal
params.EnableDQR = true;
params.DQRMode = 'fallback';
params.AdaptiveDE = true;
params.PressureMap = 'coupled';
params.NormalizeDecomposition = false;
params.FastSearchPath = true;
params.UseWeightCache = true;
params.ArchiveDiversityMode = 'grid-crowding';
if ~isfield(params,'ArchiveGridDivisions') || isempty(params.ArchiveGridDivisions)
    params.ArchiveGridDivisions = 7;
end
params.DirectPhysicalFE = true;
params.FastDonorSampling = false;
[rep,best,history] = NAV_APDP_MOEAD_DE_UAV(params);
history.Algorithm = 'PBA-DQRF-DIVERSE-DFE-NO-PBB';
history.PaperMethod = history.Algorithm;
history.CandidateVersion = 'PBA-DQRF-DIVERSE-DFE-NO-PBB-20260816';
history.StrictAblationOf = 'PBA-DQRF-DIVERSE-DFE';
history.RemovedMechanism = 'PBB';
history.CoreMechanisms = 'Success-History DE + deterministic fallback DQR';
history.ArchivePolicy = 'grid-crowding';
history.ImplementationNotes = 'Direct Physical FE + WeightCache';
history.Mechanism = history.CoreMechanisms;
history.PBB = false;
history.EnableAPB = false;
history.AdaptiveDE = true;
history.EnableDQR = true;
history.DQR = true;
history.DQRMode = 'fallback';
history.DirectPhysicalFE = true;
history.FastDonorSampling = false;
end
