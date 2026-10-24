# ABDR-MOEA/D-DE MATLAB algorithm

**Entry point:** `ABDR_MOEAD_DE.m`

**Core optimizer:** `ABDR_MOEAD_DE_ENGINE.m`

**Dependencies:** MATLAB helper routines in `core/`. These are objective/constraint evaluators, geometric and Pareto operations, and functions for BI, DQR and SHDE. No comparison-method optimizers are included.

To use from MATLAB:
```matlab
addpath('algorithm');
addpath('algorithm/core');
p = ABDR_Config(260825101);  % after adding experiments/ to path
[archive,best,history] = ABDR_MOEAD_DE(p);
```

Configure `NAV_COST_MODE`, `NAV_SCENARIO_ID`, the FE budget, terrain input and shared feasible initialization pool as described in [../experiments/README.md](../experiments/README.md). A direct optimizer call without environment configuration is **not** a paper-exact replication.

The source uses a single final search engine with coupled BI, DQR and SHDE controls. Internal helper names retained by MATLAB for functional compatibility are not independent algorithms.
