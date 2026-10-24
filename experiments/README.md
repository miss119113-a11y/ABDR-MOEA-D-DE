# ABDR-MOEA/D-DE experiments

The files in this directory are provided to **run the proposed method only** and analyze the manuscript's existing CSV outputs. No source code for third-party comparison methods is included.

| File | Function |
|---|---|
| `ABDR_Config.m` | Full-method parameter settings |
| `ABDR_Run_One.m` | One scenario/run; outputs objectives, HV and optional IGD+ |
| `ABDR_Run_Experiments.m` | Proposed-method tasks for main, ablation, runtime and external terrains |
| `ABDR_Review_Results.m` | Recalculate grouped means and SD from exported CSV |
| `ABDR_Review_PX4.m` | Summarize PX4 completion, tracking and safety results separately |

## Usage (MATLAB R2024b)

```matlab
addpath('experiments');
opts.PoolDir = 'PATH_TO_VERIFIED_SHARED_POOLS';
opts.OutputDir = 'PATH_FOR_NEW_RESULTS';
opts.ReferenceDir = 'PATH_TO_REFERENCE_FRONTS'; % optional for IGD+
T = ABDR_Run_Experiments('main', opts);
```

- `ABDR_Run_Experiments('ablation',opts)`: eight BI/DQR/SHDE switch configurations for the proposed algorithm.
- `ABDR_Run_Experiments('runtime',opts)`: proposed-method single-thread serial timing; other methods' timings are provided as CSV only.
- `ABDR_Run_Experiments('crater',opts)`, `'mount'`: also set `opts.TerrainFile` to the applicable **licensed external DEM**. The external scenario IDs are `[1:4 105:112]`; use the source scenario overrides when the archived terrain scenario definition differs.
- `ABDR_Review_Results()` and `ABDR_Review_PX4()`: analyze the public numeric tables without rerunning any optimizer.

Paper-exact reproduction requires original fixed initial pools, corresponding DEMs, and frozen reference fronts. They are **not fabricated or redistributed** here. Without those inputs, the compact result CSVs can still be independently inspected and summarized.

The single-run helper exports actual, newly computed values; the published numerical results are preserved under [datasets/paper_results](../datasets/paper_results/README.md).
