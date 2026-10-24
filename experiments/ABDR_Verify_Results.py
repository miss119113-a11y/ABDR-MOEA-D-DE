#!/usr/bin/env python3
"""Read-only validation of all archived E01-E06 paper result files."""
import csv
import gzip
import math
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
TASKS = {
    "E01_Main_Comparison_1320_Runs.csv": (1320, 11, 4, 30),
    "E02_Ablation_960_Runs.csv": (960, 8, 4, 30),
    "E03_Serial_Runtime_1320_Runs.csv": (1320, 11, 4, 30),
    "E04_Crater_Lake_2160_Runs.csv": (2160, 6, 12, 30),
    "E05_Mount_St_Helens_2160_Runs.csv": (2160, 6, 12, 30),
}

def rows(path):
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))

for filename, (count, methods, scenarios, runs) in TASKS.items():
    R = rows(RESULTS / filename)
    if len(R) != count:
        raise ValueError(f"{filename}: expected {count} rows, got {len(R)}")
    if len({r["Algorithm"] for r in R}) != methods:
        raise ValueError(f"{filename}: unexpected method count")
    if len({r["Scenario"] for r in R}) != scenarios:
        raise ValueError(f"{filename}: unexpected scenario count")
    C = Counter((r["Algorithm"], r["Scenario"]) for r in R)
    if len(C) != methods * scenarios or any(n != runs for n in C.values()):
        raise ValueError(f"{filename}: incomplete method/scenario repetition groups")
    if len({(r["Algorithm"],r["Scenario"],r["Run"]) for r in R}) != len(R):
        raise ValueError(f"{filename}: duplicate experimental records")
    print(f"OK {filename}: {count} records")
    
filename = "E06_PX4_Paper_Missions_120.csv.gz"
R = rows(RESULTS / filename)
C = Counter(r["Algorithm"] for r in R)
assert len(R) == 120 and len(C) == 6 and all(n == 20 for n in C.values())
assert len({r["MissionID"] for r in R}) == 120
summary = {r["Method"]: r for r in rows(RESULTS/"statistics"/"E06_PX4_Paper_Summary.csv")}
truth = lambda v: str(v).strip().lower() in ("1", "true")
for alg, n in C.items():
    subset = [r for r in R if r["Algorithm"] == alg]
    completed = [r for r in subset if truth(r["MissionCompleted"])]
    for flag, col in (("MissionCompleted","flight_success"),("TrackingSuccess","tracking_success"),
                      ("SafetyCompletion","safety_success")):
        observed = sum(truth(r[flag]) for r in subset)
        assert observed == int(summary[alg][col]), (alg, col, observed)
    for metric, col in (("XTE_RMSE_m","XTE_RMSE_m"),
                        ("XTE_P95_m","XTE_P95_m"),
                        ("MinTerrainClearanceM","min_terrain_clearance_m"),
                        ("MinThreatMarginM","min_threat_margin_m")):
        avg = sum(float(r[metric]) for r in completed) / len(completed)
        expected = float(summary[alg][col])
        if not math.isclose(avg,expected,abs_tol=1e-6,rel_tol=1e-8):
            raise ValueError(f"E06 {alg} {metric}: {avg} versus saved summary {expected}")
    print(f"OK E06 {alg}: missions={n}, completed={len(completed)}, safe={sum(truth(r['SafetyCompletion']) for r in subset)}")
print("PASS: all six saved experiment groups checked, original numerical CSVs unchanged.")
