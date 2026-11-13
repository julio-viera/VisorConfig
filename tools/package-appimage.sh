#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
init_package appimage "$@"
[[ "$PREPARE_ONLY" == 1 ]] && exit 0
arch="$(uname -m)"
[[ "$arch" != arm64 ]] || arch=aarch64
filename="${APP_PACKAGE}_${APP_VERSION}_${arch}.AppImage"
appdir="$WORK/$APP_PACKAGE.AppDir"
mv -- "$STAGE" "$appdir"
ARCH="$arch" "${APPIMAGETOOL:-appimagetool}" "$appdir" "$WORK/$filename"
mv -- "$WORK/$filename" "$OUT/$filename"
finish_package "$OUT/$filename"
