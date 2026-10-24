# ABDR-MOEA/D-DE

**Experimental data and MATLAB research material for multiobjective UAV path planning**

ABDR-MOEA/D-DE combines block inheritance (**BI**), direction-quota replacement (**DQR**), and success-history differential-evolution parameter adaptation (**SHDE**) within the MOEA/D-DE framework.

## Research data

The reviewer-facing dataset is in **[datasets/paper_results](datasets/paper_results/README.md)**, covering:

- E01 — Main algorithm comparison (1,320 runs)
- E02 — Ablation experiments (960 runs)
- E03 — Independent serial runtime (1,320 runs)
- E04 — Crater Lake external-terrain evaluation (2,160 runs)
- E05 — Mount St. Helens external-terrain evaluation (2,160 runs)
- E06 — PX4-Gazebo SITL (120 per-mission records)

The numerical results are provided as CSV files with summary statistics and a source-data directory for verification. See [naming conventions](datasets/ALGORITHM_AND_EXPERIMENT_NAMES.md) and [original data provenance](datasets/curated/README.md).

## Source code

MATLAB research code and experiment scripts are maintained in the repository, including the [frozen_20261022](frozen_20261022/README.md) snapshot. Some source files carry earlier development identifiers. Dataset file naming is standardized for the manuscript, while source snapshots remain unchanged for traceability.

## Data use

The numerical dataset is a curated copy of archived experiment results. Raw MAT archives, large PX4 ULogs and licensed third-party terrain files are stored separately. Reported mission-completion status and safety status are distinct fields; see the dataset README for interpretation and provenance.
