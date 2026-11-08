#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
skip=0
for argument in "$@"; do
  case "$argument" in
    --skip-build) skip=1 ;;
    --prepare-only) ;;
    -h|--help) echo "Usage: $0 [--skip-build] [--prepare-only]"; exit 0 ;;
    *) echo "Unknown argument: $argument" >&2; exit 2 ;;
  esac
done
if [[ "$skip" == 0 ]]; then
  require "$DART"; require "$FLUTTER"
  "$DART" "$ROOT/tools/sync_app_info.dart"
  (cd "$ROOT" && "$FLUTTER" build linux --release)
fi
status=0
for format in deb rpm flatpak snap; do
  if ! "$ROOT/tools/package-$format.sh" --skip-build "$@"; then
    echo "Packaging failed: $format" >&2
    status=1
  fi
done
exit "$status"
