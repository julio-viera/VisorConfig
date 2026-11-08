#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
init_package flatpak "$@"
[[ "$PREPARE_ONLY" == 1 ]] && exit 0
require flatpak
runtime_version="${FLATPAK_RUNTIME_VERSION:-51}"
flatpak info "org.gnome.Platform/$FLATPAK_ARCH/$runtime_version" >/dev/null || { echo "Install org.gnome.Platform//$runtime_version first, or set FLATPAK_RUNTIME_VERSION." >&2; exit 2; }
app="$WORK/flatpak-app"
mkdir -p "$app/files/bin" "$app/files/lib" "$app/files/share"
cp -a "$STAGE/usr/lib/$APP_PACKAGE" "$app/files/lib/"
cp -a "$STAGE/usr/share/." "$app/files/share/"
cp "$STAGE/usr/bin/$APP_PACKAGE" "$app/files/bin/$APP_PACKAGE"
chmod 755 "$app/files/bin/$APP_PACKAGE"
printf '[Application]\nname=%s\nruntime=org.gnome.Platform/%s/%s\n' "$APP_ID" "$FLATPAK_ARCH" "$runtime_version" > "$app/metadata"
# Prebuilt Flutter bundle: no SDK/build container or installation is required.
flatpak build-finish --command="$APP_PACKAGE" --share=ipc --socket=wayland --socket=fallback-x11 --device=dri --env=GTK_USE_PORTAL=1 "$app"
flatpak build-export --arch="$FLATPAK_ARCH" "$WORK/flatpak-repo" "$app" stable
artifact="$OUT/${APP_PACKAGE}-${APP_VERSION}-${FLATPAK_ARCH}.flatpak"
flatpak build-bundle --arch="$FLATPAK_ARCH" --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo "$WORK/flatpak-repo" "$artifact" "$APP_ID" stable
finish_package "$artifact"
