"""Payload integration tests: python3 -m unittest discover -s tools -p 'test_*.py'."""
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import unittest
from prepare_package import prepare

ROOT = Path(__file__).resolve().parent.parent


class PackagingTests(unittest.TestCase):
    def test_each_format_contains_metadata_license_and_readmes_in_every_language(self):
        with tempfile.TemporaryDirectory(prefix='visor-package-test-') as temporary:
            work = Path(temporary)
            metadata = work / 'metadata.json'
            exported = subprocess.check_output([os.environ.get('DART', 'dart'), str(ROOT / 'tools/export_metadata.dart')], cwd=ROOT, text=True)
            info = json.loads(exported)
            metadata.write_text(exported)
            bundle = work / 'bundle'
            (bundle / 'data').mkdir(parents=True)
            # Minimal x86_64 ELF header for staging checks; no executable is run.
            header = bytearray(20)
            header[:4] = b'\x7fELF'
            header[18:20] = (62).to_bytes(2, 'little')
            (bundle / info['binaryName']).write_bytes(header)
            for format_name in ('deb', 'rpm', 'flatpak', 'snap'):
                with self.subTest(format=format_name):
                    stage, output = work / format_name / 'stage', work / format_name / 'out'
                    prepare(ROOT, metadata, bundle, stage, output, format_name, 'amd64')
                    for lang in info['descriptions']:
                        readme = output / lang / 'README.md'
                        installed = stage / 'usr/share/doc' / info['packageName'] / lang / 'README.md'
                        text = readme.read_text()
                        self.assertEqual(text, installed.read_text())
                        for value in (info['name'], 'JSONPath', 'CSV'):
                            self.assertIn(value, text)
                        self.assertNotIn(info['author'], text)
                        for link in re.findall(r'\]\(([^)]+)\)|src="([^"]+)"', text):
                            target = next(part for part in link if part)
                            if not target.startswith('https://'):
                                for document in (readme, installed):
                                    self.assertTrue((document.parent / target).is_file(), target)
                    self.assertEqual(json.loads((output / 'app-info.json').read_text()), info)
                    self.assertTrue((stage / 'usr/share/licenses' / info['packageName'] / 'LICENSE').exists())
                    desktop = stage / 'usr/share/applications' / f'{info["id"]}.desktop'
                    if format_name == 'snap':
                        # Snapcraft expands SNAP in its exported desktop file.
                        expanded = output / 'expanded.desktop'
                        expanded.write_text(desktop.read_text().replace('${SNAP}', f'/snap/{info["packageName"]}/current'))
                        subprocess.run(['desktop-file-validate', str(expanded)], check=True)
                    else:
                        subprocess.run(['desktop-file-validate', str(desktop)], check=True)
                    desktop_text = desktop.read_text()
                    self.assertIn(f'Exec={info["packageName"]} -- %F', desktop_text)
                    self.assertIn('text/plain;', desktop_text)
                    self.assertIn('application/json;', desktop_text)
                    applications = desktop.parent
                    subprocess.run(['update-desktop-database', '-q', str(applications)], check=True)
                    cache = (applications / 'mimeinfo.cache').read_text()
                    self.assertIn(f'text/plain={info["id"]}.desktop;', cache)
                    self.assertIn(f'application/json={info["id"]}.desktop;', cache)
                    if format_name == 'deb':
                        for hook in ['postinst', 'postrm']:
                            subprocess.run(['sh', '-n', str(stage / 'DEBIAN' / hook)], check=True)
                        # Simulate the launcher mount prefix without installing files.
                        executable = stage / 'usr/lib' / info['packageName'] / info['binaryName']
                        executable.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
                        executable.chmod(0o755)
                        launcher = stage / 'usr/bin' / info['packageName']
                        arguments = ['--', 'a file with spaces.txt', '{"key":"$literal"}']
                        result = subprocess.check_output([str(launcher), *arguments], env={**os.environ, 'SNAP': str(stage)}, text=True)
                        self.assertEqual(json.loads(result), arguments)
                        version_output = subprocess.check_output([str(launcher), '--version'], text=True)
                        self.assertIn(info['version'], version_output)
                    native_version = info['version'].replace('-', '~', 1).replace('-', '.')
                    if format_name == 'deb':
                        self.assertIn(f'Version: {native_version}\n', (stage / 'DEBIAN/control').read_text())
                    if format_name == 'rpm':
                        spec = (output / f'{info["packageName"]}.spec').read_text()
                        self.assertIn(info['licenseSpdx'], spec)
                        self.assertIn(f'Version: {native_version}\n', spec)
                    if format_name == 'snap':
                        recipe = (output / 'snapcraft.yaml').read_text()
                        self.assertIn('extensions: [gnome]', recipe)
                        self.assertIn(
                            f"slots:\n  app-dbus:\n    interface: dbus\n    bus: session\n    name: {info['id']}\n",
                            recipe,
                        )
                        self.assertIn('    slots: [app-dbus]\n', recipe)

    def test_packaging_scripts_parse_and_help_has_no_build_side_effects(self):
        for script in (ROOT / 'tools').glob('*.sh'):
            subprocess.run(['bash', '-n', str(script)], check=True)
            if script.name.startswith('package-'):
                result = subprocess.run([str(script), '--help'], capture_output=True, text=True, check=True)
                self.assertIn('--skip-build', result.stdout)


if __name__ == '__main__':
    unittest.main()
