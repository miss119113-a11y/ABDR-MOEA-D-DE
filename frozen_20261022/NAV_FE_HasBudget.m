function tf=NAV_FE_HasBudget()
%NAV_FE_HASBUDGET True when another counted objective evaluation is allowed.
tf=true;
try
    if ~isappdata(0,'NAV_FE_LIMIT'),return;end
    limit=double(getappdata(0,'NAV_FE_LIMIT'));
    evaluated=0;
    if isappdata(0,'NAV_FE_EVALUATED')
        evaluated=double(getappdata(0,'NAV_FE_EVALUATED'));
    end
    tf=~isfinite(limit) || evaluated<limit;
catch
    tf=true;
end
end