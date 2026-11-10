"""Export the approved icon master using macOS sips (no design changes)."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / 'assets/branding/app-icon.png'


def export(relative, size):
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['sips', '-z', str(size), str(size), str(MASTER), '--out', str(target)],
                   check=True, stdout=subprocess.DEVNULL)


def main():
    if not MASTER.exists():
        raise SystemExit(f'Missing icon master: {MASTER}')
    for size in (192, 512):
        export(f'web/icons/clipdesk-{size}.png', size)
        export(f'web/icons/clipdesk-maskable-{size}.png', size)
    export('web/icons/clipdesk-apple-180.png', 180)
    export('web/clipdesk-favicon.png', 32)
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        export(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
    icon_set = Path('ios/Runner/Assets.xcassets/AppIcon.appiconset')
    contents = json.loads((ROOT / icon_set / 'Contents.json').read_text())
    for item in contents['images']:
        size = round(float(item['size'].split('x')[0]) * float(item['scale'].rstrip('x')))
        export(icon_set / item['filename'], size)
    print('Exported Web, Apple touch, favicon, Android and iOS icons.')


if __name__ == '__main__':
    main()
