#!/usr/bin/env python3
"""Render the canonical SVG into the icon assets consumed by Flutter/platforms.

Requires python3-gi, gir1.2-rsvg-2.0, python3-cairo and Pillow.
This renders vector artwork; it does not modify the generated concept image.
"""
import io
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import gi
import cairo
from PIL import Image

gi.require_version('Rsvg', '2.0')
from gi.repository import Rsvg

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'assets/app_icon.svg'


def render(size, *, opaque=False, inset=0, foreground=False):
    svg = ET.parse(SOURCE)
    node = svg.getroot()
    if foreground:
        for item in list(node):
            if item.tag.endswith('rect'):
                node.remove(item)
    elif opaque:
        for item in node:
            if item.tag.endswith('rect'):
                item.set('rx', '0')
    data = ET.tostring(node)
    handle = Rsvg.Handle.new_from_data(data)
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    context = cairo.Context(surface)
    if opaque:
        context.set_source_rgb(33 / 255, 23 / 255, 45 / 255)
        context.paint()
    extent = size * (1 - 2 * inset)
    viewport = Rsvg.Rectangle()
    viewport.x = viewport.y = size * inset
    viewport.width = viewport.height = extent
    handle.render_document(context, viewport)
    output = io.BytesIO()
    surface.write_to_png(output)
    return Image.open(io.BytesIO(output.getvalue())).convert('RGBA')


def save(path, size, **options):
    path.parent.mkdir(parents=True, exist_ok=True)
    image = render(size, **options)
    if options.get('opaque'):
        image = image.convert('RGB')
    image.save(path)
    return image


def main():
    master = save(ROOT / 'assets/app_icon.png', 1024)
    save(ROOT / 'assets/app_icon_256.png', 256)
    master.save(ROOT / 'windows/runner/resources/app_icon.ico', sizes=[(n, n) for n in [16, 24, 32, 48, 64, 128, 256]])
    for density, pixels in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        save(ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', pixels)
        save(ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png', round(pixels * 108 / 48), inset=.16, foreground=True)
    for platform in ['ios', 'macos']:
        directory = ROOT / f'{platform}/Runner/Assets.xcassets/AppIcon.appiconset'
        info = json.loads((directory / 'Contents.json').read_text())
        for entry in info['images']:
            if 'filename' not in entry:
                continue
            size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
            save(directory / entry['filename'], size, opaque=platform == 'ios')
    save(ROOT / 'web/favicon.png', 32)
    for size in [192, 512]:
        save(ROOT / f'web/icons/Icon-{size}.png', size)
        save(ROOT / f'web/icons/Icon-maskable-{size}.png', size, opaque=True, inset=.1)


if __name__ == '__main__':
    main()
