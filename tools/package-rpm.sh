#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
init_package rpm "$@"
[[ "$PREPARE_ONLY" == 1 ]] && exit 0
require rpmbuild
mkdir -p "$WORK/rpmbuild/"{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
tar -czf "$WORK/rpmbuild/SOURCES/payload.tar.gz" -C "$WORK" payload
rpmbuild --define "_topdir $WORK/rpmbuild" --target "$RPM_ARCH" -bb "$OUT/$APP_PACKAGE.spec"
find "$WORK/rpmbuild/RPMS" -type f -name '*.rpm' -exec cp -- {} "$OUT/" \;
artifact="$OUT/${APP_PACKAGE}-${APP_VERSION}-1.${RPM_ARCH}.rpm"
[[ -f "$artifact" ]] || { echo 'RPM did not produce the expected artifact' >&2; exit 1; }
finish_package "$artifact"
