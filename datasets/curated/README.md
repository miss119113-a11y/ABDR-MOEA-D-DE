# ABDR-MOEA/D-DE: curated experimental results for peer review

Version: 2026-10-24 (curated from supplied archived experiments)

## What is included

* Main benchmark: 1320 per-run records (11 methods x 4 scenarios x 30).
* Ablation: 960 per-run records (8 variants x 4 scenarios x 30).
* Serial runtime: 1320 records, including `RuntimeSec` measurements.
* External DEM: 2160 records for Crater Lake and 2160 for Mount St. Helens (historic LEGACY_H5 cohort, as explicitly marked in source archives).
* PX4 SITL per-mission extracts: 20 newly packaged proposed method, 20 ToP, 80 historical baselines, with explicit cohort labels and the original outcome/pass fields.
* Reference fronts, representative-selection indexes, scenario configurations, summary statistics and tests where supplied.

These data preserve the numerical values and original per-run pass/fail fields. Source CSVs have been narrowed to relevant measurement and provenance fields; local Windows paths, bundled copies of source trees, third-party terrain files, bulk raw MAT archives and binary flight log/ULog files are deliberately excluded. Full source archives remain available with the original custodian.

## IMPORTANT: interpretation and version limits

* The external DEM cohorts are explicitly marked `LEGACY_H5` in the uploaded archives. They must not be described as a proven identical run of a later controller version without further run-level evidence.
* A completed PX4 mission is not the same as a safety pass. In the `new_proposed_formal20` cohort, the underlying `SafetyCompletion` status is FALSE for all 20 entries (and is preserved verbatim). `new_ToP_formal20` reports also fail the corresponding safety test. Investigate altitude-reference / terrain-collision evaluation independently before making safety-success claims.
* The 80 baseline PX4 records in this extract come from a historical available-records source. Do not present them as a uniform cohort of complete raw ULogs.
* The four method and scenario-dependent result tables should be interpreted with the stated statistical direction conventions: mean-direction sign and Holm-corrected rank-based MW test significance are different properties.
* Reference-front and scenario data are from the source bundles; this dataset does not independently establish rights to redistribute third-party DEM raster input files.

## Fields and provenance

The run CSVs retain `record_id`, scene, run, seed, algorithm, iteration budget, objectives F1–F4, HV, IGDPlus, archive size, plus saved-run metadata and source SHA-256 where present. Values are copied from source CSV strings without rounding. Statistics and reference fronts are byte-preserved from source ZIP entries.

PX4 results retain mission ID, algorithm, condition, plan/ULog hashes, executed tracking, terrain and threat margin metrics, and original completion / tracking / safety flags. `cohort` is a new contextual label added solely for cross-batch clarity.

See `MANIFEST_SHA256.csv` for the original ZIP hashes and `CURATED_FILES_SHA256.csv` for extracted file hashes. The availability of full binary data upon request should not be represented as a permanent open download link.

This distribution is an evidence-oriented per-run numerical dataset, not a claim that every source archive is identical to the manuscript's final algorithm implementation.
