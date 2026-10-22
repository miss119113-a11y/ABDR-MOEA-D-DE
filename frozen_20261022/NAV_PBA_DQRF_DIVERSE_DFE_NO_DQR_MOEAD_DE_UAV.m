function [rep,best,history] = NAV_PBA_DQRF_DIVERSE_DFE_NO_DQR_MOEAD_DE_UAV(params)
%NAV_PBA_DQRF_DIVERSE_DFE_NO_DQR_MOEAD_DE_UAV Final-consistent no-DQR ablation.
%   This entry is identical to PBA-DQRF-DIVERSE-DFE except that DQR is
%   disabled. DQRMode intentionally remains 'fallback' so EnableDQR is the
%   only changed configuration field relative to the full method.
if nargin < 1 || isempty(params), params = struct(); end
params.EnableAPB = true;
params.EnableDQR = false;                 % ONLY search-mechanism removal
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
history.Algorithm = 'PBA-DQRF-DIVERSE-DFE-NO-DQR';
history.PaperMethod = history.Algorithm;
history.CandidateVersion = 'PBA-DQRF-DIVERSE-DFE-NO-DQR-20260816';
history.StrictAblationOf = 'PBA-DQRF-DIVERSE-DFE';
history.RemovedMechanism = 'DQR';
history.CoreMechanisms = 'PBB + Success-History DE';
history.ArchivePolicy = 'grid-crowding';
history.ImplementationNotes = 'Direct Physical FE + WeightCache';
history.Mechanism = history.CoreMechanisms;
history.PBB = true;
history.EnableAPB = true;
history.AdaptiveDE = true;
history.EnableDQR = false;
history.DQR = false;
history.DQRMode = 'fallback';
history.DirectPhysicalFE = true;
history.FastDonorSampling = false;
end
