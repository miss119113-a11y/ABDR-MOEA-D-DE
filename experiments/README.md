# Experiment code

The experiment folder contains code for the **proposed ABDR-MOEA/D-DE method** and scripts for reading recorded paper results. No competing algorithm source code is included.

| Script | Function |
|---|---|
| `ABDR_Config.m` | Current proposed-method settings. |
| `ABDR_Run_One.m` | One MATLAB run with an exact 6000-FE requirement. |
| `ABDR_Run_Experiments.m` | Proposed-method main, ablation, runtime or external-terrain runs. |
| `ABDR_Review_Results.m` | Calculate group means and SD from E01 or another run CSV. |
| `ABDR_Review_PX4.m` | Summarize mission completion, tracking and safety flags. |
| `ABDR_Verify_Results.py` | Validate E01–E06 CSV record counts and expected experiment group sizes using Python 3. |

## MATLAB R2024b

```matlab
addpath('algorithm', 'algorithm/core', 'experiments');
opts.PoolDir = 'PATH_TO_ORIGINAL_SHARED_POOLS';
opts.OutputDir = 'PATH_TO_NEW_OUTPUT';
% opts.ReferenceDir = 'PATH_TO_REFERENCE_FRONTS';
T = ABDR_Run_Experiments('main', opts);
```

Other proposed-method tasks: `ABDR_Run_Experiments('ablation',opts)` (8 configurations × 4 scenarios × 30), `ABDR_Run_Experiments('runtime',opts)` (4 × 30), and `ABDR_Run_Experiments('crater',opts)` / `ABDR_Run_Experiments('mount',opts)` (12 × 30 each). Set `opts.TerrainFile` to the respective DEM for external terrain experiments. Original scenario definitions and shared pools must match those used for the archived results.

These MATLAB runners **do not execute competitors**. E01/E03/E04/E05 already contain competitors' saved numerical results, so they can be reviewed without those implementations.

## Review saved results without rerunning

```matlab
S = ABDR_Review_Results();
F = ABDR_Review_PX4();
```

```bash
python experiments/ABDR_Verify_Results.py
```

Python requires no third-party packages. The verification script never changes a recorded CSV. The PX4 script reports completion and safety as distinct outcomes; it does not run the PX4/Gazebo simulator.
