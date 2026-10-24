# Original numerical results accompanying the manuscript

| ID | Group | Per-run data | Statistics |
|---|---|---|---|
| E01 | 11-method main comparison; 1320 | [CSV](E01_Main_Comparison_1320_Runs.csv) | [Mean / SD](statistics/E01_Main_Comparison_Mean_SD.csv) |
| E02 | 8 variants; 960 | [CSV](E02_Ablation_960_Runs.csv) | [Mean / SD](statistics/E02_Ablation_Mean_SD.csv) |
| E03 | Serial runtime; 1320 | [CSV](E03_Serial_Runtime_1320_Runs.csv) | Per-run timing values |
| E04 | Crater Lake; 2160 | [CSV](E04_Crater_Lake_2160_Runs.csv) | [Mean / SD](statistics/E04_Crater_Lake_Mean_SD.csv) |
| E05 | Mount St. Helens; 2160 | [CSV](E05_Mount_St_Helens_2160_Runs.csv) | [Mean / SD](statistics/E05_Mount_St_Helens_Mean_SD.csv) |
| E06 | PX4–Gazebo SITL paper cohort; 120 missions | [gzip CSV](E06_PX4_Paper_Missions_120.csv.gz) | [Paper Table 9 metrics](statistics/E06_PX4_Paper_Summary.csv) |

E06's source is the 2026-10-23 `ABDR_IEEEAccess_DATA_EXPORT.zip` paper-data file `T09_px4_missions_raw.csv`. The published compact CSV preserves all 120 mission outcomes, XTE RMSE, XTE P95, terrain clearance, threat margin and cohort/algorithm-binding flags, without large telemetry binaries or private source paths. Expand with `python experiments/ABDR_Extract_PX4.py`.

**Do not use** the older `diagnostics/E06_U28_Preflight_Not_Manuscript.csv` as the paper Table 9 dataset. It is retained for traceability and has a different analysis population / safety convention.

The saved E01–E05 numerical CSV and statistics were not altered. E04/E05 include a legacy H5-controller campaign. The E06 proposed-method cohort contains earlier flown ULTRA route hashes; its equivalence to the final updated optimizer routes has not been demonstrated. Four comparator missions had only incomplete historical evidence; more generally, all historical comparator cohorts have incomplete raw-flight coverage. The algorithm's current default BI pressure-selector pathway is not textually identical to the manuscript rank-only formula.

The source reconciliation found four significance-symbol disagreements (Table 2 S3: NMOPSO, NSGA-III, ToP F2; Table 6 Mount S2: ToP F2) and eight mean-versus-rank directional count differences in Table 7. The original numeric outcomes remain unchanged. These distinctions matter for scientific interpretation but do not affect file row counts.
