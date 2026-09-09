from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1, found {count}')
    return text.replace(old, new, 1)

path = Path('lib/features/design_v2/v2_composers.dart')
text = path.read_text()
text = replace_once(
    text,
    '''      isScrollControlled: true,\n      useSafeArea: true,\n      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,''',
    '''      isScrollControlled: true,\n      useSafeArea: true,\n      isDismissible: false,\n      enableDrag: false,\n      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,''',
    'compact composer dismissal flags',
)

start = text.index('class _ComposerScaffold extends StatelessWidget')
end = text.index('class _ComposerFooter extends StatelessWidget')
segment = text[start:end]
segment = replace_once(
    segment,
    '    return AnimatedPadding(\n',
    '    final body = AnimatedPadding(\n',
    'composer scaffold body',
)
segment = replace_once(
    segment,
    '''    );\n  }\n}\n\n''',
    '''    );\n    return PopScope(canPop: onClose != null, child: body);\n  }\n}\n\n''',
    'composer scaffold pop guard',
)
text = text[:start] + segment + text[end:]
path.write_text(text)

path = Path('test/features/design_v2_composers_test.dart')
test = path.read_text()
if "import 'dart:async';" not in test:
    test = "import 'dart:async';\n" + test
closing = '\n}\n'
if not test.endswith(closing):
    raise SystemExit('composer test did not end with expected brace')
new_test = r'''

  testWidgets(
    'writable composer cannot be dismissed while save is in flight',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final saveCompleter = Completer<void>();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2QuickCapture(
                context,
                studentName: '林同学',
                subjects: const ['语文'],
                attachmentPicker: (_) async => null,
                onSave: (_) => saveCompleter.future,
              ),
              child: const Text('打开保存测试'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开保存测试'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '保存期间不能误关。',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
      await tester.pump();

      expect(find.text('保存中…'), findsOneWidget);
      expect(find.text('记录新问题'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('记录新问题'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.text('记录新问题'), findsOneWidget);

      await tester.drag(find.text('记录新问题'), const Offset(0, 360));
      await tester.pump();
      expect(find.text('记录新问题'), findsOneWidget);

      saveCompleter.complete();
      await tester.pumpAndSettle();
      expect(find.text('记录新问题'), findsNothing);
    },
  );
'''
test = test[:-len(closing)] + new_test + closing
path.write_text(test)
