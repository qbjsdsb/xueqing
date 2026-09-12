from pathlib import Path


path = Path('lib/features/design_v2/v2_workspace_preview.dart')
source = path.read_text()


def replace_once(old: str, new: str) -> None:
    global source
    count = source.count(old)
    if count != 1:
        raise SystemExit(
            f'Expected exactly one match, got {count}: {old[:120]!r}'
        )
    source = source.replace(old, new)


replace_once(
    """                      Text(
                        '先处理已经安排好的跟进。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),""",
    """                      Text(
                        currentItems.isEmpty && undatedItems.isEmpty
                            ? '今天没有已安排的跟进。'
                            : '先处理已经安排好的跟进。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),""",
)

replace_once(
    """                  final quickCapture = FilledButton.tonalIcon(
                    key: const Key('v2-today-quick-capture'),
                    onPressed: () => _showV2QuickCaptureStudentPicker(context),
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('记录问题'),
                  );""",
    """                  final quickCapture = TextButton.icon(
                    key: const Key('v2-today-quick-capture'),
                    onPressed: () => _showV2QuickCaptureStudentPicker(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('记录问题'),
                  );""",
)

replace_once(
    """                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [""",
    """                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [""",
)

replace_once(
    """              if (currentItems.isEmpty && undatedItems.isEmpty)
                Text(
                  '今天暂时没有需要处理的提醒',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),""",
    """              if (currentItems.isEmpty && undatedItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '今天没有待处理事项',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '已经安排的跟进都处理好了。需要时可以继续查看学生或记录新问题。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),""",
)

replace_once(
    """              if (recentStudents.isNotEmpty) ...[
                const SizedBox(height: 28),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 18),
                const _SectionTitle(title: '最近学生'),
                const SizedBox(height: 8),
                for (final student in recentStudents.take(5))
                  _TodayRecentStudentRow(
                    student: student,
                    businessDate: data.businessDate,
                    onTap: () => onOpenStudent(student),
                  ),
              ],""",
    """              if (data.students.isNotEmpty) ...[
                const SizedBox(height: 28),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 18),
                _SectionTitle(
                  title: recentStudents.isEmpty ? '我的学生' : '最近学生',
                ),
                const SizedBox(height: 8),
                for (final student in (recentStudents.isEmpty
                    ? data.students.take(5)
                    : recentStudents.take(5)))
                  _TodayRecentStudentRow(
                    student: student,
                    businessDate: data.businessDate,
                    onTap: () => onOpenStudent(student),
                  ),
              ],""",
)

replace_once(
    """            Text(
              _recentActivityLabel(student.lastActivityAt!, businessDate),
              style: Theme.of(context).textTheme.bodySmall,
            ),""",
    """            Text(
              student.lastActivityAt == null
                  ? (student.openCaseCount == 0
                        ? '查看学生'
                        : '${student.openCaseCount} 个问题跟进中')
                  : _recentActivityLabel(student.lastActivityAt!, businessDate),
              style: Theme.of(context).textTheme.bodySmall,
            ),""",
)

replace_once(
    """    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;""",
    """    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;""",
)

replace_once(
    """            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(9),""",
    """            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),""",
)

replace_once(
    """                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.18),
                        ),
                      ),""",
    """                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),""",
)

path.write_text(source)
