from pathlib import Path

path = Path('test/features/v032_case_media_void_contract_test.dart')
text = path.read_text(encoding='utf-8')
old = "    expect(source, contains(\"key: ValueKey<String>('v2-evidence-photo-$index')\"));\n"
new = "    expect(source, contains(r\"key: ValueKey<String>('v2-evidence-photo-$index')\"));\n"
if text.count(old) != 1:
    raise SystemExit(f'expected one contract literal, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Gate B contract literal fixed')
