# BIDR-MOEA/D-DE — frozen MATLAB implementation (2026-10-22)

Private source repository accompanying the revised IEEE Access manuscript **“A Multiobjective Decomposition Algorithm With Active Block Inheritance, Directional Replacement, and Multi-Memory Adaptation for UAV Path Planning.”**

## Method

The algorithm combines **Active Population-wise Block Inheritance (APB)**, **Direction-Quota Replacement (DQR)** and a **multi-memory success-history differential-evolution controller (SHDE)**. APB maps the weakest ranked objective of an incumbent to one or more coupled navigation-variable blocks. DQR associates feasible offspring with eligible reference directions and enforces at most one accepted replacement per direction per generation. SHDE samples mutation and crossover controls from five cells and updates the memory values and cell-selection probabilities using the scalar improvements of accepted feasible replacements.

The five initial CR memory values are `[0.1 0.3 0.5 0.7 0.9]`; the initial selection probabilities are `[0.2 0.2 0.2 0.2 0.2]`. Mutation memories start at 0.5. Every scenario uses the same initial memories and `neighborSize=6`. In the frozen protocol, `ControllerAlphaP=0.25` and `ControllerPMin=0.05`.

## Quick start (MATLAB R2024b)

Place the entire MATLAB source directory, `ChrismasTerrain2.tif`, and `demo_pool_S1.mat` in one directory, then run:

```matlab
cd('PATH_TO_REPOSITORY');
RUN_BIDR_DEMO_MINIMAL;
```

The demonstration is a short functional check (300 FEs), **not** the source of the paper's 6000-FE results. For an experiment-scale run use `RUN_EXACT6000_PROTOCOL.m` and its documented inputs, or the `BIDR_CHAMPION_ENGINE` interface with the same frozen setup. The 30 shared feasible initial solutions count toward the total 6000 FEs.

## Core implementation

- `BIDR_CHAMPION_ENGINE.m`: frozen algorithm and all three active mechanisms.
- `BIMOEAD_DE.m`: public entry wrapper.
- `NAV_APDP_PressureBlockMask.m`, `NAV_PBD_BlockCrossover*.m`: APB pressure and block crossover helpers.
- `NAV_SHDE_ADAPTIVE_SAMPLE.m`, `NAV_SHDE_ADAPTIVE_UPDATE.m`: success-history sampling and updating.
- `NAV_MyCost_PhysicalV2.m`, `CreateModel.m`, `NAV_ValidatePhysicalPath.m`: shared objective and constraint evaluator.
- `RUN_BIDR_DEMO_MINIMAL.m`: integration check.
- `SOURCE_LOCK.json`: original source hash inventory.

## Manuscript protocol

Population 30; 10 intermediate nodes (30 variables); neighborhood size 6; feasible nondominated archive capacity 30; a common 6000-FE budget including initialization; 30 independent runs per primary scenario. The main manuscript reports F1 (route efficiency), F2 (threat exposure), F3 (terrain-relative altitude), F4 (smoothness), HV, and IGD+.

The paper's statistical archive and flight telemetry are not part of this minimal algorithm repository. Numerical summary CSVs and the manuscript revision package are maintained separately. The repository does not redistribute external comparison-algorithm implementations or PX4/Gazebo flight recordings.

## Provenance and third-party assets

The SHDE adaptation principle builds on Tanabe and Fukunaga (IEEE CEC 2013); MOEA/D and MOEA/D-DE follow the referenced foundational literature. Third-party DEM and comparison algorithms retain their own authorship and licenses. `ChrismasTerrain2.tif` is an input terrain asset; reuse/distribution requires checking the source dataset's terms.

## Release status

Private pre-acceptance working repository; a public release and license decision will be made at acceptance. No repository access or release status is implied by the manuscript's code-availability statement beyond the actual private repository.