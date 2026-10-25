"""Offline source-contract checks, NOT PostgreSQL execution or RLS proof.

Run: python -m pytest supabase/tests/test_health_observation_schema_contract.py -q
Only pathlib/re/hashlib and pytest are used; there is no database/network client.
"""
import hashlib
import re
from collections import Counter
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"
PROPOSAL = MIGRATIONS / "20261025120000_health_observation_persistence.sql"
DART = (ROOT / "Auracare_mobile_app/auracare_mobile_app/lib/data/records.dart").read_text(encoding="utf-8")
SOURCE = PROPOSAL.read_text(encoding="utf-8")
SQL = re.sub(r"--[^\n]*", "", SOURCE)
COMPACT = re.sub(r"\s+", " ", SQL).strip().lower()


def dart_enum(name):
    body = re.search(rf"enum {name}\s*\{{([^;}}]+)", DART).group(1)
    return set(re.findall(r"\b[a-z][A-Za-z]*\b", body))


def sql_enum(column):
    body = re.search(rf"check\s*\(\s*{column}\s+in\s*\(([^)]+)\)", SQL).group(1)
    return set(re.findall(r"'([^']+)'", body))


def column_grant(operation):
    match = re.search(rf"grant {operation}\s*\(([^)]+)\)\s+on table public.health_observations to authenticated", SQL, re.S)
    assert match, f"Missing scoped {operation} column grant"
    return set(re.findall(r"\b[a-z_]+\b", match.group(1)))


def test_new_version_is_valid_and_distinct_from_existing_versions():
    version = PROPOSAL.name.split("_", 1)[0]
    assert re.fullmatch(r"\d{14}", version)
    from datetime import datetime
    datetime.strptime(version, "%Y%m%d%H%M%S")
    versions = Counter(p.name.split("_", 1)[0] for p in MIGRATIONS.glob("*.sql"))
    assert versions[version] == 1
    assert version > max(p.name.split("_", 1)[0] for p in MIGRATIONS.glob("*.sql") if p != PROPOSAL)


@pytest.mark.parametrize("filename, expected", [
    ("20261025_initial_schema.sql", "bb6f44ca89a01bfa32d32448d66889d22ba9ab329a9dba6522a373be761446b7"),
    ("20261025_extended_features.sql", "2de06dde1247274d5ac302b86c21767d0950272c9e994f0384560774fa4c1dcd"),
])
def test_existing_migration_text_is_unchanged(filename, expected):
    normalized = (MIGRATIONS / filename).read_text(encoding="utf-8").replace("\r\n", "\n")
    assert hashlib.sha256(normalized.encode()).hexdigest() == expected


def test_transaction_and_only_additive_schema_targets():
    assert COMPACT.startswith("begin;") and COMPACT.endswith("commit;")
    assert re.findall(r"create table\s+([\w.]+)", SQL) == ["public.health_observations"]
    assert set(re.findall(r"alter table\s+([\w.]+)", SQL)) == {"public.journal_entries", "public.health_observations"}
    assert re.findall(r"\bdrop\s+constraint\s+(\w+)", SQL, re.I) == ["journal_entries_body_check"]
    assert not re.search(r"\b(drop\s+(?:table|column|schema)|truncate|security\s+definer)\b", SQL, re.I)
    assert "check (char_length(body) between 0 and 50000)" in SQL
    assert not re.search(r"\b(insert\s+into|update\s+public\.|delete\s+from|alter\s+policy|create\s+or\s+replace)\b", SQL, re.I)


def test_journal_columns_preserve_unknown_times_without_backfill():
    block = re.search(r"alter table public.journal_entries(.*?);", SQL, re.S).group(1)
    assert set(re.findall(r"add column\s+(\w+)", block)) == {
        "entry_time", "entry_is_utc", "client_request_id", "severity", "mood_category",
        "period_start", "period_end", "tracking_amount", "tracking_color",
        "tracking_consistency", "tracking_odor_change", "tracking_irritation"}
    assert "time(6) without time zone" in block
    for column in ("entry_time", "entry_is_utc"):
        line = re.search(rf"add column {column}[^\n]*", block).group()
        assert not re.search(r"\b(default|not\s+null)\b", line)
    assert "(entry_time is null) = (entry_is_utc is null)" in block
    assert "entry_time < time '24:00:00'" in block
    assert not re.search(r"policy\s+\w+\s+on\s+public.journal_entries", SQL)


@pytest.mark.parametrize("dart_name, column", [
    ("EntryType", "kind"), ("Severity", "severity"), ("RecordedMood", "mood_category"),
    ("TrackingAmount", "tracking_amount"), ("ObservationAnswer", "tracking_odor_change"),
    ("ObservationAnswer", "tracking_irritation"),
])
def test_every_flutter_enum_value_has_exact_sql_representation(dart_name, column):
    values = dart_enum(dart_name)
    if dart_name == "EntryType":
        values.remove("journal")  # Routed to journal_entries, never duplicated here.
    assert sql_enum(column) == values


