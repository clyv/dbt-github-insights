import re

import pandas as pd


def model(dbt, session):
    dbt.config(materialized="table")

    df = dbt.ref("int_events_with_keys").df()

    bot_pattern = re.compile(r"\[bot\]$|-bot$|^bot-", re.IGNORECASE)
    ci_pattern = re.compile(
        r"^(travis|circleci|dependabot|renovate|snyk)", re.IGNORECASE
    )

    df["is_bot_actor"] = df["actor_login"].apply(
        lambda x: bool(bot_pattern.search(str(x))) if pd.notna(x) else False
    )
    df["is_ci_actor"] = df["actor_login"].apply(
        lambda x: bool(ci_pattern.match(str(x))) if pd.notna(x) else False
    )
    df["actor_login_clean"] = df["actor_login"].str.lower().str.strip()

    return df
