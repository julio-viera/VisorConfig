#!/usr/bin/env bash
# Shared packaging implementation; source from package-*.sh.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DART="${DART:-dart}"
FLUTTER="${FLUTTER:-flutter}"
require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 2; }; }
init_package() {
  FORMAT="$1"; shift
  SKIP_BUILD=0; PREPARE_ONLY=0
  for argument in "$@"; do
    case "$argument" in
      --skip-build) SKIP_BUILD=1 ;;
      --prepare-only) PREPARE_ONLY=1 ;;
      -h|--help) echo "Usage: $0 [--skip-build] [--prepare-only]"; exit 0 ;;
      *) echo "Unknown argument: $argument" >&2; exit 2 ;;
    esac
  done
  require "$DART"; require python3
  if [[ "$PREPARE_ONLY" == 0 ]]; then
    case "$FORMAT" in
      deb) require dpkg-deb ;;
      rpm) require rpmbuild ;;
      flatpak) require flatpak ;;
      snap) require snapcraft ;;
    esac
  fi
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/visor-package.XXXXXXXX")"
  trap 'rm -rf -- "$WORK"' EXIT
  "$DART" "$ROOT/tools/export_metadata.dart" > "$WORK/metadata.json"
  APP_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$WORK/metadata.json")"
  APP_PACKAGE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["packageName"])' "$WORK/metadata.json")"
  APP_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$WORK/metadata.json")"
  APP_BINARY="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["binaryName"])' "$WORK/metadata.json")"
  case "$(uname -m)" in
    x86_64) FLUTTER_ARCH=x64; DEB_ARCH=amd64; RPM_ARCH=x86_64; SNAP_ARCH=amd64; FLATPAK_ARCH=x86_64 ;;
    aarch64|arm64) FLUTTER_ARCH=arm64; DEB_ARCH=arm64; RPM_ARCH=aarch64; SNAP_ARCH=arm64; FLATPAK_ARCH=aarch64 ;;
    *) echo 'Unsupported build architecture' >&2; exit 2 ;;
  esac
  if [[ "$SKIP_BUILD" == 0 ]]; then
    require "$FLUTTER"
    "$DART" "$ROOT/tools/sync_app_info.dart"
    (cd "$ROOT" && "$FLUTTER" build linux --release --build-name "$APP_VERSION")
  fi
  BUNDLE="${BUNDLE_DIR:-$ROOT/build/linux/$FLUTTER_ARCH/release/bundle}"
  [[ -x "$BUNDLE/$APP_BINARY" ]] || { echo "Missing Linux release bundle: $BUNDLE" >&2; exit 2; }
  OUT="$ROOT/dist/$APP_VERSION/$FORMAT"
  mkdir -p "$OUT"
  STAGE="$WORK/payload"
  python3 "$ROOT/tools/prepare_package.py" "$ROOT" "$WORK/metadata.json" "$BUNDLE" "$STAGE" "$OUT" "$FORMAT" "$DEB_ARCH"
  if [[ "$PREPARE_ONLY" == 1 ]]; then
    # Retain only this generated staging tree; never remove other output directories.
    rm -rf -- "$OUT/staging"
    mkdir -p "$OUT/staging"
    cp -a "$STAGE/." "$OUT/staging/"
    echo "Prepared $OUT/staging (no package built)"
  fi
}
finish_package() {
  local artifact="$1"
  (cd "$OUT" && sha256sum "$(basename -- "$artifact")" > SHA256SUMS)
  echo "Created $artifact"
}
