"""
Assert the Mermaid DAG in README.md still matches the real lineage.

The README embeds the lineage as a hand-maintained Mermaid diagram rather than
a committed screenshot, so it renders on GitHub and diffs like code. The risk
with any hand-maintained diagram is that it drifts from the DAG it claims to
describe. This closes that: it extracts the edges from the README block and
compares them to model dependencies in target/manifest.json.

Run `dbt compile` (or any build) first so the manifest exists.

Usage:
    python scripts/check_lineage_diagram.py

Exits non-zero on any drift, so it works as a CI gate alongside
scripts/validate_bigquery_sql.py.
"""

import io
import json
import os
import re
import sys

MANIFEST = os.path.join("target", "manifest.json")


def manifest_edges(path):
    with io.open(path, encoding="utf-8") as fh:
        manifest = json.load(fh)

    edges = set()
    for node in manifest["nodes"].values():
        if node["resource_type"] != "model":
            continue
        for parent in node["depends_on"]["nodes"]:
            edges.add((parent.split(".")[-1], node["name"]))
    return edges


def readme_edges(path):
    with io.open(path, encoding="utf-8") as fh:
        readme = fh.read()

    match = re.search(r"```mermaid\n(.*?)\n```", readme, re.S)
    if not match:
        raise SystemExit("No ```mermaid block found in README.md")
    block = match.group(1)

    # node id -> the first line of its label, which is the model name
    labels = {}
    for node_id, label in re.findall(r'(\w+)\[+\(?"([^"]+)"', block):
        labels[node_id] = label.split("<br/>")[0].strip()

    edges = set()
    for left, right in re.findall(r"^\s*(\w+)\s*-->\s*(\w+)\s*$", block, re.M):
        edges.add((labels.get(left, left), labels.get(right, right)))
    return edges


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    if not os.path.exists(MANIFEST):
        raise SystemExit(f"{MANIFEST} not found -- run `dbt compile` first.")

    real = manifest_edges(MANIFEST)
    documented = readme_edges("README.md")

    missing = sorted(real - documented)
    extra = sorted(documented - real)

    if not missing and not extra:
        print(f"README lineage diagram matches the manifest ({len(real)} edges).")
        return 0

    print("README lineage diagram has drifted from the DAG.\n")
    for parent, child in missing:
        print(f"  in the DAG but missing from the README:  {parent} -> {child}")
    for parent, child in extra:
        print(f"  in the README but not in the DAG:        {parent} -> {child}")
    print("\nUpdate the ```mermaid block in README.md.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
