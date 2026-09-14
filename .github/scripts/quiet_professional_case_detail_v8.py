from pathlib import Path

SOURCE = Path('lib/features/design_v2/v2_workspace_preview.dart')
TEST = Path('test/features/v2_case_detail_desktop_composition_test.dart')
WORKFLOW = Path('.github/workflows/quiet-professional-case-detail-desktop-v8.yml')
SCRIPT = Path('.github/scripts/quiet_professional_case_detail_v8.py')

source = SOURCE.read_text()

# Keep the outer desktop breakpoint as the single source of truth.
desktop_start = source.index('class _DesktopWorkspace extends StatelessWidget')
desktop_end = source.index('class _MediumWorkspace extends StatefulWidget', desktop_start)
desktop = source[desktop_start:desktop_end]
needle = '''                      ? _CaseDetailPane(\n                          student: selectedStudent,\n                          item: selectedCase!,\n                          onBack: onBackFromCase,\n                        )'''
replacement = '''                      ? _CaseDetailPane(\n                          student: selectedStudent,\n                          item: selectedCase!,\n                          onBack: onBackFromCase,\n                          wideDesktop: expandedRail,\n                        )'''
assert desktop.count(needle) == 1, 'desktop case detail call changed unexpectedly'
desktop = desktop.replace(needle, replacement, 1)
source = source[:desktop_start] + desktop + source[desktop_end:]

case_start = source.index('class _CaseDetailPane extends StatelessWidget')
case_end = source.index('class _TodayPane extends StatelessWidget', case_start)
old_case = source[case_start:case_end]

# Constructor/field: wide desktop is opt-in and only the outer desktop shell enables it.
old_ctor = '''  const _CaseDetailPane({\n    required this.student,\n    required this.item,\n    required this.onBack,\n    this.compact = false,\n  });\n\n  final V2Student student;\n  final V2FocusItem item;\n  final VoidCallback onBack;\n  final bool compact;'''
new_ctor = '''  const _CaseDetailPane({\n    required this.student,\n    required this.item,\n    required this.onBack,\n    this.compact = false,\n    this.wideDesktop = false,\n  });\n\n  final V2Student student;\n  final V2FocusItem item;\n  final VoidCallback onBack;\n  final bool compact;\n  final bool wideDesktop;'''
assert old_case.count(old_ctor) == 1, 'case detail constructor changed unexpectedly'
old_case = old_case.replace(old_ctor, new_ctor, 1)

# Preserve the existing identity/actions exactly; only replace the composition below them.
body_start = old_case.index('    return ColoredBox(')
body_end = old_case.rindex('  }\n}')
prefix = old_case[:body_start]
suffix = old_case[body_end:]

