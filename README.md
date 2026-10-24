# ABDR-MOEA/D-DE

MATLAB source, experiment scripts, and source-traceable numerical results for constrained multiobjective UAV path planning.

## Repository structure

- [algorithm/](algorithm/) — one proposed ABDR-MOEA/D-DE optimizer plus required MATLAB dependencies.
- [experiments/](experiments/) — MATLAB single/batch runs, existing-results analysis, and Python verification/unpacking.
- [results/](results/) — E01–E06 archived paper results and group statistics.

We do not distribute implementation source code for competing methods.

## Results

The E01–E05 run-level CSV data and statistics are unchanged. For PX4, the paper-matched 120-mission cohort is **[E06_PX4_Paper_Missions_120.csv.gz](results/E06_PX4_Paper_Missions_120.csv.gz)**. Its statistics are in [results/statistics/E06_PX4_Paper_Summary.csv](results/statistics/E06_PX4_Paper_Summary.csv). The earlier incompatible U28/preflight CSV is preserved under [results/diagnostics/](results/diagnostics/) and is **not** Table 9.

To verify the results or produce an ordinary PX4 CSV using Python 3 (no extra packages):
```bash
python experiments/ABDR_Verify_Results.py
python experiments/ABDR_Extract_PX4.py
```

## MATLAB usage

```matlab
addpath('algorithm','algorithm/core','experiments');
opts.PoolDir='PATH_TO_ORIGINAL_SHARED_POOLS';
opts.OutputDir='PATH_TO_OUTPUT';
T=ABDR_Run_Experiments('main',opts);
S=ABDR_Review_PX4();
```

The optimizer uses 30 candidates, a 6000-function-evaluation limit, and 30 trials per scenario for the paper comparison. Exact reruns also require source-matched shared feasible initial pools, reference fronts and corresponding DEMs, none of which are redistributed here. The provided runners generate results for our method only.

**Research provenance limits:** E04/E05 include a legacy H5 controller cohort; PX4 includes a legacy-flown ULTRA20 cohort with unproven identity to the latest optimizer route hashes, and historical comparator data with incomplete flight payloads. Reproduced numbers are not proof of algorithm-version equivalence. Mechanism flags in some existing ablation runs also control ancillary operations. See [results/README.md](results/README.md) for details.
