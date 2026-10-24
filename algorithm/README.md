# ABDR-MOEA/D-DE MATLAB algorithm

**Public entry point:** `ABDR_MOEAD_DE.m`

**Algorithm engine:** `ABDR_MOEAD_DE_ENGINE.m`

**Required support code:** `core/`

This is the complete algorithm implementation supplied in the October 24 release package, with the engine's MATLAB function name standardized for the paper. Its search logic is preserved: Block Inheritance (BI), Direction-Quota Replacement (DQR), and multi-memory success-history differential evolution (SHDE). Required evaluator, archive, geometry, and parameter-adaptation helpers are included.

```matlab
addpath('algorithm','algorithm/core','experiments','maps/terrain');
p = ABDR_Config(260825101);
[rep,best,history] = ABDR_MOEAD_DE(p);
```

Run `python maps/extract_maps.py` before calling the optimizer. For paper-matched batch experiments, use the scripts in `experiments/` with the study's shared initialization pools.
