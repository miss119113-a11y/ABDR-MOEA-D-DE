function optimizer = NAV_PaperMethodHandle(method)
%NAV_PAPERMETHODHANDLE Resolve only retained paper and audit optimizers.
%   The active registry deliberately excludes rejected development variants.
%   MOGWO remains available solely to reproduce the frozen Exact-2000
%   historical studies; it is not part of the current paper Main-5.
%   MOEA/D-STM is the retained A1 framework baseline implemented under the
%   AMM publication experiment support tree.

key = upper(strtrim(char(string(method))));
switch key
    case 'PDMOEA/D'
        optimizer = @NAV_PDMOEAD_UAV;
    case 'PBA-DQRF-DIVERSE-DFE'
        optimizer = @NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV;
    case 'PBA-DQRF-DIVERSE-DFE-NO-PBB'
        optimizer = @NAV_PBA_DQRF_DIVERSE_DFE_NO_PBB_MOEAD_DE_UAV;
    case 'PBA-DQRF-DIVERSE-DFE-NO-DQR'
        optimizer = @NAV_PBA_DQRF_DIVERSE_DFE_NO_DQR_MOEAD_DE_UAV;
    case 'PBA-DQRF-DIVERSE-DFE-NO-SHDE'
        optimizer = @NAV_PBA_DQRF_DIVERSE_DFE_NO_SHDE_MOEAD_DE_UAV;
    case 'ECDE-2025'
        optimizer = @ECDE_2025_UAV_Baseline;
    case 'NMOPSO'
        optimizer = @NMOPSO_Baseline_Function;
    case 'SPEA2'
        optimizer = @NAV_SPEA2_UAV;
    case 'NSGA-III'
        optimizer = @NAV_NSGAIII_UAV;
    case {'MOEA/D','MOEA/D-DE'}
        optimizer = @NAV_MOEAD_DE_UAV;
    case 'MOEA/D-AWA'
        optimizer = @NAV_MOEAD_AWA_UAV;
    case 'MOEA-2DE'
        optimizer = @NAV_MOEA2DE_UAV;
    case 'MOEA/D-STM'
        optimizer = @NAV_MOEAD_STM_UAV;
    case 'MOGWO'
        optimizer = @NAV_MOGWO_UAV;
    case {'TOP', 'TOP-2023'}
        optimizer = @TOP_2023_UAV_Baseline;
    case {'MOEAD-UR', 'MOEA/D-UR', 'MOEAD_UR', 'MOEAD-UR-2021', 'MOEA/D-UR-2021'}
        optimizer = @MOEAD_UR_2021_UAV_Baseline;
    otherwise
        sensitivityPattern = ...
            '^PBA-DQRF-DIVERSE-DFE-(G\d{2}(-T\d{2})?|N\d{2})$';
        if ~isempty(regexp(key,sensitivityPattern,'once')) %#ok<RGXP1>
            % Registered parameter-sensitivity labels share the frozen full
            % implementation and differ only through ParamOverrides.
            optimizer = @NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV;
        else
            error('PDMOEAD:RetiredOrUnknownMethod', ...
                'Method %s is not in the retained paper registry.',method);
        end
end
end