function [rep,best,history] = NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV(params)
%NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV Final PBA-DQRF-DIVERSE-DFE entry.
%   The paper-level search contribution is intentionally limited to three
%   coupled operators: (1) the pressure-based block (PBB), (2) Success-
%   History DE parameter adaptation, and (3) fallback directional-quota
%   replacement (DQR).  Grid crowding is an archive-diversity policy; Direct
%   Physical FE and WeightCache are implementation accelerators.  They retain
%   the same accepted-child, initialization and Exact-2000 semantics and are
%   reported separately rather than presented as additional search ideas.
if nargin < 1 || isempty(params), params = struct(); end
params.EnableAPB = true;
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
history.Algorithm = 'PBA-DQRF-DIVERSE-DFE';
history.PaperMethod = history.Algorithm;
history.CandidateVersion = 'PBA-DQRF-DIVERSE-DFE-20260815-WEIGHTCACHE';
history.CoreMechanisms = 'PBB + Success-History DE + fallback DQR';
history.ArchivePolicy = 'grid-crowding';
history.ImplementationNotes = 'Direct Physical FE + WeightCache';
history.Mechanism = history.CoreMechanisms;
history.PBB = true;
history.AdaptiveDE = true;
history.EnableDQR = true;
history.DQR = true;
history.DirectPhysicalFE = true;
history.FastDonorSampling = false;
end