"""
Actor classification as a dbt Python model.

Why Python here and not SQL: the bot and CI-vendor rules are a maintained
list, not a fixed expression. In SQL each addition means editing a regex
literal buried in a CASE; here the vendor list is data at the top of the file
and the regex is derived from it. That is the only part of this DAG where
Python earns its place -- everything else stays SQL.

Runs locally on DuckDB, which executes Python models in-process. The
BigQuery/Dataproc path is handled inline below rather than in a second file.
"""

import re

# Accounts whose login itself marks them as a bot.
BOT_PATTERNS = [
    r"\[bot\]$",   # dependabot[bot], github-actions[bot]
    r"-bot$",      # renovate-bot, snyk-bot
    r"^bot-",      # bot-anything
]

# Automation vendors, matched on the login prefix. Deliberately overlaps
# BOT_PATTERNS: dependabot[bot] is both a bot account and a CI vendor, and
# mart_daily_repo_activity excludes either from human_events.
CI_VENDORS = [
    "travis",
    "circleci",
    "dependabot",
    "renovate",
    "snyk",
]

BOT_REGEX = "|".join(f"({p})" for p in BOT_PATTERNS)
CI_REGEX = r"^(" + "|".join(re.escape(v) for v in CI_VENDORS) + r")"


def model(dbt, session):
    dbt.config(materialized="table")

    # dbt.ref() returns a DuckDBPyRelation on dbt-duckdb and a PySpark
    # DataFrame on BigQuery/Dataproc. Normalise to pandas either way, and
    # hand the right type back at the end.
    #
    # The Spark path is written but not yet executed -- running Python models
    # on BigQuery needs Dataproc Serverless, which is not provisioned. See
    # profiles.yml.bigquery.example.
    rel = dbt.ref("int_events_with_keys")
    on_spark = not hasattr(rel, "df")
    df = rel.toPandas() if on_spark else rel.df()

    login = df["actor_login"]

    df["is_bot_actor"] = login.str.contains(BOT_REGEX, case=False, na=False, regex=True)
    df["is_ci_actor"] = login.str.contains(CI_REGEX, case=False, na=False, regex=True)
    df["actor_login_clean"] = login.str.strip().str.lower()

    # .df() widens a nullable BIGINT to float64 via NaN. Restore the integer
    # type so downstream sum(push_commit_count) stays an integer in the mart.
    if "push_commit_count" in df.columns:
        df["push_commit_count"] = df["push_commit_count"].astype("Int64")

    if on_spark:
        return session.createDataFrame(df)

    return df
