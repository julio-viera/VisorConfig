#!/usr/bin/env python3
"""Generate package payloads and bundle the localized user guides."""
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import struct
import subprocess
import sys


def write(path, text, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')
    path.chmod(mode)


def prepare(root, metadata_path, bundle, stage, output, format_name, arch):
    info = json.loads(metadata_path.read_text(encoding='utf-8'))
    name, version, package, app_id, binary = (info[k] for k in ('name', 'version', 'packageName', 'id', 'binaryName'))
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?', version):
        raise ValueError('Packaging requires a three-component appVersion, such as 1.0.0 or 1.0.0-beta.1')
    yaml_version = re.search(r'^version:\s*([^+\s]+)', (root / 'pubspec.yaml').read_text(), re.M).group(1)
    if yaml_version != version:
        raise ValueError('Version mismatch: run dart tools/sync_app_info.dart before packaging')
    # Debian and RPM sort prereleases before the stable version with a tilde.
    native_version = version.replace('-', '~', 1).replace('-', '.')
    with (bundle / binary).open('rb') as stream:
        header = stream.read(20)
    expected_machine = {'amd64': 62, 'arm64': 183}[arch]
    if header[:4] != b'\x7fELF' or struct.unpack('<H', header[18:20])[0] != expected_machine:
        raise ValueError('The bundle architecture does not match the build host')
    payload = stage / 'usr/lib' / package
    shutil.copytree(bundle, payload, dirs_exist_ok=True)
    (payload / binary).chmod(0o755)
    prefix = '/app/lib' if format_name == 'flatpak' else '${SNAP:-}/usr/lib'
    heading = shlex.quote(f'{name} {version}')
    usage = shlex.quote(f'Usage: {package} [FILE.json|FILE.txt|JSON_TEXT]...\n       {package} --file PATH\n       {package} --json JSON_TEXT\nOptions: --help, --version, -- (end options)')
    launcher = f'''#!/bin/sh
case "${{1:-}}" in
  --help) printf '%s\\n%s\\n' {heading} {usage}; exit 0 ;;
  --version) printf '%s\\n' {heading}; exit 0 ;;
esac
exec "{prefix}/{package}/{binary}" "$@"
'''
    write(stage / 'usr/bin' / package, launcher, 0o755)
    shutil.copyfile(root / 'LICENSE', payload / 'LICENSE')
    write(stage / 'usr/share/licenses' / package / 'LICENSE', (root / 'LICENSE').read_text())
    icon = f'usr/share/icons/hicolor/scalable/apps/{app_id}.svg'
    (stage / icon).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / 'assets/app_icon.svg', stage / icon)
    comments = '\n'.join(f'Comment[{lang}]={description}' for lang, description in info['descriptions'].items())
    desktop = f'''[Desktop Entry]
Type=Application
Name={name}
Comment={info['descriptions']['en']}
{comments}
Exec={package} -- %F
Icon={app_id}
Terminal=false
Categories=Development;
MimeType=application/json;application/yaml;application/x-yaml;application/toml;text/plain;application/ld+json;application/geo+json;
StartupNotify=true
StartupWMClass={app_id}
'''
    if format_name == 'snap':
        desktop = desktop.replace(f'Icon={app_id}', f'Icon=${{SNAP}}/{icon}')
    write(stage / 'usr/share/applications' / f'{app_id}.desktop', desktop)
    for docs in (stage / 'usr/share/doc' / package, output):
        shutil.copytree(root / 'docs/images', docs / 'images', dirs_exist_ok=True)
        shutil.copyfile(root / 'LICENSE', docs / 'LICENSE')
        for lang in info['descriptions']:
            filename = 'README.md' if lang == 'en' else f'README.{lang}.md'
            text = (root / filename).read_text(encoding='utf-8')
            text = text.replace('docs/images/', '../images/').replace('(LICENSE)', '(../LICENSE)')
            for target in info['descriptions']:
                target_file = 'README.md' if target == 'en' else f'README.{target}.md'
                text = text.replace(f'({target_file})', f'(../{target}/README.md)')
            write(docs / lang / 'README.md', text)
    write(output / 'app-info.json', json.dumps(info, ensure_ascii=False, indent=2) + '\n')
    if format_name == 'deb':
        if shutil.which('readelf') is None:
            raise RuntimeError('readelf (binutils) is required to derive the minimum glibc version')
        versions = [(2, 17)]
        for file in payload.rglob('*'):
            if file.is_file() and (file.name == binary or '.so' in file.name):
                data = subprocess.run(['readelf', '--version-info', str(file)], capture_output=True, text=True, check=False).stdout
                versions.extend(tuple(map(int, v.split('.'))) for v in re.findall(r'GLIBC_([0-9]+\.[0-9]+)', data))
        glibc = '.'.join(map(str, max(versions)))
        control = f'''Package: {package}
Version: {native_version}
Architecture: {arch}
Maintainer: {os.environ.get('DEB_MAINTAINER', info['author'])}
Section: devel
Priority: optional
Installed-Size: {sum(f.stat().st_size for f in stage.rglob('*') if f.is_file()) // 1024}
Depends: libc6 (>= {glibc}), libgtk-3-0t64 | libgtk-3-0, libglib2.0-0t64 | libglib2.0-0, libstdc++6, libgcc-s1
Homepage: {info['repositoryUrl']}
Description: JSON viewer and editor
 {info['descriptions']['en']}
'''
        write(stage / 'DEBIAN/control', control)
        for hook, events in [('postinst', 'configure'), ('postrm', 'remove|purge')]:
            script = f'''#!/bin/sh
set -e
case "$1" in
  {events})
    if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database -q /usr/share/applications || true
    fi
    ;;
esac
exit 0
'''
            write(stage / 'DEBIAN' / hook, script, 0o755)
    if format_name == 'rpm':
        spec = f'''%global debug_package %{{nil}}
%global _build_id_links none
%global __brp_strip %{{nil}}
%global __brp_strip_comment_note %{{nil}}
Name: {package}
Version: {native_version}
Release: 1
Summary: JSON viewer and editor
License: {info['licenseSpdx']}
URL: {info['repositoryUrl']}
Source0: payload.tar.gz
Requires: gtk3, libstdc++

%description
{info['descriptions']['en']}

%prep
%setup -q -n payload

%build

%install
mkdir -p "%{{buildroot}}"
cp -a usr "%{{buildroot}}/"

%post
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || :
fi

%postun
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || :
fi

%files
/usr/bin/{package}
/usr/lib/{package}
/usr/share/applications/{app_id}.desktop
/usr/share/icons/hicolor/scalable/apps/{app_id}.svg
%doc /usr/share/doc/{package}
%license /usr/share/licenses/{package}/LICENSE
'''
        write(output / f'{package}.spec', spec)
    if format_name == 'snap':
        snap = f'''name: {package}
base: core24
version: '{version}'
title: {json.dumps(name, ensure_ascii=False)}
summary: JSON viewer and editor
description: {json.dumps(info['descriptions']['en'], ensure_ascii=False)}
contact: {json.dumps(info['issuesUrl'])}
issues: {json.dumps(info['issuesUrl'])}
source-code: {json.dumps(info['repositoryUrl'])}
website: {json.dumps(info['repositoryUrl'])}
grade: stable
confinement: strict
license: {info['licenseSpdx']}
icon: payload/{icon}
platforms:
  {arch}:
slots:
  app-dbus:
    interface: dbus
    bus: session
    name: {app_id}
apps:
  {package}:
    command: usr/bin/{package}
    desktop: usr/share/applications/{app_id}.desktop
    extensions: [gnome]
    plugs: [home, removable-media]
    slots: [app-dbus]
parts:
  app:
    plugin: dump
    source: payload
'''
        write(output / 'snapcraft.yaml', snap)


if __name__ == '__main__':
    if len(sys.argv) != 8:
        raise SystemExit('Usage: prepare_package.py ROOT METADATA BUNDLE STAGE OUTPUT FORMAT ARCH')
    prepare(*[Path(p).resolve() for p in sys.argv[1:6]], sys.argv[6], sys.argv[7])
