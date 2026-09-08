"""
Parse every SQL model as BigQuery SQL without touching GCP.

The BigQuery target cannot be executed here -- there is no GCP project, so
`dbt build --target bigquery` has never run. That leaves the BigQuery branches
of the dual-target models unexercised, which is exactly the kind of code that
rots. This script closes most of the gap: it renders each model's Jinja with
target.type = 'bigquery' and parses the result with sqlglot's BigQuery
dialect.

It validates syntax and dialect-specific builtins. It does NOT validate that
column names exist in githubarchive.day.*, or that the query is cheap. Those
need a real first run.

Usage:
    python scripts/validate_bigquery_sql.py

Exits non-zero on the first dialect error, so it works as a CI gate.
"""

import glob
import os
import sys

try:
    import jinja2
    import sqlglot
    from sqlglot.errors import ParseError
except ImportError:
    sys.exit("pip install jinja2 sqlglot")


class Target:
    """Stands in for dbt's `target` context variable."""

    type = "bigquery"
    name = "bigquery"


class DbtUtils:
    """Stubs the dbt_utils macros this project calls."""

    @staticmethod
    def generate_surrogate_key(columns):
        joined = ", ".join(f"coalesce(cast({c} as string), '')" for c in columns)
        return f"to_hex(md5(concat({joined})))"


def ref(*parts):
    return "`project`.`dataset`." + parts[-1]


def source(_source_name, _table_name):
    return "`githubarchive`.`day`.`20240101`"


def config(**_kwargs):
    return ""


def var(_name, default=None):
    return default


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    env = jinja2.Environment()
    context = {
        "target": Target(),
        "ref": ref,
        "source": source,
        "config": config,
        "var": var,
        "dbt_utils": DbtUtils(),
    }

    failures = []
    checked = 0

    for path in sorted(glob.glob("models/**/*.sql", recursive=True)):
        raw = open(path, encoding="utf-8").read()
        rendered = env.from_string(raw).render(**context).strip()

        if not rendered:
            failures.append((path, "rendered to empty SQL"))
            continue

        try:
            sqlglot.parse_one(rendered, dialect="bigquery")
        except ParseError as exc:
            failures.append((path, str(exc).splitlines()[0]))
            print(f"  FAIL  {path}")
            continue

        checked += 1
        print(f"  ok    {path}")

    print()
    if failures:
        for path, err in failures:
            print(f"FAILED {path}\n       {err}")
        return 1

    print(f"{checked} model(s) parse as valid BigQuery SQL.")
    print("Note: int_actor_login_cleaned is a Python model and is not covered here.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
