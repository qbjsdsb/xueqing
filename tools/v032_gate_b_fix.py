from pathlib import Path

path = Path('test/features/v032_case_media_void_contract_test.dart')
text = path.read_text(encoding='utf-8')
old = "    expect(source, contains(\"key: ValueKey<String>('v2-evidence-photo-$index')\"));\n"
new = "    expect(source, contains(r\"key: ValueKey<String>('v2-evidence-photo-$index')\"));\n"
if text.count(old) != 1:
    raise SystemExit(f'expected one contract literal, found {text.count(old)}')
text = text.replace(old, new, 1)
old_tap = "    expect(source, contains('onTap: () => _showV2EvidencePhotoPreview'));\n"
new_tap = "    expect(source, contains('onTap: () =>'));\n    expect(\n      source,\n      contains('_showV2EvidencePhotoPreview(context, urls[index])'),\n    );\n"
if text.count(old_tap) != 1:
    raise SystemExit(f'expected one preview tap contract, found {text.count(old_tap)}')
path.write_text(text.replace(old_tap, new_tap, 1), encoding='utf-8')
print('Gate B formatter-safe contracts fixed')
