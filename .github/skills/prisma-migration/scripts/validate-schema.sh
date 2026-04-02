#!/usr/bin/env bash
# validate-schema.sh — Validates the Prisma schema and reports migration status.
#
# Usage:
#   bash .github/skills/prisma-migration/scripts/validate-schema.sh
#
# Checks performed:
#   1. Prisma schema syntax validation   (prisma validate)
#   2. Pending migration detection       (prisma migrate status)
#   3. Convention checks:
#        - All models have a UUID primary key
#        - All models have a createdAt timestamp
#        - All String FK fields use @db.Uuid

set -euo pipefail

SCHEMA_FILE="prisma/schema.prisma"
PASS=0
FAIL=0

print_ok()   { echo "  [OK]   $1"; PASS=$((PASS + 1)); }
print_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
print_warn() { echo "  [WARN] $1"; }
section()    { echo ""; echo "── $1 ──────────────────────────────────────────"; }

# ── 0. Pre-flight ─────────────────────────────────────────────────────────────
if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "Error: $SCHEMA_FILE not found. Run this script from the project root."
  exit 1
fi

echo "Prisma Schema Validator"
echo "Schema: $SCHEMA_FILE"

# ── 1. Prisma syntax validation ───────────────────────────────────────────────
section "Syntax Validation"
if npx prisma validate --schema="$SCHEMA_FILE" 2>&1; then
  print_ok "Schema syntax is valid"
else
  print_fail "Schema has syntax errors — fix them before running migrations"
fi

# ── 2. Migration status ───────────────────────────────────────────────────────
section "Migration Status"
MIGRATE_OUTPUT=$(timeout 10 npx prisma migrate status --schema="$SCHEMA_FILE" 2>&1) && MIGRATE_EXIT=0 || MIGRATE_EXIT=$?

if [[ $MIGRATE_EXIT -eq 124 ]]; then
  print_warn "Migration status timed out (no DB connection?) — skipping"
elif [[ $MIGRATE_EXIT -eq 0 ]]; then
  print_ok "No pending migrations"
  echo "$MIGRATE_OUTPUT"
else
  echo "$MIGRATE_OUTPUT"
  print_warn "Pending or failed migrations detected — run: npx prisma migrate dev --name <description>"
fi

# ── 3. Convention checks (grep-based, no Prisma CLI required) ─────────────────
section "Convention Checks"

# Extract model names
MODELS=$(grep -E '^model [A-Z]' "$SCHEMA_FILE" | awk '{print $2}')

if [[ -z "$MODELS" ]]; then
  print_warn "No models found in schema"
else
  for MODEL in $MODELS; do
    # Extract lines belonging to this model block
    MODEL_BLOCK=$(awk "/^model ${MODEL} \{/,/^\}/" "$SCHEMA_FILE")

    # Check: UUID primary key convention
    if echo "$MODEL_BLOCK" | grep -qE 'id\s+String\s+@id\s+@default\(uuid\(\)\)\s+@db\.Uuid'; then
      print_ok "${MODEL}: UUID primary key (@id @default(uuid()) @db.Uuid)"
    else
      print_fail "${MODEL}: Missing or non-standard primary key — expected: id String @id @default(uuid()) @db.Uuid"
    fi

    # Check: createdAt timestamp
    if echo "$MODEL_BLOCK" | grep -qE 'createdAt\s+DateTime\s+@default\(now\(\)\)'; then
      print_ok "${MODEL}: createdAt timestamp present"
    else
      print_fail "${MODEL}: Missing createdAt DateTime @default(now())"
    fi

    # Check: FK scalar fields use @db.Uuid (any field ending in Id that is String)
    FK_FIELDS=$(echo "$MODEL_BLOCK" | grep -E '[a-zA-Z]+Id\s+String' || true)
    if [[ -n "$FK_FIELDS" ]]; then
      MISSING_UUID=$(echo "$FK_FIELDS" | grep -v '@db\.Uuid' || true)
      if [[ -z "$MISSING_UUID" ]]; then
        print_ok "${MODEL}: All FK scalar fields use @db.Uuid"
      else
        while IFS= read -r LINE; do
          FIELD=$(echo "$LINE" | awk '{print $1}')
          print_fail "${MODEL}.${FIELD}: FK field is missing @db.Uuid annotation"
        done <<< "$MISSING_UUID"
      fi
    fi

    # Check: relations using onDelete but missing Cascade
    RELATIONS_WITHOUT_CASCADE=$(echo "$MODEL_BLOCK" | grep -E 'onDelete' | grep -v 'Cascade' || true)
    if [[ -n "$RELATIONS_WITHOUT_CASCADE" ]]; then
      print_warn "${MODEL}: Relation uses onDelete but not Cascade — verify this is intentional"
    fi
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
section "Summary"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "Schema has $FAIL convention violation(s). Fix them before creating a migration."
  exit 1
else
  echo "All checks passed. Schema is ready for migration."
  exit 0
fi
