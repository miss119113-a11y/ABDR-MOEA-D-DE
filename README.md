# BI-MOEA/D for 3-D UAV Path Planning

Private working repository for the manuscript:

**A Structure-Aware MOEA/D with Block Inheritance for Three-Dimensional UAV Path Planning**

## Repository scope

This private snapshot intentionally contains only the paper method itself and the main experiment entry. It does **not** contain comparator algorithms, full ablation suites, transfer-terrain batches, runtime batches, PX4/Gazebo scripts, or the complete paper-result archive.

## Included code

- `BI_MOEAD_UAV.m` — paper-facing entry point.
- `algorithm/NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV.m` — frozen paper-method switch/configuration.
- `algorithm/BI_MOEAD_Core.m` — compact main search core implementing local-guide selection, current-to-local-best/1 differential mutation, objective-pressure routing, BI, DCR, and success-history DE adaptation.
- `algorithm/NAV_PBD_BlockCrossover.m` — Block Inheritance operator.
- `algorithm/NAV_GenerateWeights.m` — fixed nonuniform reference-direction construction used by the method.
- `experiment/RUN_MAIN_BIMOEAD_EXACT6000.m` — main S1–S4, 30-run, Exact-6000 experiment driver for BI-MOEA/D only.

## Main manuscript settings

- Population size: 30
- Intermediate navigation nodes: 10
- Decision dimension: 30
- Search-stage budget: 6000 complete path evaluations
- Neighborhood size: 6
- Success-history memories initialized at M_F = M_CR = 0.5
- Gaussian sampling standard deviation: 0.1
- External archive capacity: 30
- Archive grid divisions: 7
- Archive refresh stride: 4 generations

The 30 shared initial solutions are evaluated inside the 6000-evaluation search-stage budget.

## Intentionally omitted from this private snapshot

The UAV geometry/evaluator, terrain files, shared feasible-pool builder, comparison methods, complete statistical post-processing, ablation/transfer/runtime/PX4 experiment suites, and raw result archives are intentionally not uploaded here yet.

## Status

**Private / not for public release yet.**

No public license is attached at this stage. The complete reproducibility dependencies can be added when the authors are ready for public release.
