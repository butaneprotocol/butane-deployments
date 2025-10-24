#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script        : apply-params.sh
# Purpose       : Stamp deployment-specific parameters onto the base Aiken
#                 blueprint and produce `butane-v1-deployed.json`.
# Requirements  : `aiken` (v1.0.14+) on PATH, `jq`, write access to the current
#                 directory.
# Usage         : Review the UTXOs, policies, and keys below, then run:
#                     `./apply-params.sh`
# Notes         : The script must run from the repository root so relative paths
#                 resolve. Each `aiken blueprint apply` call mutates
#                 `butane-v1-deployed.json` in place, so re-run the script only
#                 when starting from a fresh copy of `butane-v1-base.json`.
# -----------------------------------------------------------------------------
set -euo pipefail

BASE_BLUEPRINT="butane-v1-base.json"
DEPLOYED_BLUEPRINT="butane-v1-deployed.json"

INIT_TX_HASH="4cd48455f0db64906b042f84d035525425cb44f7f2cfaae9fdc533cbd3f94af9"
INIT_OUTPUT_INDEX="02"
SALT_PARAM="00"
POINTER_VANITY_PARAM="485485fbd6794319e0"
ORACLE_KEY="3cd63c27c9b3e7c9fef1eae2e5c6076baaa2480d9cbae1cd2681a80123193549"
GOV_NFT_POLICY="f0932eda096e3bb711a2de60ef192deeac7871e1f67e57ea5895b65f"
GOV_NFT_ASSET_NAME="676f76"
BTN_POLICY="016be5325fd988fea98ad422fcfd53e5352cacfced5c106a932a35a4"
BTN_ASSET_NAME="42544e"
REDEMPTION_NFT_POLICY="63f51f7153439e122f8a9c35e8a12a92c409aff318df4c8aea10ad39"
REDEMPTION_NFT_ASSET_NAME="726564"

if [[ -t 1 ]]; then
  COLOR_TITLE=$'\033[95m'
  COLOR_STEP=$'\033[36m'
  COLOR_INFO=$'\033[32m'
  COLOR_WARN=$'\033[33m'
  COLOR_ERROR=$'\033[31m'
  COLOR_RESET=$'\033[0m'
else
  COLOR_TITLE=""
  COLOR_STEP=""
  COLOR_INFO=""
  COLOR_WARN=""
  COLOR_ERROR=""
  COLOR_RESET=""
fi

log_title()   { printf "%s%s%s\n" "$COLOR_TITLE" "$1" "$COLOR_RESET"; }
log_step()    { printf "  %s→%s %s\n" "$COLOR_STEP" "$COLOR_RESET" "$1"; }
log_info()    { printf "    %s•%s %s\n" "$COLOR_INFO" "$COLOR_RESET" "$1"; }
log_warn()    { printf "    %s!%s %s\n" "$COLOR_WARN" "$COLOR_RESET" "$1"; }
log_error()   { printf "%sError:%s %s\n" "$COLOR_ERROR" "$COLOR_RESET" "$1" >&2; }

ensure_file() {
  local file=$1
  if [[ ! -f "$file" ]]; then
    log_error "Missing required file: $file"
    exit 1
  fi
}

require_tool() {
  local tool=$1
  if ! command -v "$tool" >/dev/null 2>&1; then
    log_error "Missing required tool: $tool"
    exit 1
  fi
}

apply_param() {
  local source=$1
  local module=$2
  local validator=$3
  local value=$4

  log_step "${module}.${validator}"
  aiken blueprint apply \
    --in "$source" \
    -m "$module" \
    -v "$validator" \
    --out "$DEPLOYED_BLUEPRINT" \
    "$value"
}

hash_for_validator() {
  local title=$1
  local hash

  hash=$(jq -r --arg title "$title" '.validators[] | select(.title == $title).hash' "$DEPLOYED_BLUEPRINT")
  if [[ -z "$hash" || "$hash" == "null" ]]; then
    log_error "Unable to locate validator hash for '$title'"
    exit 1
  fi

  printf "%s" "$hash"
}

payload_utxo() {
  printf 'd8799fd8799f5820%sff%sff' "$INIT_TX_HASH" "$INIT_OUTPUT_INDEX"
}

payload_pointer_anchor() {
  local script_hash=$1
  printf 'd8799fd87a9f581c%sffff' "$script_hash"
}

payload_script_hash() {
  local script_hash=$1
  printf '581c%s' "$script_hash"
}

payload_policy_asset() {
  local policy_id=$1
  local asset_name=$2
  printf 'd8799f581c%s43%sff' "$policy_id" "$asset_name"
}

