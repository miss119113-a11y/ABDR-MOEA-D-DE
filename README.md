# BI-MOEA/D for 3-D UAV Path Planning

Private working repository for the manuscript:

**A Structure-Aware MOEA/D with Block Inheritance for Three-Dimensional UAV Path Planning**

## Repository scope

This private snapshot intentionally contains only:

- the proposed BI-MOEA/D main algorithm;
- the Block Inheritance (BI) implementation;
- the Direction-Compatible Replacement (DCR) logic embedded in the main MOEA/D-DE engine;
- the main Exact-6000 experiment driver.

Comparator implementations, full ablation suites, external-DEM experiments, runtime batches, PX4/Gazebo scripts, and complete paper-result archives are intentionally excluded.

## Paper-to-code mapping

- `BI_MOEAD_UAV.m`: paper-facing entry point.
- `algorithm/NAV_PBA_DQRF_DIVERSE_DFE_MOEAD_DE_UAV.m`: frozen paper-method configuration.
- `algorithm/NAV_APDP_MOEAD_DE_UAV.m`: main MOEA/D-DE search engine containing local-guide selection, DE donor construction, objective-pressure calculation, success-history DE control, and DCR replacement.
- `algorithm/NAV_PBD_BlockCrossover.m`: BI crossover implementation.
- `algorithm/NAV_PBD_BlockCrossoverFast.m`: equivalent cached BI implementation used by the frozen fast search path.
- `experiment/RUN_MAIN_BIMOEAD_EXACT6000.m`: primary S1-S4 / 30-run / Exact-6000 experiment driver.

Historical internal MATLAB function names are retained to preserve consistency with the frozen manuscript experiments.

## Main manuscript settings

- Population size: 30
- Intermediate navigation nodes: 10
- Decision dimension: 30
- Search-stage budget: 6000 complete path evaluations
- BI-MOEA/D neighborhood size: 6
- Initial success-history memories: M_F = M_CR = 0.5
- Gaussian sampling standard deviation: 0.1
- External archive capacity: 30
- Archive grid divisions: 7
- Archive refresh stride: 4 generations

The 30 shared initial solutions are evaluated inside the 6000-evaluation search-stage budget.

## Status

**Private / not for public release yet.**

No public license is attached at this stage. Supporting evaluator/model files, terrain data, and the complete reproducibility package can be added before public release.
