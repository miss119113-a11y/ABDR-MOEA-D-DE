# ABDR-MOEA/D-DE — experimental results for IEEE Access

This directory presents the numerical results associated with the UAV multiobjective path-planning manuscript **ABDR-MOEA/D-DE**. Experiment titles and display labels are standardized to match the manuscript.

## Experiments

| No. | Experiment | Data |
|---|---|---|
| E01 | Main algorithm comparison: 11 algorithms, four scenarios, 30 independent runs | [E01_Main_Comparison_1320_Runs.csv](E01_Main_Comparison_1320_Runs.csv) |
| E02 | Ablation study: eight configurations, four scenarios, 30 runs | [E02_Ablation_960_Runs.csv](E02_Ablation_960_Runs.csv) |
| E03 | Independent serial runtime: 11 algorithms, four scenarios, 30 runs | [E03_Serial_Runtime_1320_Runs.csv](E03_Serial_Runtime_1320_Runs.csv) |
| E04 | Crater Lake external-terrain comparison: six algorithms, twelve scenarios, 30 runs | [E04_Crater_Lake_2160_Runs.csv](E04_Crater_Lake_2160_Runs.csv) |
| E05 | Mount St. Helens external-terrain comparison: six algorithms, twelve scenarios, 30 runs | [E05_Mount_St_Helens_2160_Runs.csv](E05_Mount_St_Helens_2160_Runs.csv) |
| E06 | PX4-Gazebo SITL evaluation: 120 per-mission records, six methods | [E06_PX4_Gazebo_SITL_120_Missions.csv](E06_PX4_Gazebo_SITL_120_Missions.csv) |

Summary statistics: [E01 means/SD](statistics/E01_Main_Comparison_Mean_SD.csv), [E02 means/SD](statistics/E02_Ablation_Mean_SD.csv), [E04 means/SD](statistics/E04_Crater_Lake_Mean_SD.csv), [E05 means/SD](statistics/E05_Mount_St_Helens_Mean_SD.csv).

## Algorithm and experiment names

- Proposed algorithm: **ABDR-MOEA/D-DE**.
- Core mechanisms: **BI** (block inheritance, including associated pressure selection), **DQR** (direction-quota replacement, including its configured archive guidance), **SHDE** (success-history parameter adaptation with memory-related controls).
- Comparator algorithm names are retained as distinct methods.
- Ablation variants are written as `Full`, `Without BI-related components`, `Without DQR-related components`, `Without SHDE-related components`, `SHDE-related components only`, `BI-related components only`, `DQR-related components only`, and `MOEA/D-DE baseline`.
- The `OriginalAlgorithmLabel` and `SourceRecordID` columns retain the exact historical input identifiers; experiment naming changes do not modify the numerical outputs.
- For PX4, the manuscript display name **ABDR-MOEA/D-DE** corresponds to the source method identifier `ULTRA`; `SourcePaperMethod` and `SourceRecordGroup` preserve the original values.

## Scope and interpretation

All recorded objective values, HV, IGD+, runtime and PX4 status fields are copied from the supplied results. The source data and original run metadata remain in [../curated](../curated/README.md). This is a presentation-normalized view, not a claim that historical runs were produced by a single source revision.

External-terrain data are drawn from the archived H5-controller experiments; the matching of those runs to the manuscript's final control configuration requires separate evidence. PX4 mission completion and tracking passes must not be interpreted as safety passes: the exported `SafetyCompletion`, `TerrainSafetyPass` and related values are preserved without alteration. Historical PX4 comparators are retained as historical records.

Large raw MAT files, ULog files, terrain rasters and third-party materials are not part of this lightweight repository view. Source-archive checksums are in [../curated/MANIFEST_SHA256.csv](../curated/MANIFEST_SHA256.csv). 
