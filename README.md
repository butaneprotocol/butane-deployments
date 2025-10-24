# Butane Blueprint Parameterization

This repository contains the deployment artifacts for the Butane protocol's on-chain blueprint. It holds a vanilla (parameter-free) Aiken blueprint and a helper script that stamps environment-specific parameters into the blueprint prior to deployment.

## Repository Layout

- `butane-v1-base.json` – Exported Aiken blueprint produced at build time. All validators exist, but any deployment-time parameters (keys, policies, UTXOs) are intentionally blank.
- `butane-v1-deployed.json` – The blueprint with deployment parameters applied. This file is overwritten by the helper script each time you run it.
- `apply-params.sh` – Main orchestration script that derives payloads and feeds them to `aiken blueprint apply`.

## Script Workflow

`apply-params.sh` transforms the base blueprint into a deployment-ready artifact. The script is broken into logical stages:

1. **Upgradeable control state** – Seeds the blueprint with the origin UTXO that anchors the deployment and applies a salt to the control-state validator. The resulting hash is reused later.
2. **Pointer scripts** – Applies pointer mint and spend validators. The mint validator is stamped twice: once with the control-state anchor and once with a vanity policy parameter.
3. **Synthetics staking hooks** – Binds the pointer scripts to the synthetic staking validator, enabling the synthetic contracts to reference the pointer hashes.
4. **Price feed** – Injects the oracle verification key into `price_feed.check_feed` and captures the resulting script hash.
5. **Treasury validation** – Provides the pointer and price-feed hashes to the treasury validator.
6. **Governance validation** – Supplies governance NFT policy/asset names, pointers, and price-feed hash to the governance validator.
7. **Synthetics main validator** – Reuses the gathered hashes (governance, treasury, price feed, leftovers, staking) along with the synthetic BTN and redemption NFT identifiers to finish the main synthetic validator configuration.

Each stage depends on values produced earlier in the run. For example, the pointer script hashes are harvested via `jq` and later injected into treasury, governance, and synthetics validators. The script centralizes all payload generation (UTXO, policy/asset pairs, script hashes) so refactors can be performed in one place.

## Relationship Between Referenced Scripts

`apply-params.sh` references validator titles found in the Aiken blueprint (`module.validator` naming):

- `upgradeable.control_state` – Base validator parameterized with the deployment UTXO and salt; its hash establishes upgrade control.
- `pointers.mint` / `pointers.spend` – Validators that manage pointer tokens; their hashes are prerequisites for staking and synthetic logic.
- `price_feed.check_feed` – Oracle check validator that requires the external oracle key.
- `synthetics.external_staking_validate` – Bridges the pointer validators into the broader synthetics context.
- `synthetics.external_treas_validate` – Treasury guard that trusts only the minted pointer scripts and price feed.
- `synthetics.external_gov_validate` – Governance guard that validates governance NFTs, pointer scripts, and oracle proofs.
- `synthetics.validate` – The main synthetics validator that stitches together BTN policy details, redemption NFT identifiers, and all referenced validator hashes.
- `leftovers.collect` – Validator used to drain leftovers; its hash becomes one of the dependencies of `synthetics.validate`.

Although these validators live inside the JSON blueprint, the script treats them like command targets: each `aiken blueprint apply` invocation points at one validator, passes the required payload, and captures any hashes needed downstream.

## Usage

```bash
./apply-params.sh
```

The script validates the presence of `aiken` and `jq`, ensures `butane-v1-base.json` exists, and then rewrites `butane-v1-deployed.json` in place. Re-run the script only when starting from a clean copy of the base file.

## Prerequisites

- macOS or Linux with Bash 4+
- `aiken` CLI v1.0.14 or newer
- `jq`

## Customization

Update the constant section near the top of `apply-params.sh` to change:

- Deployment anchoring UTXO (`INIT_TX_HASH`, `INIT_OUTPUT_INDEX`)
- Vanity policy (`POINTER_VANITY_PARAM`)
- Oracle verification key (`ORACLE_KEY`)
- Governance and BTN policy/asset names
- Redemption NFT identifiers

Once adjusted, run the script again to regenerate `butane-v1-deployed.json` with the new parameters.
