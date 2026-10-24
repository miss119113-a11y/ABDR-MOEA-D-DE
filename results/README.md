# Manuscript experiment results — ABDR-MOEA/D-DE

| ID | Experiment | Per-run CSV | Statistical summary |
|---|---|---|---|
| E01 | 11-method main comparison, four scenarios, 30 runs | [1320 records](E01_Main_Comparison_1320_Runs.csv) | [Mean / SD](statistics/E01_Main_Comparison_Mean_SD.csv) |
| E02 | Eight mechanism configurations, four scenarios, 30 runs | [960 records](E02_Ablation_960_Runs.csv) | [Mean / SD](statistics/E02_Ablation_Mean_SD.csv) |
| E03 | Independent serial runtime, 11 methods, four scenarios, 30 runs | [1320 records](E03_Serial_Runtime_1320_Runs.csv) | From per-run records |
| E04 | Crater Lake external-terrain evaluation, 12 scenarios | [2160 records](E04_Crater_Lake_2160_Runs.csv) | [Mean / SD](statistics/E04_Crater_Lake_Mean_SD.csv) |
| E05 | Mount St. Helens external-terrain evaluation, 12 scenarios | [2160 records](E05_Mount_St_Helens_2160_Runs.csv) | [Mean / SD](statistics/E05_Mount_St_Helens_Mean_SD.csv) |
| E06 | PX4–Gazebo SITL, six methods, 20 missions each | [120 mission records](E06_PX4_Gazebo_SITL_120_Missions.csv) | From per-mission records |

**Result labels:** `ABDR-MOEA/D-DE` denotes the proposed method. The file names above are publication-oriented labels. `SourceRecordID`, `OriginalAlgorithmLabel`, and original mission-source fields remain available inside the CSVs for traceability.

**Preservation:** This folder contains the uploaded per-run numerical outcomes. Reorganization did not recalculate F1–F4, HV, IGD+, runtimes, or PX4 pass/fail flags.

**Cohort boundaries:** The E04/E05 source result packages were marked as earlier H5-controller cohorts. In E06, the proposed-method cohort uses the `ULTRA` source label; the baseline mission records include historical saved outcomes. Recorded `MissionCompleted`, `TrackingSuccess` and `SafetyCompletion` fields have different meanings and are retained separately.

The original large MAT/ULog archives, raster DEMs and original fixed initialization pools are not included. This folder is intended for numerical inspection, not a claim that every archive can be reproduced exactly from the repository alone.
