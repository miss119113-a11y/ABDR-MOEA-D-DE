# Proposed algorithm: ABDR-MOEA/D-DE

- `ABDR_MOEAD_DE.m` — single public MATLAB entry point.
- `ABDR_MOEAD_DE_ENGINE.m` — current optimization engine.
- `core/` — the directly required evaluation, geometry, constraints, Pareto, BI/DQR and success-history parameter-adaptation helper functions.

The algorithm's MATLAB implementation and its numerical operations are unchanged by the repository layout update. Historical helper identifiers appearing inside the retained source are not separate algorithms or independently distributed comparator implementations.

```matlab
addpath('algorithm', 'algorithm/core', 'experiments');
p = ABDR_Config(260825101);
[archive,best,history] = ABDR_MOEAD_DE(p);
```

For a manuscript-matched run, use `ABDR_Run_One` / `ABDR_Run_Experiments` with the original shared initialization pool and scenario inputs instead of relying on a bare optimizer invocation.
