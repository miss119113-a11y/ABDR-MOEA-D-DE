# ABDR-MOEA/D-DE MATLAB algorithm

**Entry point:** `ABDR_MOEAD_DE.m`

**Main engine:** `ABDR_MOEAD_DE_ENGINE.m`

**Required helper:** `core/CODEX_ARCHIVE_GUIDE.m` (original audited implementation now restored, because the default `CodexArchiveGuide=true` path invokes it).

Other `core/` MATLAB files provide objectives/constraints, geometry, block crossover, direction-quota replacement, SHDE, and archive operations. No separate comparator optimizers or iteration snapshots are included.

```matlab
addpath('algorithm','algorithm/core','experiments');
p=ABDR_Config(260825101);
[archive,best,history]=ABDR_MOEAD_DE(p);
```

For manuscript-aligned experiments use `ABDR_Run_One` / `ABDR_Run_Experiments` with the original initialization pools and terrain. The algorithm engine was not rewritten during result reorganization. The current configured `TriadPBB` objective-pressure selector uses Tchebycheff contributions and is not identical to a rank-only selector; the manuscript/source difference is a remaining scientific provenance matter.
