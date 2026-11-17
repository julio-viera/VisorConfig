# Visor Config licensing and third-party notices

Visor Config's own code is licensed under [GNU GPL version 3 only](LICENSE) (`GPL-3.0-only`). Third-party libraries and assets retain their upstream licenses and copyright notices.

## Dependencies and assets

- **Dart and Flutter packages.** The versions in `pubspec.lock` include software under MIT, BSD-3-Clause, Apache-2.0 and MPL-2.0. MIT, BSD-3-Clause and Apache-2.0 are compatible with GPLv3. Preserve their copyright, license and applicable notice texts when redistributing the binaries. [GNU license compatibility list](https://www.gnu.org/licenses/license-list.html)
- **Dart D-Bus package (`dbus` 0.7.15).** The Linux file picker and drag-and-drop plugins use this package under MPL-2.0. Its reviewed source files carry no Exhibit B incompatibility notice. MPL-2.0 section 3.3 permits combining it with GPLv3 under the conditions described by Mozilla. Keep the MPL notices and make the exact covered source available to recipients of the binary. [Package source archive](https://pub.dev/api/archives/dbus-0.7.15.tar.gz) · [Mozilla's MPL FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/#q14)
- **Material Icons font.** Material Icons by Google is distributed as a separate font asset under the [CC BY 4.0 license](https://creativecommons.org/licenses/by/4.0/), as stated in the reviewed Flutter SDK's `MaterialIcons_LICENSE.txt`. Flutter may subset the font to the glyphs the app uses in release builds. [Flutter's Material Icons font documentation](https://github.com/flutter/flutter/wiki/Updating-Material-Design-Fonts-%26-Icons)
- **Cupertino Icons font.** The bundled `cupertino_icons` package supplies its font with an MIT license and a copyright notice for Vladimir Kharlampidi. [Package license](https://pub.dev/packages/cupertino_icons/versions/1.0.9/license)
- **System fonts and libraries.** Fonts selected from the operating system and libraries supplied by the host or a separate platform runtime retain the terms of their respective providers. If a package additionally bundles any of these files, review the licenses of those exact files.

## Binary distribution

Linux packages include these notes, the application's GPL text and the Flutter bundle's original `data/flutter_assets/NOTICES.Z`. The packaging scripts also extract those Flutter notices to `FLUTTER_NOTICES.txt` in the package documentation when the bundle contains them.

An AppImage adds a separate runtime to the Flutter bundle. The upstream Type 2 runtime lists MIT terms for its own code and additional terms for its statically linked components, including libfuse. Keep the notices for the exact runtime used and satisfy its components' source and redistribution terms. This also applies when selecting a custom runtime. [AppImage Type 2 runtime license and component notices](https://github.com/AppImage/type2-runtime/blob/main/LICENSE)

When publishing binaries, provide the corresponding source for that exact release in accordance with GPLv3 section 6. Include the build and packaging scripts and the corresponding source for covered bundled components. Review native dependencies and runtime additions against the actual artifacts for each platform. [GPLv3, section 6](https://www.gnu.org/licenses/gpl-3.0.html#section6)
