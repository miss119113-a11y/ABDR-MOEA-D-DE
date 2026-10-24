# ABDR-MOEA/D-DE experimental datasets (2026-10-24)

This directory records the evidence archive structure for the IEEE Access UAV multiobjective path-planning study. The large experimental archives will be distributed as **GitHub Release assets**, not committed as ordinary Git files.

Expected nine archives:

1. `ABDR_MAIN_COMPARISON_1320_20261024.zip` — 11 algorithms, 4 scenarios, 30 runs; source matrices and statistics.
2. `ABDR_ABLATION_960_20261024.zip` — 8 configurations, 4 scenarios, 30 runs.
3. `ABDR_SERIAL_RUNTIME_1320_20261024.zip` — independent serial runtime benchmark.
4. `ABDR_EXTERNAL_PART1_CRATER_2160_LEGACY_H5_20261024.zip` — Crater Lake external DEM, H5-labeled cohort.
5. `ABDR_EXTERNAL_PART2_MOUNT_2160_LEGACY_H5_20261024.zip` — Mount St. Helens external DEM, H5-labeled cohort.
6. `ABDR_PX4_PART1_PROPOSED_FORMAL20_SITL_20261024.zip` — proposed method, 20 SITL runs.
7. `ABDR_PX4_PART2_TOP20_AND_REANALYSIS_20261024.zip` — ToP, 20 SITL runs and analyses.
8. `ABDR_PX4_PART3_HISTORICAL_FOUR_METHODS_20261024.zip` — 80 historical records for four baselines.
9. `ABDR_PX4_PART4_PREFLIGHT_AND_LEGACY_COHORT_20261024.zip` — preflight and legacy cohorts.

**Status: upload preparation only; no public data release yet.** Archive names and historical/legacy cohort tags are preserved deliberately. Archive-specific documentation governs run provenance and safety definitions. Before publishing large archives, review any third-party terrain and external code distribution rights and remove unintended private files. Do not infer that archived historical cohorts correspond to the identical final-controller implementation.

The release will receive a stable URL once the nine archives have been uploaded and the repository made public.
