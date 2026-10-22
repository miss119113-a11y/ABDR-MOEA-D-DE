function history = NAV_RecordConvergenceHistory(history, iteration, archive)
%NAV_RECORDCONVERGENCEHISTORY Store optional archive snapshots.

if ~isstruct(history) || ~isfield(history,'ArchiveCost')
    return;
end
if iteration < 1 || iteration > numel(history.ArchiveCost)
    return;
end

history.ArchiveCost{iteration} = NAV_ArchiveCostMatrix(archive);
if isfield(history,'FE') && isappdata(0,'NAV_FE_EVALUATED')
    history.FE(iteration) = double(getappdata(0,'NAV_FE_EVALUATED'));
end
if isfield(history,'AttemptedFE') && isappdata(0,'NAV_FE_ATTEMPTED')
    history.AttemptedFE(iteration) = double(getappdata(0,'NAV_FE_ATTEMPTED'));
end
end