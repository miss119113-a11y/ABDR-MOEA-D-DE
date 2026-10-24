# Experiment scripts

This directory includes MATLAB experiment routines for the proposed ABDR-MOEA/D-DE and scripts that inspect its archived numerical results.

| File | Purpose |
|---|---|
| `ABDR_Config.m` | Proposed-method parameters and mechanism switches |
| `ABDR_Run_One.m` | Execute one proposed-method task with the 6000-FE budget |
| `ABDR_Run_Experiments.m` | Batch runners for main comparisons, ablation, timing, and external terrains |
| `ABDR_Review_Results.m` | Recalculate mean and SD of stored optimization outcomes |
| `ABDR_Review_PX4.m` | Review the 120 archived PX4 mission records |
| `ABDR_Verify_Results.py` | Verify archived E01–E06 record counts and statistics |

Unpack the maps with `python maps/extract_maps.py` before running MATLAB. The main scenario data use the supplied Christmas Island TIFF, while external-terrain runs require their corresponding TIFF files.

```matlab
addpath('algorithm','algorithm/core','experiments','maps/terrain');
opts.PoolDir = 'PATH_TO_SHARED_INITIAL_POOLS';
opts.OutputDir = 'PATH_TO_OUTPUT';
T = ABDR_Run_Experiments('main', opts);
```

Other experiment modes: `ablation`, `runtime`, `crater`, `mount`. Original shared feasible initialization pools and reference fronts are not included in this distribution. No competing algorithm source code or complete PX4/Gazebo installation is included.

To inspect the provided recorded data without MATLAB:

```bash
python experiments/ABDR_Verify_Results.py
```
