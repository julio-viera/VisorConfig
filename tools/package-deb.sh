#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
init_package deb "$@"
[[ "$PREPARE_ONLY" == 1 ]] && exit 0
require dpkg-deb
artifact="$OUT/${APP_PACKAGE}_${APP_VERSION}_${DEB_ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGE" "$artifact"
finish_package "$artifact"
