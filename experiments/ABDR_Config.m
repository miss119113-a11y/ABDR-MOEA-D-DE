function p = ABDR_Config(seed)
%ABDR_CONFIG Final full-method configuration for exact-6000 runs.
if nargin < 1, seed = 260825101; end
p = struct('Seed',seed,'nPop',30,'nRep',30,'MaxIt',200, ...
    'nGrid',7,'alpha',0.1,'beta',2,'gamma',2, ...
    'reportWeights',[1 1 1 1],'StoreConvergenceHistory',false, ...
    'verbose',false,'delta',5,'fixMutation',true, ...
    'usePaperMutationGain',true,'HistoryStride',100);
p = NAV_DefaultParams(p);
p.repairProb = 0;
p.guidedInitRatio = 0.45;
p.initMaxTry = 80;
p.EnableAPB = true;
p.EnableDQR = true;
p.AdaptiveDE = true;
p.MultiMemoryCR = true;
p.DQRMode = 'fallback';
p.ControllerMode = 'GLOBAL_H5_FIR_CR_ARITH';
p.ControllerH = 5;
p.ControllerAlphaP = 0.25;
p.ControllerPMin = 0.05;
p.deF = 0.5;
p.deCR = 0.5;
p.neighborSize = 6;
p.T = 6;
p.PressureMap = 'coupled';
p.ArchiveDiversityMode = 'grid-crowding';
p.ArchiveGridDivisions = 7;
p.NormalizeDecomposition = false;
p.MatingScope = 'staged';
p.FastSearchPath = true;
p.DirectPhysicalFE = true;
p.UseWeightCache = true;
p.FastDonorSampling = false;
p.archiveStride = 1;
p.CodexArchiveGuide = true;
p.TriadPBB = true;
end