def test_model_fields_have_structured_columns_not_hidden_note_payloads():
    required = {"id", "user_id", "kind", "title", "notes", "observation_date",
                "observation_time", "observation_is_utc", "timezone_label", "severity",
                "mood_category", "period_start", "period_end", "tracking_amount",
                "tracking_color", "tracking_consistency", "tracking_odor_change",
                "tracking_irritation", "created_at", "updated_at", "version", "client_request_id"}
    definitions = set(re.findall(r"^    (\w+)\s+(?:uuid|text|date|time\(6\)|boolean|timestamptz|bigint)(?=\s|,)", SQL, re.M))
    assert definitions == required
    assert "notes text not null default '' check (char_length(notes) <= 2000)" in SQL
    for field in ("tracking_color", "tracking_consistency"):
        assert f"char_length({field}) <= 80" in SQL
    assert "tracking_amount is not null or" in SQL
    for field in ("tracking_color", "tracking_consistency", "tracking_odor_change", "tracking_irritation"):
        assert f"{field} is null" in SQL


def test_nominal_timestamps_are_distinct_from_audit_instants():
    assert "observation_time time(6) without time zone not null" in SQL
    assert "observation_is_utc boolean not null" in SQL
    assert "observation_time < time '24:00:00'" in SQL
    assert "between date '0001-01-01' and date '9999-12-31'" in SQL
    assert "created_at timestamptz not null default now()" in SQL
    assert "updated_at timestamptz not null default now()" in SQL
    assert "at time zone" not in COMPACT and "coalesce" not in COMPACT


def test_multiple_same_day_observations_are_not_deduplicated():
    assert re.findall(r"\bunique\s*\(([^)]+)\)", SQL, re.I) == [
        "user_id, client_request_id", "user_id, client_request_id"]
    assert "id uuid primary key default gen_random_uuid()" in SQL
    for name in ("owner_time_idx", "owner_kind_time_idx"):
        assert f"create index health_observations_{name}" in SQL
    assert "(user_id, observation_date desc, observation_time desc, id desc)" in SQL
    assert "(user_id, kind, observation_date desc, observation_time desc, id desc)" in SQL


def test_unknown_flags_and_categories_are_not_defaulted_to_absence():
    for name in ("period_start", "period_end"):
        assert re.search(rf"^    {name} boolean,", SQL, re.M)
    for name in ("mood_category", "tracking_amount", "tracking_odor_change", "tracking_irritation"):
        line = re.search(rf"^    {name} text[^\n]*", SQL, re.M).group()
        assert "not null" not in line and "default" not in line


def test_ownership_and_metadata_are_not_client_writable():
    assert "user_id uuid not null default auth.uid()" in SQL
    assert "references auth.users (id) on delete cascade" in SQL
    for operation in ("insert", "update"):
        assert column_grant(operation).isdisjoint({"user_id", "created_at", "updated_at", "version"})
    assert "id" not in column_grant("insert") | column_grant("update")
    assert column_grant("insert") - {"client_request_id"} == column_grant("update")
    for operation in ("insert", "update"):
        journal_grant = re.search(rf"grant {operation}\s*\(([^)]+)\)\s+on table public.journal_entries to authenticated", SQL, re.S)
        assert journal_grant
        assert set(re.findall(r"\b[a-z_]+\b", journal_grant.group(1))).isdisjoint(
            {"id", "user_id", "created_at", "updated_at", "version"})
    assert "revoke insert, update on table public.journal_entries from authenticated;" in SQL


def test_default_grants_are_revoked_and_no_broad_write_grant_exists():
    assert "revoke all on table public.health_observations from public, anon, authenticated;" in SQL
    assert "grant select, delete on table public.health_observations to authenticated;" in SQL
    assert not re.search(r"grant\s+(?:all|insert|update)\s+on", SQL, re.I)
    assert not re.search(r"grant\s+[^;]+\s+to\s+(?:public|anon)\s*;", SQL, re.I)


@pytest.mark.parametrize("operation", ["select", "insert", "update", "delete"])
def test_each_operation_has_owner_only_rls(operation):
    assert "alter table public.health_observations enable row level security;" in SQL
    policies = re.findall(r"create policy ([^;]+);", COMPACT)
    assert len(policies) == 4
    policy = next(p for p in policies if f"for {operation} " in p)
    assert "on public.health_observations" in policy
    assert "to authenticated" in policy
    if operation != "insert":
        assert "using ((select auth.uid()) = user_id)" in policy
    if operation in ("insert", "update"):
        assert "with check ((select auth.uid()) = user_id)" in policy
    assert "using (true)" not in policy


def test_metadata_uses_existing_server_trigger_and_client_cas_is_documented():
    assert "before insert or update on public.health_observations" in SQL
    assert "for each row execute function public.set_record_metadata();" in SQL
    assert "version bigint not null default 1 check (version > 0)" in SQL
    existing = (MIGRATIONS / "20261025_initial_schema.sql").read_text(encoding="utf-8")
    assert "new.version := 1;" in existing and "new.version := old.version + 1;" in existing
    assert "Clients must condition updates AND deletes on owner, id and expected version" in SOURCE
