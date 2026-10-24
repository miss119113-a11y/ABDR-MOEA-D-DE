#!/usr/bin/env python3
"""Read-only verification of E01-E06 datasets against archived group statistics."""
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

def read_csv(path):
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))

for name, (count, methods, scenarios, repeats) in TASKS.items():
    rows = read_csv(RESULTS / name)
    assert len(rows) == count, (name, "count", len(rows))
    assert len({x["Algorithm"] for x in rows}) == methods, name
    assert len({x["Scenario"] for x in rows}) == scenarios, name
    by_group = Counter((x["Algorithm"], x["Scenario"]) for x in rows)
    assert len(by_group) == methods * scenarios and all(n == repeats for n in by_group.values()), name
    assert len({(x["Algorithm"], x["Scenario"], x["Run"]) for x in rows}) == len(rows), name
    print(f"OK {name}: {count} records")

missions = read_csv(RESULTS / "E06_PX4_Paper_Missions_120.csv.gz")
summary = {x["Method"]: x for x in read_csv(RESULTS / "statistics" / "E06_PX4_Paper_Summary.csv")}
continuous_rows = read_csv(RESULTS / "E06_PX4_Continuous_Clearance_40.csv")
continuous = {x["MissionID"]: float(x["ContinuousMinTerrainClearanceM"]) for x in continuous_rows}
by_algorithm = Counter(x["Algorithm"] for x in missions)
assert len(missions) == 120 and len(by_algorithm) == 6 and all(n == 20 for n in by_algorithm.values())
assert len({x["MissionID"] for x in missions}) == 120
assert len(continuous) == len(continuous_rows) == 40
truth = lambda v: str(v).strip().lower() in ("true", "1")
for alg, n in by_algorithm.items():
    x = [r for r in missions if r["Algorithm"] == alg]
    completed = [r for r in x if truth(r["MissionCompleted"])]
    for field, summary_field in (("MissionCompleted", "flight_success"),
                                 ("TrackingSuccess", "tracking_success"),
                                 ("SafetyCompletion", "safety_success")):
        assert sum(truth(r[field]) for r in x) == int(summary[alg][summary_field]), (alg, field)
    for field in ("XTE_RMSE_m", "XTE_P95_m"):
        observed = sum(float(r[field]) for r in completed) / len(completed)
        assert math.isclose(observed, float(summary[alg][field]), rel_tol=1e-10, abs_tol=1e-8), (alg, field)
    min_terrain = min(continuous.get(r["MissionID"], float(r["MinTerrainClearanceM"])) for r in completed)
    min_threat = min(float(r["MinThreatMarginM"]) for r in completed)
    assert math.isclose(min_terrain, float(summary[alg]["min_terrain_clearance_m"]), rel_tol=1e-10, abs_tol=1e-8), alg
    assert math.isclose(min_threat, float(summary[alg]["min_threat_margin_m"]), rel_tol=1e-10, abs_tol=1e-8), alg
    print(f"OK E06 {alg}: {n} flights, {len(completed)} complete, {sum(truth(r['SafetyCompletion']) for r in x)} safety passed")
print("PASS: six groups checked; no original numerical records modified.")
