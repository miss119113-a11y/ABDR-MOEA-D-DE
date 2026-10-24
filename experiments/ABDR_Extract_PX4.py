#!/usr/bin/env python3
"""Extract the paper's 120 mission records into a plain CSV (stdlib only)."""
import gzip
import shutil
from pathlib import Path

results = Path(__file__).resolve().parents[1] / "results"
source = results / "E06_PX4_Paper_Missions_120.csv.gz"
target = results / "E06_PX4_Paper_Missions_120.csv"
with gzip.open(source, "rb") as s, target.open("wb") as d:
    shutil.copyfileobj(s, d)
print(target)
