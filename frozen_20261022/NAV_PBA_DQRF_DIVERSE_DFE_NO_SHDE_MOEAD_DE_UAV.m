function [rep,best,history] = NAV_PBA_DQRF_DIVERSE_DFE_NO_SHDE_MOEAD_DE_UAV(params)
%NAV_PBA_DQRF_DIVERSE_DFE_NO_SHDE_MOEAD_DE_UAV Final-consistent no-SHDE ablation.
%   This entry is identical to PBA-DQRF-DIVERSE-DFE except that
%   Success-History DE parameter adaptation is disabled.
if nargin < 1 || isempty(params), params = struct(); end
params.EnableAPB = true;
params.EnableDQR = true;
params.DQRMode = 'fallback';
params.AdaptiveDE = false;                % ONLY search-mechanism removal
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
history.Algorithm = 'PBA-DQRF-DIVERSE-DFE-NO-SHDE';
history.PaperMethod = history.Algorithm;
history.CandidateVersion = 'PBA-DQRF-DIVERSE-DFE-NO-SHDE-20260816';
history.StrictAblationOf = 'PBA-DQRF-DIVERSE-DFE';
history.RemovedMechanism = 'Success-History DE';
history.CoreMechanisms = 'PBB + deterministic fallback DQR';
history.ArchivePolicy = 'grid-crowding';
history.ImplementationNotes = 'Direct Physical FE + WeightCache';
history.Mechanism = history.CoreMechanisms;
history.PBB = true;
history.EnableAPB = true;
history.AdaptiveDE = false;
history.EnableDQR = true;
history.DQR = true;
history.DQRMode = 'fallback';
history.DirectPhysicalFE = true;
history.FastDonorSampling = false;
end
