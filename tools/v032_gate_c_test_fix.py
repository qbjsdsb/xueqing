from pathlib import Path

path = Path('test/features/v032_progress_recovery_test.dart')
text = path.read_text(encoding='utf-8')
old_import = "import 'dart:typed_data';\n\n"
new_import = "import 'dart:convert';\nimport 'dart:typed_data';\n\n"
if text.count(old_import) != 1:
    raise SystemExit(f'expected typed_data import block once, found {text.count(old_import)}')
text = text.replace(old_import, new_import, 1)
old_bytes = "      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),\n      fileName: '恢复.jpg',\n      contentType: 'image/jpeg',\n"
new_bytes = "      bytes: Uint8List.fromList(\n        base64Decode(\n          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'\n          'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',\n        ),\n      ),\n      fileName: '恢复.png',\n      contentType: 'image/png',\n"
if text.count(old_bytes) != 1:
    raise SystemExit(f'expected invalid image fixture once, found {text.count(old_bytes)}')
path.write_text(text.replace(old_bytes, new_bytes, 1), encoding='utf-8')
print('Gate C recovery test now uses a real PNG fixture')
