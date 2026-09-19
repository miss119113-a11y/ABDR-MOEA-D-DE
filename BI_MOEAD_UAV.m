function [archive,best,history] = BI_MOEAD_UAV(params)
%BI_MOEAD_UAV Paper-facing entry point for the proposed method.
[archive,best,history] = NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV(params);
end
