# Manuscript E01–E06 numerical results

| ID | Experiment | Per-run records | Statistics |
|---|---|---|---|
| E01 | Main comparison: 11 methods; 4 scenarios × 30 | [1320 CSV](E01_Main_Comparison_1320_Runs.csv) | [Mean/SD](statistics/E01_Main_Comparison_Mean_SD.csv) |
| E02 | Ablation: 8 variants; 4 scenarios × 30 | [960 CSV](E02_Ablation_960_Runs.csv) | [Mean/SD](statistics/E02_Ablation_Mean_SD.csv) |
| E03 | Serial runtime: 11 methods; 4 scenarios × 30 | [1320 CSV](E03_Serial_Runtime_1320_Runs.csv) | From timing records |
| E04 | Crater Lake: 6 methods; 12 scenarios × 30 | [2160 CSV](E04_Crater_Lake_2160_Runs.csv) | [Mean/SD](statistics/E04_Crater_Lake_Mean_SD.csv) |
| E05 | Mount St. Helens: 6 methods; 12 scenarios × 30 | [2160 CSV](E05_Mount_St_Helens_2160_Runs.csv) | [Mean/SD](statistics/E05_Mount_St_Helens_Mean_SD.csv) |
| E06 | PX4–Gazebo: 6 methods × 20 flights | [120 mission gzip CSV](E06_PX4_Paper_Missions_120.csv.gz) | [Table 9](statistics/E06_PX4_Paper_Summary.csv) |

E06 was derived, without changing recorded outcomes, from the 2026-10-23 `ABDR_IEEEAccess_DATA_EXPORT.zip` source `paper_data/T09_px4_missions_raw.csv`. The compact gzip CSV includes identifiers, cohort/binding information, mission completion, tracking, safety, XTE RMSE/P95, per-flight sampled terrain clearance, and threat margin. For the 40 ULTRA20/ToP flights, Table 9 uses **continuous terrain clearance** rather than sampled clearance; their corresponding per-flight values are [here](E06_PX4_Continuous_Clearance_40.csv). The global terrain and threat-margin statistics are **minimum values across completed missions**, not means. XTE statistics are means across completed missions. Rates use all 20 flights per method.

Use `python experiments/ABDR_Verify_Results.py` to independently check totals and derive E06 Table 9 metrics; `python experiments/ABDR_Extract_PX4.py` exports an ordinary 120-row CSV.

[Old U28 preflight/reanalysis records](diagnostics/E06_U28_Preflight_Not_Manuscript.csv) do **not** correspond to paper Table 9. They are separated to avoid mixing cohorts.

All E01–E05 numerical data are byte-identical to the previously uploaded GitHub run-level data; no metric values were adjusted in this clean-up. External results include a legacy H5-controller batch, which does not alone demonstrate current-controller generalization. The flown ULTRA20 routes are not proven identical to the final updated optimizer routes. Comparator flight payload evidence is incomplete. These are provenance limitations, not numeric substitutions.

Independent audit additionally identified four significance-symbol differences (Table 2, S3: NMOPSO / NSGA-III / ToP F2; Table 6 Mount S2: ToP F2) and eight rank-versus-mean-direction count differences in Table 7. Keep the distinctions explicit rather than altering raw data.
