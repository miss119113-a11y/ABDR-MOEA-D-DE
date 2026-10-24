function [rep,best,history] = ABDR_MOEAD_DE(params)
%ABDR_MOEAD_DE Proposed MATLAB multiobjective UAV path planner.
%   [rep,best,history] = ABDR_MOEAD_DE(params)
%   Uses the complete BI + DQR + multi-memory SHDE implementation.
if nargin < 1 || isempty(params), params=struct(); end
[rep,best,history] = ABDR_MOEAD_DE_ENGINE(params);
end
