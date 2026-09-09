from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1, found {count}')
    return text.replace(old, new, 1)

composer_path = Path('lib/features/design_v2/v2_composers.dart')
composer = composer_path.read_text()
for required in (
    'isDismissible: false,',
    'enableDrag: false,',
    'return PopScope(canPop: onClose != null, child: body);',
):
    if required not in composer:
        raise SystemExit(f'missing product guard: {required}')

path = Path('test/features/design_v2_composers_test.dart')
test = path.read_text()
marker = "testWidgets('writable composer cannot be dismissed while save is in flight'"
if marker not in test:
    raise SystemExit('saving-dismiss test is missing')
start = test.index(marker)
segment = test[start:]
old = """    await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
    await tester.pump();

    expect(find.text('保存中…'), findsOneWidget);"""
new = """    final saveButton = find.widgetWithText(FilledButton, '记录问题');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('保存中…'), findsOneWidget);"""
if old in segment:
    segment = replace_once(segment, old, new, 'saving test visible tap')
elif new not in segment:
    raise SystemExit('saving test tap shape is neither old nor expected new form')
test = test[:start] + segment
path.write_text(test)
