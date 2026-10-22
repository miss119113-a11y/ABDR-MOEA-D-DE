function epsRisk = NAV_RiskEpsilon(params, it)
    t = it / max(params.MaxIt, 1);
    epsRisk = params.riskEpsFinal + (params.riskEps0 - params.riskEpsFinal) * (1 - t)^2;
end
