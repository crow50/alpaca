"""Prints what a generated range actually contains (used by the `cli` check)."""
import glob
import json

for path in glob.glob("/tmp/alpaca/ranges/*/range_metadata.json"):
    meta = json.load(open(path))
    lattices = [{"exploit_steps": len(l["vulns"]), "config": l["config"]} for l in meta["lattices"]]
    print("   -> what was generated: lattices =", lattices)
