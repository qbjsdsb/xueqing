from pathlib import Path

path = Path('test/features/design_v2_composers_test.dart')
text = path.read_text()
old_import = "import 'dart:typed_data';"
if text.count(old_import) != 1:
    raise SystemExit(f'expected one typed_data import, found {text.count(old_import)}')
text = text.replace(old_import, "import 'dart:convert';", 1)
old_bytes = 'bytes: Uint8List.fromList([1, 2, 3]),'
if text.count(old_bytes) != 1:
    raise SystemExit(f'expected one fake image fixture, found {text.count(old_bytes)}')
text = text.replace(
    old_bytes,
    "bytes: base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='),",
    1,
)
path.write_text(text)
