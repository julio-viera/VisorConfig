#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
init_package snap "$@"
[[ "$PREPARE_ONLY" == 1 ]] && exit 0
require snapcraft
project="$WORK/snap-project"
mkdir -p "$project/snap" "$project/payload"
cp -a "$STAGE/." "$project/payload/"
cp "$OUT/snapcraft.yaml" "$project/snap/snapcraft.yaml"
filename="${APP_PACKAGE}_${APP_VERSION}_${SNAP_ARCH}.snap"
# Snapcraft uses its configured provider (normally LXD); no store upload occurs.
# The provider only copies package output from within the project tree.
(cd "$project" && snapcraft pack --output "$filename")
mv -- "$project/$filename" "$OUT/$filename"
finish_package "$OUT/$filename"
