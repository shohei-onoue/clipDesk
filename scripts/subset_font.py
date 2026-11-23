"""日本語フォント（NotoSansJP）を、よく使う文字だけに絞って assets/fonts に出力する。

元のフォント（約9.5MB）は scripts/fonts_src に置いてあり、アプリには入れない。
出力は約5.6MB（転送量は約半分）。必要な文字（JIS X 0208・0213、人名の異体字
〔髙・𠮷・互換漢字〕、記号、全角・半角）を残し、可変フォント（太さ）はそのまま。
含まれない文字は、端末・ブラウザの代替フォントで表示される（欠けて空白にはならない）。

使い方（fonttools と brotli が必要）：
  python3 -m venv .venv && .venv/bin/pip install fonttools brotli
  .venv/bin/python scripts/subset_font.py
"""
import subprocess, sys, tempfile, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
src = root / 'scripts/fonts_src/NotoSansJP-Variable.ttf'
out = root / 'assets/fonts/NotoSansJP-Variable.ttf'


def rng(a, b):
    return {chr(c) for c in range(a, b + 1)}


chars = set()
for a in range(0xA1, 0xFF):
    for b in range(0xA1, 0xFF):
        for codec in ('euc_jisx0213', 'euc_jp'):
            try:
                chars.add(bytes([a, b]).decode(codec))
            except Exception:
                pass
chars |= (rng(0x20, 0x7E) | rng(0xA0, 0xFF) | rng(0x2000, 0x206F) | rng(0x2190, 0x22FF)
          | rng(0x2460, 0x24FF) | rng(0x25A0, 0x26FF) | rng(0x3000, 0x30FF) | rng(0x31F0, 0x31FF)
          | rng(0x3200, 0x33FF) | rng(0xF900, 0xFAFF) | rng(0xFF00, 0xFFEF))
chars |= set('髙𠮷𠮟﨑塚德') | set('髙')

with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False, encoding='utf-8') as f:
    f.write(''.join(sorted(chars)))
subprocess.check_call([
    'pyftsubset', str(src),
    f'--text-file={f.name}', '--layout-features=*', f'--output-file={out}',
])
print(out, out.stat().st_size)
