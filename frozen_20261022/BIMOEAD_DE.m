function [rep, best, history] = BIMOEAD_DE(params)
% BIMOEAD_DE Standard drop-in entry point for BIDR-MOEA/D-DE.
%   Wraps the core BIDR_CHAMPION_ENGINE with full parameter verification.
%
% Usage:
%   [rep, best, history] = BIMOEAD_DE(params);
%
% Algorithm: BIDR-MOEA/D-DE (Frozen Champion 2026-10-22)
% Features:
%   - Autonomous SHDE with Maximum-Entropy Uniform Spectrum Memory
%     M_CR^{(0)} = [0.10, 0.30, 0.50, 0.70, 0.90], p_h^{(0)} = 0.20
%   - Dynamic Probability Feedback based on Normalized Objective Improvement
%   - Direction-Conditioned Replacement (DQR) with Topological Neighborhood T=6
%   - Active Population-wise Block Inheritance (APB)

if nargin < 1, params = struct(); end
[rep, best, history] = BIDR_CHAMPION_ENGINE(params);
end
