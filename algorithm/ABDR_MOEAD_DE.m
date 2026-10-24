function [rep,best,history] = ABDR_MOEAD_DE(params)
%ABDR_MOEAD_DE Proposed algorithm entry point.
% The original numerical routines are in ABDR_MOEAD_DE_ENGINE.m.
if nargin < 1 || isempty(params), params = struct(); end
[rep,best,history] = ABDR_MOEAD_DE_ENGINE(params);
end
