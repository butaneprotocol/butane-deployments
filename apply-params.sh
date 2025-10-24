# USES AIKEN-CLI TO VERIFY DEPLOYMENT DETAILS

# Input UTXO
# 4cd48455f0db64906b042f84d035525425cb44f7f2cfaae9fdc533cbd3f94af9#2
INIT_TXHASH="4cd48455f0db64906b042f84d035525425cb44f7f2cfaae9fdc533cbd3f94af9"
INIT_OUTPUTINDEX="02"
aiken blueprint apply --in butane.json -m upgradeable -v control_state --out butane-deployed.json "d8799fd8799f5820${INIT_TXHASH}ff${INIT_OUTPUTINDEX}ff"

# SALT
aiken blueprint apply --in butane-deployed.json -m upgradeable -v control_state --out butane-deployed.json "00"

UPGRADEABLE_SCRIPT_HASH=$(jq -r '.validators[] | select(.title == "upgradeable.control_state").hash' butane-deployed.json)

echo "UPGRADEABLE_SCRIPT_HASH: ${UPGRADEABLE_SCRIPT_HASH}"

# The pointers
# POINTER MINT
aiken blueprint apply --in butane-deployed.json -m pointers -v mint --out butane-deployed.json "d8799fd87a9f581c${UPGRADEABLE_SCRIPT_HASH}ffff"
# This is a value we mined for, to get a vanity policy
aiken blueprint apply --in butane-deployed.json -m pointers -v mint --out butane-deployed.json "485485fbd6794319e0"

# POINTER SPEND
aiken blueprint apply --in butane-deployed.json -m pointers -v spend --out butane-deployed.json "d8799fd87a9f581c${UPGRADEABLE_SCRIPT_HASH}ffff"

MINT_SCRIPT_HASH=$(jq -r '.validators[] | select(.title == "pointers.mint").hash' butane-deployed.json)
SPEND_SCRIPT_HASH=$(jq -r '.validators[] | select(.title == "pointers.spend").hash' butane-deployed.json)
# external_staking_validate
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_staking_validate --out butane-deployed.json "581c${MINT_SCRIPT_HASH}"
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_staking_validate --out butane-deployed.json "581c${SPEND_SCRIPT_HASH}"

# Price Feed Check Feed
ORACLE_KEY="3cd63c27c9b3e7c9fef1eae2e5c6076baaa2480d9cbae1cd2681a80123193549"
aiken blueprint apply --in butane-deployed.json -m price_feed -v check_feed --out butane-deployed.json "581c${ORACLE_KEY}"
PRICE_FEED_SCRIPT_HASH=$(jq -r '.validators[] | select(.title == "price_feed.check_feed").hash' butane-deployed.json)

# Treasury Validation
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_treas_validate --out butane-deployed.json "581c${MINT_SCRIPT_HASH}"
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_treas_validate --out butane-deployed.json "581c${SPEND_SCRIPT_HASH}"
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_treas_validate --out butane-deployed.json "581c${PRICE_FEED_SCRIPT_HASH}"

TREASURY_VALIDATION_SCRIPT_HASH=$(jq -r '.validators[] | select(.title == "synthetics.external_treas_validate").hash' butane-deployed.json)

# GOVERNANCE Validation
GOV_NFT_POLICY="f0932eda096e3bb711a2de60ef192deeac7871e1f67e57ea5895b65f"
GOV_NFT_ASSETNAME="676f76"
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_gov_validate --out butane-deployed.json "d8799f581c${GOV_NFT_POLICY}43${GOV_NFT_ASSETNAME}ff"
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_gov_validate --out butane-deployed.json "581c${MINT_SCRIPT_HASH}"
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_gov_validate --out butane-deployed.json "581c${SPEND_SCRIPT_HASH}"
BTN_POLICY="016be5325fd988fea98ad422fcfd53e5352cacfced5c106a932a35a4"
BTN_ASSETNAME="42544e"
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_gov_validate --out butane-deployed.json "d8799f581c${BTN_POLICY}43${BTN_ASSETNAME}ff"
aiken blueprint apply --in butane-deployed.json -m synthetics -v external_gov_validate --out butane-deployed.json "581c${PRICE_FEED_SCRIPT_HASH}"

GOVERNANCE_VALIDATION_SCRIPT_HASH=$(jq -r '.validators[] | select(.title == "synthetics.external_gov_validate").hash' butane-deployed.json)

# Main branch validator
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "d8799f581c${BTN_POLICY}43${BTN_ASSETNAME}ff"
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "581c${MINT_SCRIPT_HASH}"
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "581c${SPEND_SCRIPT_HASH}"
LEFTOVERS_SCRIPT_HASH=$(jq -r '.validators[] | select(.title == "leftovers.collect").hash' butane-deployed.json)
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "581c${LEFTOVERS_SCRIPT_HASH}"
REDEMPTION_NFT_POLICY="63f51f7153439e122f8a9c35e8a12a92c409aff318df4c8aea10ad39"
REDEMPTION_NFT_ASSETNAME="726564"
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "d8799f581c${REDEMPTION_NFT_POLICY}43${REDEMPTION_NFT_ASSETNAME}ff"
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "581c${GOVERNANCE_VALIDATION_SCRIPT_HASH}"
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "581c${TREASURY_VALIDATION_SCRIPT_HASH}"
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "581c${PRICE_FEED_SCRIPT_HASH}"
SYNTHETICS_STAKING_SCRIPT_HASH=$(jq -r '.validators[] | select(.title == "synthetics.external_staking_validate").hash' butane-deployed.json)
aiken blueprint apply --in butane-deployed.json -m synthetics -v validate --out butane-deployed.json "581c${SYNTHETICS_STAKING_SCRIPT_HASH}"
