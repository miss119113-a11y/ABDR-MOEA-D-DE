# Numerical experiment results

**Tables 2–9 in the submitted manuscript's exact display format** are available in [paper_tables/](paper_tables/). Original run-level measurements and full-precision statistics below remain unchanged.


All numeric data are provided as recorded, organized by experiment.

| ID | Experiment | Run-level data | Statistics |
|---|---|---|---|
| E01 | Main method comparison | [1320 records](E01_Main_Comparison_1320_Runs.csv) | [Mean and SD](statistics/E01_Main_Comparison_Mean_SD.csv) |
| E02 | Mechanism ablation | [960 records](E02_Ablation_960_Runs.csv) | [Mean and SD](statistics/E02_Ablation_Mean_SD.csv) |
| E03 | Serial runtime | [1320 records](E03_Serial_Runtime_1320_Runs.csv) | Per-run values |
| E04 | Crater Lake terrain | [2160 records](E04_Crater_Lake_2160_Runs.csv) | [Mean and SD](statistics/E04_Crater_Lake_Mean_SD.csv) |
| E05 | Mount St. Helens terrain | [2160 records](E05_Mount_St_Helens_2160_Runs.csv) | [Mean and SD](statistics/E05_Mount_St_Helens_Mean_SD.csv) |
| E06 | PX4–Gazebo SITL | [120 mission records](E06_PX4_Paper_Missions_120.csv) | [Aggregated outcomes](statistics/E06_PX4_Paper_Summary.csv) |

The PX4 results include mission completion, tracking, safety, trajectory error, and obstacle/terrain clearance outcomes. Continuous terrain-clearance values for the 40 proposed-method/ToP missions are provided separately in [E06_PX4_Continuous_Clearance_40.csv](E06_PX4_Continuous_Clearance_40.csv).

To check the tabulated records:

```bash
python experiments/ABDR_Verify_Results.py
```

Large flight telemetry logs, raw route archives, and comparator implementations are not part of this compact release.
