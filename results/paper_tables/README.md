# Results as displayed in the submitted IEEE Access manuscript

These eight CSV files reproduce **Tables 2–9 exactly as printed** in the submitted manuscript (`main(1).pdf`). Numeric values retain the paper's original number of decimal places, significance markers (`+`, `−`/`-`, `=`), and G05–G12 win/loss/tie counts. They were constructed from the manuscript's `paper_table_cells.csv` transcription in the authors' 2026-10-23 data export. They are **as-published presentation tables**, not newly recomputed statistics.

| Manuscript | Publication-format table |
|---|---|
| Table 2 — Primary algorithm comparison | [Table 02](Table_02_Main_Comparison_As_Published.csv) |
| Table 3 — Decomposition-based comparison | [Table 03](Table_03_Decomposition_As_Published.csv) |
| Table 4 — BI / DQR / SHDE ablation | [Table 04](Table_04_Ablation_As_Published.csv) |
| Table 5 — Crater Lake transfer | [Table 05](Table_05_Crater_Lake_As_Published.csv) |
| Table 6 — Mount St. Helens transfer | [Table 06](Table_06_Mount_St_Helens_As_Published.csv) |
| Table 7 — G05–G12 terrain comparison | [Table 07](Table_07_External_G05_G12_As_Published.csv) |
| Table 8 — Serial execution time | [Table 08](Table_08_Runtime_As_Published.csv) |
| Table 9 — PX4–Gazebo fixed-route results | [Table 09](Table_09_PX4_As_Published.csv) |

## Recorded experiments

The independent-run measurements in the parent `results/` directory (`E01–E06`) and the numerical summaries in `results/statistics/` retain the original supplied precision and values. These must **not** be replaced with rounded publication-table numbers. This permits reanalysis of results while keeping paper-format tables available for readers.

The source export independently identified 4 significance-marker, 8 G05–G12 count, and 13 PX4 last-digit differences. [The precise cells and recomputations](Paper_vs_Raw_Display_Differences.csv) are retained here so readers can distinguish the manuscript's displayed values from independently re-derived values; no raw run/mission records were modified to force agreement. The significance-marker and count columns represent the submitted paper, not a claim that the same testing convention was recomputed from the raw data.