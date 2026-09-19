function [rep,best,history] = NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV(params)
% Frozen paper-method configuration for BI-MOEA/D.
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

[rep,best,history] = BI_MOEAD_Core(params);

history.Algorithm = 'BI-MOEA/D';
history.CoreMechanisms = 'Block Inheritance + Direction-Compatible Replacement';
history.AdaptiveDE = true;
history.EnableDQR = true;
end
