#!/usr/bin/env python3
"""Fetch GitHub traffic + release download data and upsert into CSVs."""

import csv
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

REPO   = "adamorad/portpeek"
OUTDIR = Path("data/traffic")
OUTDIR.mkdir(parents=True, exist_ok=True)
TODAY  = datetime.now(timezone.utc).strftime("%Y-%m-%d")


def gh_api(path):
    result = subprocess.run(
        ["gh", "api", path],
        capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)


def upsert_csv(path, rows, key_col):
    """Merge rows into CSV, keyed on key_col (no duplicates)."""
    existing = {}
    if path.exists():
        with open(path, newline="") as f:
            for row in csv.DictReader(f):
                existing[row[key_col]] = row

    for row in rows:
        existing[row[key_col]] = row

    fieldnames = list(rows[0].keys()) if rows else list(existing.values())[0].keys() if existing else []
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(sorted(existing.values(), key=lambda r: r[key_col]))


def append_csv(path, rows):
    """Append rows, skipping exact duplicates."""
    if not rows:
        return
    existing_lines = set()
    if path.exists():
        with open(path) as f:
            existing_lines = set(f.readlines())

    fieldnames = list(rows[0].keys())
    write_header = not path.exists()
    with open(path, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if write_header:
            writer.writeheader()
        for row in rows:
            line = ",".join(str(row[k]) for k in fieldnames) + "\n"
            if line not in existing_lines:
                writer.writerow(row)


# ── Views ─────────────────────────────────────────────────────
data = gh_api(f"/repos/{REPO}/traffic/views")
upsert_csv(
    OUTDIR / "views.csv",
    [{"date": v["timestamp"][:10], "views": v["count"], "uniques": v["uniques"]}
     for v in data["views"]],
    key_col="date",
)
print(f"Views: total={data['count']} uniques={data['uniques']}")

# ── Clones ────────────────────────────────────────────────────
data = gh_api(f"/repos/{REPO}/traffic/clones")
upsert_csv(
    OUTDIR / "clones.csv",
    [{"date": c["timestamp"][:10], "clones": c["count"], "uniques": c["uniques"]}
     for c in data["clones"]],
    key_col="date",
)
print(f"Clones: total={data['count']} uniques={data['uniques']}")

# ── Referrers ─────────────────────────────────────────────────
referrers = gh_api(f"/repos/{REPO}/traffic/popular/referrers")
append_csv(
    OUTDIR / "referrers.csv",
    [{"date": TODAY, "referrer": r["referrer"], "views": r["count"], "uniques": r["uniques"]}
     for r in referrers],
)
print(f"Referrers: {[r['referrer'] for r in referrers]}")

# ── Release downloads ─────────────────────────────────────────
releases = gh_api(f"/repos/{REPO}/releases")
rows = []
for rel in releases:
    for asset in rel.get("assets", []):
        rows.append({
            "date":      TODAY,
            "release":   rel["tag_name"],
            "asset":     asset["name"],
            "downloads": asset["download_count"],
        })
if rows:
    append_csv(OUTDIR / "downloads.csv", rows)
    for r in rows:
        print(f"Downloads: {r['release']}/{r['asset']} = {r['downloads']}")
