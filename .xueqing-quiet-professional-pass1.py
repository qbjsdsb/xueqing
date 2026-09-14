from pathlib import Path

workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = workspace_path.read_text()

old = '''class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text('$count', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
'''
new = '''class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 7),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
'''
assert old in text, 'SectionTitle anchor not found'
text = text.replace(old, new, 1)

old = '''              if (futureItems.isNotEmpty) ...[
                const SizedBox(height: 28),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ExpansionTile(
'''
new = '''              if (futureItems.isNotEmpty) ...[
                const SizedBox(height: 34),
                ExpansionTile(
'''
assert old in text, 'Today future divider anchor not found'
text = text.replace(old, new, 1)

old = '''              if (data.students.isNotEmpty) ...[
                const SizedBox(height: 28),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 18),
                _SectionTitle(title: recentStudents.isEmpty ? '我的学生' : '最近学生'),
'''
new = '''              if (data.students.isNotEmpty) ...[
                const SizedBox(height: 38),
                _SectionTitle(title: recentStudents.isEmpty ? '我的学生' : '最近学生'),
'''
assert old in text, 'Today student divider anchor not found'
text = text.replace(old, new, 1)

old = '''          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
'''
new = '''          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
'''
assert old in text, 'Today action padding anchor not found'
text = text.replace(old, new, 1)

old = '''                Container(
                  width: 2,
                  height: 62,
'''
new = '''                Container(
                  width: 2,
                  height: 54,
'''
assert old in text, 'Today action indicator anchor not found'
text = text.replace(old, new, 1)

old = '''                      Text(
                        '${student.name} · ${item.subject}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.pendingVerification
                            ? '${item.title} · 待复检'
                            : item.title,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
'''
new = '''                      Text(
                        '${student.name} · ${item.subject} · ${item.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
'''
assert old in text, 'Today metadata anchor not found'
text = text.replace(old, new, 1)

workspace_path.write_text(text)

test_path = Path('test/features/quiet_professional_visual_foundation_test.dart')
test_path.write_text(r'''import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_page_header.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';

void main() {
  testWidgets('top-level header has a clear editorial hierarchy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 800,
            child: V2PageHeader(
              title: '今日',
              meta: '9 月 14 日 · 周一',
              description: '只保留老师下一步真正需要处理的信息。',
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('今日'));
    final meta = tester.widget<Text>(find.text('9 月 14 日 · 周一'));
    final description = tester.widget<Text>(
      find.text('只保留老师下一步真正需要处理的信息。'),
    );

    expect(title.style?.fontSize, 29);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(meta.style?.fontSize, lessThan(title.style!.fontSize!));
    expect(description.style?.fontSize, lessThan(title.style!.fontSize!));
    expect(tester.takeException(), isNull);
  });

  test('Today uses spacing and typography instead of extra section chrome', () {
    final source = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    final todayStart = source.indexOf('class _TodayPane');
    final actionStart = source.indexOf('class _TodayAction');
    final todayBlock = source.substring(todayStart, actionStart);

    expect(todayStart, greaterThanOrEqualTo(0));
    expect(actionStart, greaterThan(todayStart));
    expect(todayBlock, isNot(contains('Divider(')));
    expect(
      source,
      contains("'${student.name} · ${item.subject} · ${item.title}'"),
    );
    expect(source, contains("'v2-today-complete-${item.id}'"));
    expect(source, contains("'v2-today-reschedule-${item.id}'"));
  });

  test('section labels stay quieter than content titles', () {
    final source = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    final sectionStart = source.indexOf('class _SectionTitle');
    final focusStart = source.indexOf('class _FocusRow');
    final sectionBlock = source.substring(sectionStart, focusStart);

    expect(sectionBlock, contains('theme.textTheme.titleSmall?.copyWith('));
    expect(sectionBlock, contains('scheme.onSurfaceVariant'));
    expect(sectionBlock, isNot(contains('textTheme.titleLarge')));
  });
}
''')
