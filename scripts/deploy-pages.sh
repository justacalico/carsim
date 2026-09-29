#!/usr/bin/env bash
# GitLab Pages job: unpack the web build from the synced release into public/,
# plus the AltStore source so it is reachable at
# https://<namespace>.gitlab.io/carsim/altstore/apps.json
set -euo pipefail

GITHUB_REPO="justacalico/carsim"
RELEASE_TAG="${RELEASE_TAG:-nightly}"

mkdir -p public

if gh release download "$RELEASE_TAG" -R "$GITHUB_REPO" \
    --pattern "carsim-web.tar.gz" --dir /tmp/webpkg --clobber 2>/dev/null; then
  tar -xzf /tmp/webpkg/carsim-web.tar.gz -C public
else
  echo "No web asset on release $RELEASE_TAG; publishing placeholder"
  echo '<h1>carsim web build pending</h1>' > public/index.html
fi

mkdir -p public/altstore
if [ -f altstore/apps.json ]; then
  cp altstore/apps.json public/altstore/apps.json
else
  echo '{"name":"carsim","identifier":"com.httpanimations.carsim","apps":[]}' \
    > public/altstore/apps.json
fi

ls -la public
