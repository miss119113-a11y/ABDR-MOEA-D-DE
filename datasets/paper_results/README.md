# ABDR-MOEA/D-DE — manuscript experimental results

The following datasets accompany the proposed multiobjective UAV path planning method. All numeric outputs and stored completion/safety flags are copied from the supplied experimental archives.

| ID | Experiment | Per-run results | Statistics |
|---|---|---|---|
| E01 | Main comparison: 11 algorithms, S1–S4, 30 runs | [1320 runs](E01_Main_Comparison_1320_Runs.csv) | [Mean/SD](statistics/E01_Main_Comparison_Mean_SD.csv) |
| E02 | BI/DQR/SHDE ablation, eight configurations, S1–S4 | [960 runs](E02_Ablation_960_Runs.csv) | [Mean/SD](statistics/E02_Ablation_Mean_SD.csv) |
| E03 | Independent serial runtime evaluation | [1320 runs](E03_Serial_Runtime_1320_Runs.csv) | From run records |
| E04 | Crater Lake terrain evaluation | [2160 runs](E04_Crater_Lake_2160_Runs.csv) | [Mean/SD](statistics/E04_Crater_Lake_Mean_SD.csv) |
| E05 | Mount St. Helens terrain evaluation | [2160 runs](E05_Mount_St_Helens_2160_Runs.csv) | [Mean/SD](statistics/E05_Mount_St_Helens_Mean_SD.csv) |
| E06 | PX4–Gazebo SITL | [120 missions](E06_PX4_Gazebo_SITL_120_Missions.csv) | Original per-mission outcomes |

### Names

The proposed method is **ABDR-MOEA/D-DE**. Its mechanisms are **BI**, **DQR**, and **SHDE**. CSVs use publication-aligned names; `OriginalAlgorithmLabel` and `SourceRecordID` retain source identifiers needed to trace rows back to original files.

### Important interpretation

- External-terrain source packages identify an earlier H5-controller run batch. These results should not be described as independently proving an identical implementation of the latest source without task-level evidence.
- For PX4, a mission's completion and tracking status are separate from its saved `SafetyCompletion`/terrain-collision outcomes; the dataset preserves both.
- Numeric results from comparison algorithms are provided, **not** their source code.

Original large MAT and ULog archives, reference-front binaries and third-party DEM raster files are not in this lightweight repository.
