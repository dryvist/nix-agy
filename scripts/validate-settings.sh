#!/usr/bin/env bash
# Validate ~/.gemini/antigravity-cli/settings.json after home-manager merge.
#
# Arguments:
#   $1 - Target settings path (merged runtime file on disk)
#   $2 - Nix-generated baseline settings path (/nix/store)
#
# Environment (set by the Nix wrapper):
#   SCHEMA_FILE          - Vendored settings.schema.json (no network fetch)
#   FORBIDDEN_MODEL_NAMES - JSON array of router role names agy rejects
#   REPAIR_LEGACY        - When "1", repair known legacy drift (default "1")
#
# Exit codes:
#   0 - Valid (possibly after legacy repair)
#   1 - Invalid and unrepairable, or usage error

set -euo pipefail

TARGET="${1:-}"
BASELINE="${2:-}"
SCHEMA_FILE="${SCHEMA_FILE:?SCHEMA_FILE not set}"
FORBIDDEN_MODEL_NAMES="${FORBIDDEN_MODEL_NAMES:?FORBIDDEN_MODEL_NAMES not set}"
REPAIR_LEGACY="${REPAIR_LEGACY:-1}"

if [[ -z "$TARGET" || -z "$BASELINE" ]]; then
  echo "Usage: validate-gemini-settings <target-settings> <nix-baseline-settings>" >&2
  exit 1
fi

if [[ ! -f "$BASELINE" ]]; then
  echo "ERROR: Nix baseline settings missing: $BASELINE" >&2
  exit 1
fi

if [[ ! -f "$TARGET" ]]; then
  # First activation — merge step creates the file on the prior line.
  exit 0
fi

check_schema() {
  local file="$1"
  local label="$2"
  if ! check-jsonschema --schemafile "$SCHEMA_FILE" "$file"; then
    echo "ERROR: $label failed JSON Schema validation ($SCHEMA_FILE)" >&2
    return 1
  fi
}

check_policy_and_drift() {
  local file="$1"
  local errors=0

  local model_name
  model_name="$(jq -r '.model.name // empty' "$file")"
  if [[ -n "$model_name" ]]; then
    local forbidden
    while IFS= read -r forbidden; do
      [[ -n "$forbidden" ]] || continue
      if [[ "$model_name" == "$forbidden" ]]; then
        echo "ERROR: model.name '$model_name' is a LiteLLM router role, not a gemini-cli registry name — agy discards the entire settings file" >&2
        errors=1
      fi
    done < <(jq -r '.[]' <<< "$FORBIDDEN_MODEL_NAMES")
  fi

  local baseline_has_model target_has_model
  baseline_has_model="$(jq -r 'has("model")' "$BASELINE")"
  target_has_model="$(jq -r 'has("model")' "$file")"
  if [[ "$baseline_has_model" == "false" && "$target_has_model" == "true" ]]; then
    echo "ERROR: Nix baseline omits model but merged settings.json defines model (stale runtime drift)" >&2
    errors=1
  fi

  return "$errors"
}

repairable_drift() {
  local file="$1"
  if check_policy_and_drift "$file"; then
    return 1
  fi
  jq -e 'has("model")' "$file" >/dev/null 2>&1
}

validate_pair() {
  if [[ "${VALIDATE_SCHEMA:-0}" == "1" ]]; then
    check_schema "$BASELINE" "Nix baseline settings" || return 1
  fi
  check_policy_and_drift "$TARGET" || return 1
  return 0
}

if validate_pair; then
  exit 0
fi

if [[ "$REPAIR_LEGACY" == "1" ]] && repairable_drift "$TARGET"; then
  echo "Repairing legacy model drift in $TARGET (removing stale model key)" >&2
  umask 077
  jq 'del(.model)' "$TARGET" > "${TARGET}.tmp" \
    && mv "${TARGET}.tmp" "$TARGET" \
    && chmod 600 "$TARGET"
  if validate_pair; then
    echo "Legacy model drift repaired and validated" >&2
    exit 0
  fi
fi

echo "ERROR: Gemini CLI settings validation failed for $TARGET" >&2
exit 1
