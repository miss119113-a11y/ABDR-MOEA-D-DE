# MATLAB experiment scripts and validation

| File | Purpose |
|---|---|
| `ABDR_Config.m` | Current optimizer settings |
| `ABDR_Run_One.m` | One proposed-method run with exact FE budget |
| `ABDR_Run_Experiments.m` | Four main scenarios, eight ablation variants, runtime, or external DEM tests |
| `ABDR_Review_Results.m` | Means/SD of stored optimization results |
| `ABDR_Review_PX4.m` | Reads the corrected E06 paper mission cohort and reports completion, tracking, safety and mean metrics |
| `ABDR_Verify_Results.py` | Checks paper result counts, group sizes and PX4 against saved summaries |
| `ABDR_Extract_PX4.py` | Extracts paper-matched PX4 gzip CSV into ordinary CSV |

Run:
```bash
python experiments/ABDR_Verify_Results.py
python experiments/ABDR_Extract_PX4.py
```
MATLAB R2024b:
```matlab
addpath('experiments','algorithm','algorithm/core');
opts.PoolDir='PATH_TO_ORIGINAL_SHARED_POOLS';
opts.OutputDir='PATH_TO_OUTPUT';
T=ABDR_Run_Experiments('main',opts);
S=ABDR_Review_PX4();
```
Other tasks are `'ablation'`, `'runtime'`, `'crater'`, and `'mount'`. External terrain runs require source-matched terrain files and scenario definitions. These scripts do not include third-party algorithm implementations or a complete PX4/Gazebo simulator.
