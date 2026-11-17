"""Read the existing Supabase capacity sample for an external monitor."""
import json
import os
import subprocess
import sys

QUERY = """
begin read only;
set local statement_timeout = '5s';
select jsonb_build_object(
  'age_seconds', extract(epoch from now() - sampled_at),
  'signals', signals
) from operations.capacity_state where singleton;
commit;
"""
SIGNALS = {
    "database_bytes", "wal_bytes", "visible_disk_bytes", "storage_bytes",
    "storage_unknown_sizes", "app_rows_per_minute", "wal_generated_bytes_per_minute",
    "excess_rollbacks_per_minute", "long_or_idle_api_transactions",
}
SEVERITY = {"warning": 1, "incident": 2, "critical": 2}
MAX_SAMPLE_AGE_SECONDS = 900


def evaluate(raw):
    """Return a stable, value-redacted status for a scheduler or monitor."""
    try:
        sample = json.loads(raw)
        age = sample["age_seconds"]
        signals = sample["signals"]
        if type(age) not in (int, float) or not isinstance(signals, dict):
            return 3, "Capacity sample invalid"
        if not 0 <= age <= MAX_SAMPLE_AGE_SECONDS:
            return 3, "Capacity sample stale or out of range"
        if any(name not in SIGNALS or not isinstance(level, str) or level not in SEVERITY
               for name, level in signals.items()):
            return 3, "Capacity sample contains unknown signals"
    except (ValueError, KeyError, TypeError, RecursionError):
        return 3, "Capacity sample unavailable or invalid"
    status = max((SEVERITY[level] for level in signals.values()), default=0)
    if not status:
        return 0, "Capacity sample healthy"
    detail = ", ".join(f"{name}={signals[name]}" for name in sorted(signals))
    return status, f"Capacity signals: {detail}"


def check():
    if not os.environ.get("PGSERVICE"):
        return 3, "Capacity check requires a dedicated PostgreSQL service"
    try:
        result = subprocess.run(
            ["psql", "--no-psqlrc", "--no-password", "--quiet", "--tuples-only",
             "--no-align", "--set=ON_ERROR_STOP=1", "--command", QUERY],
            capture_output=True, text=True, timeout=12, check=True,
        )
    except (OSError, subprocess.SubprocessError, UnicodeError):
        return 3, "Capacity sample read failed"
    return evaluate(result.stdout)


if __name__ == "__main__":
    exit_code, message = check()
    print(message)
    sys.exit(exit_code)