log_title "Butane Blueprint Parameterization"

require_tool aiken
require_tool jq
ensure_file "$BASE_BLUEPRINT"

log_warn "Ensure ${DEPLOYED_BLUEPRINT} is disposable; it will be rewritten."

apply_param "$BASE_BLUEPRINT" upgradeable control_state "$(payload_utxo)"
apply_param "$DEPLOYED_BLUEPRINT" upgradeable control_state "$SALT_PARAM"

UPGRADEABLE_SCRIPT_HASH=$(hash_for_validator "upgradeable.control_state")
log_info "Upgradeable script hash: ${UPGRADEABLE_SCRIPT_HASH}"

apply_param "$DEPLOYED_BLUEPRINT" pointers mint "$(payload_pointer_anchor "$UPGRADEABLE_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" pointers mint "$POINTER_VANITY_PARAM"
apply_param "$DEPLOYED_BLUEPRINT" pointers spend "$(payload_pointer_anchor "$UPGRADEABLE_SCRIPT_HASH")"

MINT_SCRIPT_HASH=$(hash_for_validator "pointers.mint")
SPEND_SCRIPT_HASH=$(hash_for_validator "pointers.spend")
log_info "Pointer mint hash: ${MINT_SCRIPT_HASH}"
log_info "Pointer spend hash: ${SPEND_SCRIPT_HASH}"

apply_param "$DEPLOYED_BLUEPRINT" synthetics external_staking_validate "$(payload_script_hash "$MINT_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics external_staking_validate "$(payload_script_hash "$SPEND_SCRIPT_HASH")"

apply_param "$DEPLOYED_BLUEPRINT" price_feed check_feed "$(payload_script_hash "$ORACLE_KEY")"
PRICE_FEED_SCRIPT_HASH=$(hash_for_validator "price_feed.check_feed")
log_info "Price feed hash: ${PRICE_FEED_SCRIPT_HASH}"

apply_param "$DEPLOYED_BLUEPRINT" synthetics external_treas_validate "$(payload_script_hash "$MINT_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics external_treas_validate "$(payload_script_hash "$SPEND_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics external_treas_validate "$(payload_script_hash "$PRICE_FEED_SCRIPT_HASH")"

TREASURY_VALIDATION_SCRIPT_HASH=$(hash_for_validator "synthetics.external_treas_validate")
log_info "Treasury validation hash: ${TREASURY_VALIDATION_SCRIPT_HASH}"

apply_param "$DEPLOYED_BLUEPRINT" synthetics external_gov_validate "$(payload_policy_asset "$GOV_NFT_POLICY" "$GOV_NFT_ASSET_NAME")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics external_gov_validate "$(payload_script_hash "$MINT_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics external_gov_validate "$(payload_script_hash "$SPEND_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics external_gov_validate "$(payload_policy_asset "$BTN_POLICY" "$BTN_ASSET_NAME")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics external_gov_validate "$(payload_script_hash "$PRICE_FEED_SCRIPT_HASH")"

GOVERNANCE_VALIDATION_SCRIPT_HASH=$(hash_for_validator "synthetics.external_gov_validate")
log_info "Governance validation hash: ${GOVERNANCE_VALIDATION_SCRIPT_HASH}"

apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_policy_asset "$BTN_POLICY" "$BTN_ASSET_NAME")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_script_hash "$MINT_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_script_hash "$SPEND_SCRIPT_HASH")"

LEFTOVERS_SCRIPT_HASH=$(hash_for_validator "leftovers.collect")
log_info "Leftovers script hash: ${LEFTOVERS_SCRIPT_HASH}"
apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_script_hash "$LEFTOVERS_SCRIPT_HASH")"

apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_policy_asset "$REDEMPTION_NFT_POLICY" "$REDEMPTION_NFT_ASSET_NAME")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_script_hash "$GOVERNANCE_VALIDATION_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_script_hash "$TREASURY_VALIDATION_SCRIPT_HASH")"
apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_script_hash "$PRICE_FEED_SCRIPT_HASH")"

SYNTHETICS_STAKING_SCRIPT_HASH=$(hash_for_validator "synthetics.external_staking_validate")
log_info "Synthetics staking hash: ${SYNTHETICS_STAKING_SCRIPT_HASH}"
apply_param "$DEPLOYED_BLUEPRINT" synthetics validate "$(payload_script_hash "$SYNTHETICS_STAKING_SCRIPT_HASH")"

log_info "Parameterization complete → ${DEPLOYED_BLUEPRINT}"
