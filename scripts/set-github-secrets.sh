#!/usr/bin/env bash
# Loads release secrets into the current GitHub repo (run from the repo root
# after `gh repo create` / `git remote add`). Nothing is written to disk.
#
#   scripts/set-github-secrets.sh ~/labbiah-signing/key.properties path/to/play-service-account.json
set -euo pipefail

PROPS=${1:?path to key.properties}
PLAY_JSON=${2:?path to Play service-account JSON}

prop() { grep "^$1=" "$PROPS" | cut -d= -f2-; }

base64 < "$(prop storeFile)" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64
prop storePassword | tr -d '\n' | gh secret set ANDROID_KEYSTORE_PASSWORD
prop keyAlias      | tr -d '\n' | gh secret set ANDROID_KEY_ALIAS
prop keyPassword   | tr -d '\n' | gh secret set ANDROID_KEY_PASSWORD
gh secret set PLAY_SERVICE_ACCOUNT_JSON < "$PLAY_JSON"
gh variable set PLAY_RELEASE_STATUS --body draft

echo "Secrets set. Remember to create the 'play-testing' and 'production' environments."
