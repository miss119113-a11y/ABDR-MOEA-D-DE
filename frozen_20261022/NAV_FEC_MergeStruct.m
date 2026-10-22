function out = NAV_FEC_MergeStruct(a, b)
%NAV_FEC_MERGESTRUCT Concatenate particle structs after unifying fields.
%   Retained for the active SPEA2 baseline; canonical source was in the
%   supplied package's legacy helper set.

if nargin < 1 || isempty(a)
    out = b(:);
    return;
end
if nargin < 2 || isempty(b)
    out = a(:);
    return;
end

a = a(:);
b = b(:);
fields = unique([fieldnames(a); fieldnames(b)]);
for k = 1:numel(fields)
    field = fields{k};
    if ~isfield(a, field)
        for i = 1:numel(a)
            a(i).(field) = [];
        end
    end
    if ~isfield(b, field)
        for i = 1:numel(b)
            b(i).(field) = [];
        end
    end
end
out = [a; b];
end