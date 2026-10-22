function costs = NAV_ArchiveCostMatrix(archive)
%NAV_ARCHIVECOSTMATRIX Extract finite objective vectors from an archive.

costs = zeros(0,4);
if isempty(archive) || ~isstruct(archive) || ~isfield(archive,'Cost')
    return;
end

rows = cell(numel(archive),1);
for i = 1:numel(archive)
    value = archive(i).Cost;
    if isempty(value) || ~isnumeric(value)
        continue;
    end
    value = double(value(:)');
    if numel(value) < 4 || any(~isfinite(value(1:4)))
        continue;
    end
    rows{i} = value(1:4);
end
rows = rows(~cellfun('isempty',rows));
if isempty(rows)
    return;
end
costs = vertcat(rows{:});
costs = NAV_Q2_Nondominated(costs);
end
