function rep = NAV_FEC_UniqueFinite(rep)
%NAV_FEC_UNIQUEFINITE Remove non-finite and duplicate archive members.
    if isempty(rep), return; end
    keep=false(numel(rep),1);
    for i=1:numel(rep)
        keep(i)=isfield(rep(i),'Cost') && ~isempty(rep(i).Cost) && all(isfinite(rep(i).Cost));
    end
    rep=rep(keep);
    if isempty(rep), return; end
    keys=strings(numel(rep),1);
    for i=1:numel(rep)
        c=rep(i).Cost(:)';
        if isfield(rep(i),'Vector') && ~isempty(rep(i).Vector)
            v=rep(i).Vector(:)';
            keys(i)=sprintf('C:%s|V:%s', sprintf('%.10g,',c), sprintf('%.6g,',v));
        else
            keys(i)=sprintf('C:%s', sprintf('%.10g,',c));
        end
    end
    [~,ia]=unique(keys,'stable');
    rep=rep(sort(ia));
end
