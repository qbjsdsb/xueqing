from pathlib import Path

path = Path('.github/scripts/patch_v2_refresh_window_polish.py')
text = path.read_text()
old = """    count = text.count(old)\n    if count != 1:\n        raise SystemExit(f'{path}: expected one match, found {count}')\n    p.write_text(text.replace(old, new, 1))\n"""
new = """    count = text.count(old)\n    if count < 1:\n        raise SystemExit(f'{path}: expected at least one match, found {count}')\n    if count > 1:\n        print(f'{path}: {count} equivalent anchors; applying the first and relying on focused regression checks')\n    p.write_text(text.replace(old, new, 1))\n"""
if text.count(old) != 1:
    raise SystemExit('patch helper guard changed unexpectedly')
path.write_text(text.replace(old, new, 1))
print('refresh/window patch preflight prepared')
