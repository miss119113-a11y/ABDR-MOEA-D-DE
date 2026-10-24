#!/usr/bin/env python3
"""Read-only integrity checks for E01-E06 paper CSV files (Python 3 stdlib)."""
from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"

TABLES = {
    "E01_Main_Comparison_1320_Runs.csv": (1320, 11, 4, 30),
    "E02_Ablation_960_Runs.csv": (960, 8, 4, 30),
    "E03_Serial_Runtime_1320_Runs.csv": (1320, 11, 4, 30),
    "E04_Crater_Lake_2160_Runs.csv": (2160, 6, 12, 30),
    "E05_Mount_St_Helens_2160_Runs.csv": (2160, 6, 12, 30),
}

def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise FileNotFoundError(path)
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))

def verify():
    total = 0
    for name, (expected, methods, scenarios, repeats) in TABLES.items():
        rows = read_csv(RESULTS / name)
        if len(rows) != expected:
            raise AssertionError(f"{name}: {len(rows)} records, expected {expected}")
        required = {"Algorithm", "Scenario", "Run", "FEEvaluated"}
        if not required.issubset(rows[0]):
            raise AssertionError(f"{name}: missing {required - set(rows[0])}")
        keys = Counter((r["Algorithm"], r["Scenario"]) for r in rows)
        if len({r["Algorithm"] for r in rows}) != methods:
            raise AssertionError(f"{name}: unexpected number of methods/variants")
        if len({r["Scenario"] for r in rows}) != scenarios:
            raise AssertionError(f"{name}: unexpected scenario count")
        if len(keys) != methods * scenarios or any(n != repeats for n in keys.values()):
            raise AssertionError(f"{name}: method/scenario repetitions do not match")
        unique_runs = {(r["Algorithm"], r["Scenario"], r["Run"]) for r in rows}
        if len(unique_runs) != len(rows):
            raise AssertionError(f"{name}: duplicate method/scenario/run records")
        total += len(rows)
        print(f"OK  {name}: {len(rows)} records; {methods} methods/variants, "
              f"{scenarios} scenarios, {repeats} repeats each")

    name = "E06_PX4_Gazebo_SITL_120_Missions.csv"
    rows = read_csv(RESULTS / name)
    if len(rows) != 120:
        raise AssertionError(f"{name}: expected 120 missions")
    required = {"Algorithm", "MissionID", "MissionCompleted", "TrackingSuccess",
                "SafetyCompletion", "TerrainCollisionEvent"}
    if not required.issubset(rows[0]):
        raise AssertionError(f"{name}: missing {required - set(rows[0])}")
    groups = Counter(row["Algorithm"] for row in rows)
    if len(groups) != 6 or any(n != 20 for n in groups.values()):
        raise AssertionError(f"{name}: expected six methods with 20 missions each")
    if len({r["MissionID"] for r in rows}) != 120:
        raise AssertionError(f"{name}: repeated mission identifiers")
    print(f"OK  {name}: {len(rows)} missions; 6 methods, 20 each")
    for algorithm, n in sorted(groups.items()):
        subset = [r for r in rows if r["Algorithm"] == algorithm]
        count = lambda field: sum(r[field].strip().lower() in ("true", "1") for r in subset)
        print(f"    {algorithm}: completed {count('MissionCompleted')}/{n}, "
              f"tracking {count('TrackingSuccess')}/{n}, "
              f"safety {count('SafetyCompletion')}/{n}")
    total += len(rows)
    print(f"\nPASS: {total} saved records checked; original CSVs not modified.")

if __name__ == "__main__":
    verify()
