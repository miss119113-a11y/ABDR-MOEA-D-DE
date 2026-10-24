# ABDR-MOEA/D-DE

**Parameter-Adaptive Multiobjective Evolutionary Algorithm Based on Decomposition With Differential Evolution, Block Inheritance, and Direction-Quota Replacement for Constrained UAV Path Planning**

This repository contains the MATLAB implementation of **ABDR-MOEA/D-DE**, experiment scripts, numerical results, and three terrain digital elevation models (DEMs) for constrained 3-D multiobjective UAV path planning.

## Method

ABDR-MOEA/D-DE combines three mechanisms in a decomposition-based differential evolution framework:

- **Block Inheritance (BI):** jointly inherits physically related navigation-variable groups for segment extension, horizontal steering, and climb.
- **Direction-Quota Replacement (DQR):** associates feasible offspring with decomposition directions and limits repeated replacement of the same direction within a generation.
- **Multi-memory SHDE:** adapts differential-evolution mutation and crossover parameters from successful search improvements.

The problem minimizes route inefficiency, threat exposure, terrain-relative altitude deviation, and trajectory smoothness, subject to flight and safety constraints.

## Repository layout

| Folder | Contents |
|---|---|
| [algorithm/](algorithm/) | Current ABDR-MOEA/D-DE MATLAB algorithm and required helper functions |
| [experiments/](experiments/) | Algorithm configuration, experiment runners, and result-checking scripts |
| [results/](results/) | Main comparison, mechanism ablation, runtime, external-terrain and PX4 simulation outcomes (E01–E06) |
| [maps/](maps/) | Christmas Island, Crater Lake and Mount St. Helens DEM GeoTIFFs (compressed archive with automatic extraction) |

Only the proposed optimizer is distributed. Comparison-method results are provided as data; comparator source codes are not included.

## Quick start

**Requirements:** MATLAB R2024b (the version used for the experiments), Python 3 to extract DEMs and check CSV records.

Extract the three terrain maps after cloning:

```bash
python maps/extract_maps.py
python experiments/ABDR_Verify_Results.py
```

Then start MATLAB from the repository root:

```matlab
addpath('algorithm','algorithm/core','experiments','maps/terrain');
p = ABDR_Config(260825101);
[archive, best, history] = ABDR_MOEAD_DE(p);
```

For the exact paper-style experiment runner, provide the corresponding common feasible initialization pools (and reference fronts when computing IGD+):

```matlab
opts.PoolDir = 'PATH_TO_SHARED_POOLS';
opts.OutputDir = 'PATH_TO_OUTPUT';
T = ABDR_Run_Experiments('main', opts);
```

The standard experimental budget is **6000 objective-function evaluations**, with **30 independent runs** per scenario. See [experiments/README.md](experiments/README.md) and [results/README.md](results/README.md) for details.

## Experimental results

**Manuscript tables (Tables 2–9):** [paper-format CSV tables](results/paper_tables/) reproduce the values, significance symbols, and summary counts printed in the submitted IEEE Access manuscript. Full-precision per-run/mission records are retained below.


The `results/` directory provides original recorded metrics for E01–E06:

| Experiment | Coverage |
|---|---|
| E01: main comparison | 11 methods; 4 scenarios; 1320 records |
| E02: ablation | 8 settings; 4 scenarios; 960 records |
| E03: serial runtime | 11 methods; 4 scenarios; 1320 records |
| E04: Crater Lake | 6 methods; 12 scenarios; 2160 records |
| E05: Mount St. Helens | 6 methods; 12 scenarios; 2160 records |
| E06: PX4–Gazebo SITL | 6 methods; 120 missions |

The associated manuscript is under submission to *IEEE Access*. The present repository distributes the proposed MATLAB algorithm, experiments and numerical results for academic inspection; no comparator implementation is included.
