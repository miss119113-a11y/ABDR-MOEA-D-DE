function [rep,best,history] = NAV_R55_FULL_MOEAD_DE_UAV(params)
%NAV_R55_FULL_MOEAD_DE_UAV R5.5 strict 2x2 core-mechanism ablation wrapper.
% Full: PBB on, DQR on.
% Every non-PBB/DQR setting is deliberately identical across all four variants.
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
history.Algorithm = 'PDMOEA/D';
history.PaperMethod = 'PDMOEA/D';
history.R55CoreAblation = true;
history.PBB = true;
history.EnableAPB = true;
history.EnableDQR = true;
history.DQR = true;
history.DQRMode = 'fallback';
history.AdaptiveDE = true;
history.CoreMechanisms = 'PBB + DQR';
history.AuxiliaryAdaptation = 'Success-History DE fixed ON in every R5.5 ablation variant';
history.ReferenceGeometry = 'same application-informed balanced reference directions for all variants';
end
