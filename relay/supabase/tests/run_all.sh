#!/usr/bin/env bash
# Run all Supabase RLS/schema tests via psql.
# Usage: ./run_all.sh "$DATABASE_URL"
#    or: DATABASE_URL=... ./run_all.sh

set -euo pipefail

DB_URL="${1:-${DATABASE_URL:-}}"
if [ -z "$DB_URL" ]; then
    echo "ERROR: Pass DATABASE_URL as argument or env var."
    echo "  Find it at: Supabase Dashboard > Settings > Database > Connection string (URI)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

for sql_file in "$SCRIPT_DIR"/0*.sql; do
    filename="$(basename "$sql_file")"
    echo ""
    echo "=== $filename ==="

    output=$(psql "$DB_URL" -v ON_ERROR_STOP=0 -f "$sql_file" 2>&1) || true

    # Count PASS/FAIL (psql NOTICE has two spaces: "NOTICE:  PASS:")
    file_pass=$(echo "$output" | grep -c "PASS:" || true)
    file_fail=$(echo "$output" | grep -c "FAIL:" || true)
    PASS=$((PASS + file_pass))
    FAIL=$((FAIL + file_fail))

    # Show results
    echo "$output" | grep -E "(PASS:|FAIL:)" || true

    if [ "$file_fail" -gt 0 ]; then
        echo "--- $filename: ${file_fail} FAILED ---"
        echo "$output" | grep "ERROR:" || true
    fi
done

echo ""
echo "================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
