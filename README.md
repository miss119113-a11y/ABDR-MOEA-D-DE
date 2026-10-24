# ABDR-MOEA/D-DE

MATLAB source code, experiment runners, and numerical results for constrained multiobjective UAV path planning.

## Repository contents

| Folder | Contents |
|---|---|
| [algorithm/](algorithm/) | The proposed ABDR-MOEA/D-DE optimizer, entry point, engine, and required MATLAB helper functions. |
| [experiments/](experiments/) | MATLAB configuration, proposed-method experiment runners, data review and validation scripts. |
| [results/](results/) | E01–E06 paper experiment CSVs and accompanying summary statistics. |

**No implementations of competing optimizers are included.** Benchmark CSV files contain their measured results, not their source code.

## Validate the uploaded results

Python 3 (standard library only):

```bash
python experiments/ABDR_Verify_Results.py
```

## Run the proposed algorithm

MATLAB R2024b:

```matlab
addpath('algorithm', 'algorithm/core', 'experiments');
opts.PoolDir = 'PATH_TO_SHARED_INITIAL_POOLS';
opts.OutputDir = 'PATH_TO_NEW_OUTPUT';
T = ABDR_Run_Experiments('main',opts);
```

The reported protocol uses a population of 30, a 6000-function-evaluation cap and 30 repetitions per scenario. See [experiment instructions](experiments/README.md) before running other tasks.

## Data

The six result tables cover an 11-method main comparison (1320 records), eight-setting ablation (960), serial runtime (1320), two external terrains (2160 records each), and PX4–Gazebo SITL (120 missions). See [results/README.md](results/README.md).

Saved numerical values and recorded mission outcome flags have not been changed in this repository reorganization. The external-terrain numerical records include an earlier H5-controller cohort; the PX4 data contain separately identified flight cohorts. Do not treat a stored result as a newly executed run of the present source.

Shared original initialization pools, external DEM rasters, frozen reference-front binaries, and raw PX4 ULogs are not distributed. The provided runners execute only our method, while the CSV tables preserve the published comparisons.