new_body = r'''    final activeActionSection = Container(
      key: ValueKey<String>('v2-case-next-step-${item.id}'),
      width: double.infinity,
      padding: EdgeInsets.all(wideDesktop ? 0 : 17),
      decoration: wideDesktop
          ? null
          : BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '下一步',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            nextStep,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            dueText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (pendingAction != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pendingAction.canComplete)
                  FilledButton.tonalIcon(
                    key: ValueKey<String>('v2-complete-${item.id}'),
                    onPressed: () => _showV2CompleteCurrentAction(
                      context,
                      student,
                      item,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('处理这一步'),
                  ),
                OutlinedButton.icon(
                  key: ValueKey<String>('v2-reschedule-${item.id}'),
                  onPressed: () => _showV2RescheduleCurrentAction(
                    context,
                    student,
                    item,
                  ),
                  icon: const Icon(Icons.event_repeat_outlined, size: 18),
                  label: Text(pendingAction.dueOn == null ? '安排日期' : '改期'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              item.pendingVerification
                  ? '还没有安排复检时间。完成本次检查后如仍需继续关注，可在记录复检时设置下一次提醒。'
                  : '还没有具体提醒。记录下一次进展时，可以顺手安排后续。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    final closedActionSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(nextStep, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
        if (canReopen) ...[
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            key: ValueKey<String>('v2-reopen-${item.id}'),
            onPressed: () => _showV2ReopenClosedCase(context, student, item),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('再次出现，重新跟进'),
          ),
        ],
      ],
    );

    final actionSection = KeyedSubtree(
      key: const Key('v2-case-action-section'),
      child: item.closed ? closedActionSection : activeActionSection,
    );
    final timelineSection = Column(
      key: const Key('v2-case-timeline-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '成长过程'),
        const SizedBox(height: 16),
        _Timeline(
          entries: timelineEntries,
          resolveEvidencePhotos: true,
        ),
      ],
    );

    return ColoredBox(
      color: scheme.surface,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wideDesktop ? 1120 : 860),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 32,
                20,
                compact ? 18 : 32,
                48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    key: const Key('v2-case-context-row'),
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${student.name} · ${item.subject}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (compact) ...[
                    identity,
                    if (primaryButton != null || moreMenu != null) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [?primaryButton, ?moreMenu],
                      ),
                    ],
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: identity),
                        if (primaryButton != null) ...[
                          const SizedBox(width: 20),
                          primaryButton,
                        ],
                        if (moreMenu != null) ...[
                          const SizedBox(width: 4),
                          moreMenu,
                        ],
                      ],
                    ),
                  const SizedBox(height: 30),
                  if (wideDesktop)
                    Row(
                      key: const Key('v2-case-desktop-columns'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          key: const Key('v2-case-timeline-column'),
                          child: timelineSection,
                        ),
                        const SizedBox(width: 32),
                        SizedBox(
                          width: 304,
                          child: Container(
                            key: const Key('v2-case-action-column'),
                            padding: const EdgeInsets.only(left: 24),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: scheme.outlineVariant),
                              ),
                            ),
                            child: actionSection,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      key: const Key('v2-case-stacked-sections'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        actionSection,
                        const SizedBox(height: 40),
                        timelineSection,
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
'''

old_case = prefix + new_body + suffix
source = source[:case_start] + old_case + source[case_end:]
SOURCE.write_text(source)

TEST.write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app({double textScale = 1, bool dark = false}) => MaterialApp(
    theme: dark ? V2Theme.dark() : V2Theme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: const V2WorkspacePreview(),
  );

  Future<void> openCase(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool dark = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(app(textScale: textScale, dark: dark));
    await tester.pumpAndSettle();
    final caseTitle = find.text('函数应用题思路不清').first;
    await tester.ensureVisible(caseTitle);
    await tester.tap(caseTitle);
    await tester.pumpAndSettle();
  }

  testWidgets('case detail stays stacked below expanded desktop breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openCase(tester, const Size(1024, 720));

    expect(find.byKey(const Key('v2-case-stacked-sections')), findsOneWidget);
    expect(find.byKey(const Key('v2-case-desktop-columns')), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('v2-case-next-step-case-lin-function'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('case detail separates timeline from action on wide desktop', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openCase(tester, const Size(1440, 800));

    final timeline = find.byKey(const Key('v2-case-timeline-column'));
    final action = find.byKey(const Key('v2-case-action-column'));
    expect(find.byKey(const Key('v2-case-desktop-columns')), findsOneWidget);
    expect(timeline, findsOneWidget);
    expect(action, findsOneWidget);
    expect(
      tester.getTopLeft(timeline).dx,
      lessThan(tester.getTopLeft(action).dx),
    );
    expect(
      find.byKey(
        const ValueKey<String>('v2-case-next-step-case-lin-function'),
      ),
      findsOneWidget,
    );
    expect(find.text('成长过程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('case wide desktop survives dark mode and 200 percent text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openCase(
      tester,
      const Size(1440, 800),
      textScale: 2,
      dark: true,
    );

    expect(find.byKey(const Key('v2-case-desktop-columns')), findsOneWidget);
    expect(find.byKey(const Key('v2-case-action-column')), findsOneWidget);
    expect(find.byKey(const Key('v2-case-timeline-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
''')

# One-shot staging artifacts must not survive the verified product commit.
if WORKFLOW.exists():
    WORKFLOW.unlink()
if SCRIPT.exists():
    SCRIPT.unlink()
