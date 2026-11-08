# Herramientas de Visor Config

Los metadatos canónicos están en [`lib/app_info.dart`](../lib/app_info.dart). No se leen constantes duplicadas desde scripts ni se usa `eval` para cargar datos.

## Requisitos

- Bash, Python 3, Dart y Flutter en `PATH`.
- Compilación Linux de Flutter y sus dependencias de desarrollo (GTK 3, Clang, CMake, Ninja, pkg-config).
- `.deb`: `dpkg-deb` y `readelf` (binutils).
- `.rpm`: `rpmbuild` y `tar`.
- Flatpak: `flatpak` y `org.gnome.Platform//51` instalados. No requiere SDK ni flatpak-builder porque empaqueta un bundle ya compilado. El runtime se puede cambiar con `FLATPAK_RUNTIME_VERSION`.
- Snap: `snapcraft` con su proveedor de compilación configurado (normalmente LXD), base core24 y extensión GNOME. El bundle debe compilarse en Ubuntu 24.04 o un entorno compatible con core24; un bundle que requiera una glibc posterior no funcionará en esa base.

Los scripts no instalan dependencias, no suben paquetes a ninguna tienda y no modifican instalaciones del usuario. Los formatos generados son paquetes locales sin firma. La generación de un paquete no reemplaza su prueba de instalación y ejecución en la distribución de destino.

## Comandos

```sh
# Sincronizar los archivos que Flutter/native necesitan a partir de app_info.dart
dart tools/sync_app_info.dart

# Cada script compila Linux antes de empaquetar
tools/package-deb.sh
tools/package-rpm.sh
tools/package-flatpak.sh
tools/package-snap.sh

# Compilar una sola vez e intentar todos los formatos
tools/package-all.sh

# Reutilizar el bundle existente
tools/package-deb.sh --skip-build

# Preparar payloads, recetas y README sin requerir rpmbuild/snapcraft
tools/package-all.sh --skip-build --prepare-only
```

`--prepare-only` no crea un paquete instalable. `package-all.sh` intenta los cuatro formatos y devuelve un código distinto de cero si alguno falla; nunca presenta un formato fallido como generado.

Se pueden indicar los ejecutables de SDK y un bundle alternativo:

```sh
DART=/ruta/flutter/bin/cache/dart-sdk/bin/dart \
FLUTTER=/ruta/flutter/bin/flutter \
tools/package-all.sh

BUNDLE_DIR=/ruta/bundle tools/package-deb.sh --skip-build
```

No se realiza compilación cruzada: la arquitectura del bundle debe coincidir con el equipo (x86_64 o aarch64). `DEB_MAINTAINER` permite agregar un correo de contacto al campo del mantenedor sin modificar los datos de autor de la app.

## Salida

```text
dist/
  1.1.1/
    deb/
      visor-config_1.1.1_amd64.deb
      SHA256SUMS
      app-info.json
      images/    # Logotipo y capturas compartidas
      LICENSE
      en/README.md
      es/README.md
      fr/README.md
      pt/README.md
      de/README.md
      it/README.md
    rpm/       # .rpm, receta .spec y los mismos README
    flatpak/   # .flatpak y los mismos README
    snap/      # .snap, snapcraft.yaml y los mismos README
```

La versión y los nombres se obtienen de `app_info.dart`. Los seis README también están **dentro** de cada paquete, en `usr/share/doc/visor-config/<idioma>/README.md` (en Flatpak bajo `/app/share/doc/...`). Son copias de las guías de usuario de la raíz, con enlaces adaptados a la distribución e imágenes y licencia compartidas. Cada payload incluye `LICENSE` con GPL 3. Los archivos de salida se ignoran en Git.

En `.deb` se calcula la versión mínima de glibc leyendo los requisitos de los ELF incluidos. En RPM se conservan las dependencias automáticas del empaquetador. Flatpak permite acceso a la carpeta personal y medios extraíbles para abrir y guardar configuraciones; el selector mantiene la integración GTK. Snap utiliza la extensión GNOME y los plugs `home` y `removable-media`; este último puede necesitar conexión manual.

## Verificación

```sh
flutter analyze
flutter test
python3 -m unittest discover -s tools -p 'test_*.py'
```

Las pruebas Python usan un payload sintético y verifican los README multilingües, licencia, manifiestos, archivos desktop y la sintaxis/ayuda de los scripts. No instalan paquetes. El despliegue a tiendas, firma de paquetes y publicación de un repositorio de actualizaciones quedan fuera de estos scripts.

Referencias de implementación: [Debian control fields](https://www.debian.org/doc/debian-policy/ch-controlfields.html), [RPM spec files](https://rpm.org/docs/6.0.x/manual/spec.html), [Flatpak command reference](https://docs.flatpak.org/en/latest/flatpak-command-reference.html), [Snapcraft GNOME extension](https://ubuntu.com/docs/snapcraft/9/reference/extensions/gnome-extension/).

## Iconos de la app

Su fuente editable está en `assets/app_icon.svg`. Para regenerar los PNG, ICO, iconos de Android (incluido el adaptativo), iOS, macOS y web:

```sh
python3 tools/generate_icons.py
```

Este script requiere Pillow, PyGObject, Cairo y librsvg (`python3-pil`, `python3-gi`, `python3-cairo`, `gir1.2-rsvg-2.0` en Ubuntu).
