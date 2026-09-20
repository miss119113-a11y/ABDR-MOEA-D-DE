# BI-MOEA/D for 3-D UAV Path Planning

Private working repository for the manuscript:

**A Structure-Aware MOEA/D with Block Inheritance for Three-Dimensional UAV Path Planning**

## Repository scope

This repository follows the publication scope used by the NMOPSO paper code repository: it contains the proposed method and the minimum complete engineering components required to run the UAV path-planning method, rather than the full paper experiment suite.

The target contents are:

- BI-MOEA/D main algorithm;
- Block Inheritance (BI) and Direction-Compatible Replacement (DCR);
- success-history DE parameter adaptation used by the frozen method;
- UAV navigation-variable model and path decoding;
- the four-objective evaluator and hard-feasibility checks;
- feasible-solution initialization;
- nondominated archive / decomposition support required by BI-MOEA/D;
- one main MATLAB entry script;
- the terrain data or a reproducible data-acquisition instruction;
- plotting/visualization helpers;
- representative example output;
- README and third-party attribution where required.

## Intentionally excluded

The repository will not contain:

- ECDE, NMOPSO, SPEA2, NSGA-III, MOEA/D-DE, MOEA/D-AWA, MOEA-2DE, or MOEA/D-STM source code;
- the full BI×DCR ablation suite;
- external-DEM transfer batches;
- unified runtime benchmark batches;
- PX4/Gazebo experiment scripts and ULog files;
- the complete statistical post-processing suite;
- large raw result archives.

## Important implementation rule

The public-facing method code must be taken from the frozen manuscript implementation. Historical internal MATLAB function names may be retained when necessary for reproducibility. A compact reimplementation is not a substitute for the frozen source.

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

The 30 shared initial solutions are formally evaluated inside the 6000-evaluation search-stage budget.

## Status

**Private / not for public release yet.**

No public license for the authors' BI-MOEA/D code has been selected at this stage. Any redistributed third-party terrain/data asset must retain its original attribution/license notice.
