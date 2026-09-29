#!/usr/bin/env bash
# Regenerate altstore/apps.json from the latest GitLab release and commit it
# back to main with ci.skip (via the deploy key remote). Runs inside the
# github-release-sync job where GITLAB_RELEASE_SSH_KEY is already installed.
set -euo pipefail

RELEASE_TAG="${RELEASE_TAG:-}"
if [ -z "$RELEASE_TAG" ] || [ "$RELEASE_TAG" = "nightly" ]; then
  echo "No stable release tag, skipping AltStore update"
  exit 0
fi

REL_JSON=$(glab api "projects/$CI_PROJECT_ID/releases/$RELEASE_TAG" 2>/dev/null || true)
[ -z "$REL_JSON" ] && { echo "No GitLab release $RELEASE_TAG yet"; exit 0; }

IPA_URL=$(printf '%s' "$REL_JSON" | jq -r \
  '.assets.links[]? | select(.name | test("ipa$")) | .url' | head -n1)
if [ -z "$IPA_URL" ] || [ "$IPA_URL" = "null" ]; then
  echo "No ipa asset on release $RELEASE_TAG, skipping"
  exit 0
fi
SIZE=$(curl -fsSI "$IPA_URL" | grep -i content-length | tr -dc '0-9' || true)
SIZE=${SIZE:-0}

VERSION="${RELEASE_TAG#v}"
DATE=$(printf '%s' "$REL_JSON" | jq -r '.released_at // .created_at')
ICON_URL="https://gitlab.com/$CI_PROJECT_PATH/-/raw/main/icon-1024.png"

mkdir -p altstore
cat > altstore/apps.json <<EOF
{
  "name": "carsim",
  "identifier": "com.httpanimations.carsim",
  "sourceURL": "https://httpanimations.gitlab.io/carsim/altstore/apps.json",
  "apps": [
    {
      "name": "carsim",
      "bundleIdentifier": "com.httpanimations.carsim",
      "developerName": "HttpAnimations",
      "iconURL": "$ICON_URL",
      "tintedIconURL": "$ICON_URL",
      "versions": [
        {
          "version": "$VERSION",
          "date": "$DATE",
          "downloadURL": "$IPA_URL",
          "size": $SIZE,
          "minOSVersion": "14.0"
        }
      ],
      "appPermissions": {},
      "screenshotURLs": []
    }
  ]
}
EOF

git config user.name "GitLab CI"
git config user.email "ci@gitlab.com"
git remote add gitlab-ssh "git@gitlab.com:${CI_PROJECT_PATH}.git" 2>/dev/null || true
git fetch gitlab-ssh main
git checkout -B main gitlab-ssh/main
git add altstore/apps.json
if git diff --cached --quiet; then
  echo "AltStore source already up to date"
  exit 0
fi
git commit -m "chore: 更新 AltStore 源"
git push -o ci.skip gitlab-ssh HEAD:main
echo "AltStore source updated for $RELEASE_TAG"
