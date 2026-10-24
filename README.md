# ABDR-MOEA/D-DE

MATLAB implementation and experimental results for constrained multiobjective UAV path planning.

The proposed method combines **block inheritance (BI)**, **direction-quota replacement (DQR)**, and **success-history differential-evolution parameter adaptation (SHDE)**.

## Repository structure

- [`algorithm/`](algorithm/) — the proposed ABDR-MOEA/D-DE algorithm and the helper functions it requires.
- [`experiments/`](experiments/) — experiment configuration, single-run and batch runners, statistical summary and PX4 results-analysis code.
- [`datasets/paper_results/`](datasets/paper_results/) — numerical results associated with the manuscript (E01–E06).

**No implementations of competing algorithms are distributed here.** The benchmark CSVs retain competitors' observed numerical results for comparison.

## MATLAB

Tested source target: MATLAB R2024b. Call `ABDR_MOEAD_DE(params)` after adding `algorithm/` and `algorithm/core/` to the MATLAB path. Paper-scale runs use 30 solutions, 6000 function evaluations, and 30 repetitions per case. See [experiment instructions](experiments/README.md).

The repository stores compact numerical output, not large binary flight logs or third-party terrain rasters. Original shared initialization pools, licensed terrain inputs and reference sets must be supplied separately for an exact paper-protocol rerun.

## Research results

Use [the paper results index](datasets/paper_results/README.md) for experiment tables and CSV files. Raw numbers and recorded completion/safety flags are unchanged.
