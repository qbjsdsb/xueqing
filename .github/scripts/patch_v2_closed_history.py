from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:140]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


# Presentation item can represent either an active follow-up or a read-only
# closed history item without changing stable Case identity.
fixture = 'lib/features/design_v2/v2_fixture.dart'
replace_once(
    fixture,
    """    this.actionTiming,
    this.pendingVerification = false,
  });
""",
    """    this.actionTiming,
    this.pendingVerification = false,
    this.closed = false,
  });
""",
)
replace_once(
    fixture,
    """  final V2ActionTiming? actionTiming;
  final bool pendingVerification;
}
""",
    """  final V2ActionTiming? actionTiming;
  final bool pendingVerification;
  final bool closed;
}
""",
)

# Keep active and historical Cases separate. Today continues to consume only
# focusItems, while student longitudinal timelines can span both collections.
data = 'lib/features/design_v2/v2_workspace_data.dart'
replace_once(
    data,
    """    required this.focusItems,
    required this.timeline,
    this.businessDate,
  });

  final List<V2Student> students;
  final List<V2FocusItem> focusItems;
  final List<V2TimelineEntry> timeline;
""",
    """    required this.focusItems,
    required this.timeline,
    this.closedItems = const <V2FocusItem>[],
    this.businessDate,
  });

  final List<V2Student> students;
  final List<V2FocusItem> focusItems;
  final List<V2FocusItem> closedItems;
  final List<V2TimelineEntry> timeline;
""",
)
replace_once(
    data,
    """  List<V2FocusItem> focusItemsForStudent(V2Student student) => focusItems
      .where((item) => item.studentId == student.id)
      .toList(growable: false);

  V2Student? studentForFocusItemOrNull(V2FocusItem item) {
""",
    """  List<V2FocusItem> focusItemsForStudent(V2Student student) => focusItems
      .where((item) => item.studentId == student.id)
      .toList(growable: false);

  List<V2FocusItem> closedItemsForStudent(V2Student student) => closedItems
      .where((item) => item.studentId == student.id)
      .toList(growable: false);

  V2Student? studentForFocusItemOrNull(V2FocusItem item) {
""",
)
replace_once(
    data,
    """  List<V2TimelineEntry> timelineForStudent(V2Student student) {
    final caseIds = focusItemsForStudent(student)
        .map((item) => item.id)
        .toSet();
    return timeline
        .where((entry) => caseIds.contains(entry.caseId))
        .toList(growable: false);
  }
""",
    """  List<V2TimelineEntry> timelineForStudent(V2Student student) {
    final caseIds = <String>{
      ...focusItemsForStudent(student).map((item) => item.id),
      ...closedItemsForStudent(student).map((item) => item.id),
    };
    return timeline
        .where((entry) => caseIds.contains(entry.caseId))
        .toList(growable: false);
  }
""",
)

adapter = 'lib/features/design_v2/v2_read_model_adapter.dart'
replace_once(
    adapter,
    """    required this.focusItems,
    required this.timeline,
""",
    """    required this.focusItems,
    required this.closedItems,
    required this.timeline,
""",
)
replace_once(
    adapter,
    """  final List<V2FocusItem> focusItems;
  final List<V2TimelineEntry> timeline;
""",
    """  final List<V2FocusItem> focusItems;
  final List<V2FocusItem> closedItems;
  final List<V2TimelineEntry> timeline;
""",
)
replace_once(
    adapter,
    """    focusItems: focusItems,
    timeline: timeline,
""",
    """    focusItems: focusItems,
    closedItems: closedItems,
    timeline: timeline,
""",
)
replace_once(
    adapter,
    """  List<V2FocusItem> focusItemsForStudent(String studentId) => focusItems
      .where((item) => item.studentId == studentId)
      .toList(growable: false);

  List<V2TimelineEntry> timelineForCase(String caseId) =>
""",
    """  List<V2FocusItem> focusItemsForStudent(String studentId) => focusItems
      .where((item) => item.studentId == studentId)
      .toList(growable: false);

  List<V2FocusItem> closedItemsForStudent(String studentId) => closedItems
      .where((item) => item.studentId == studentId)
      .toList(growable: false);

  List<V2TimelineEntry> timelineForCase(String caseId) =>
""",
)
replace_once(
    adapter,
    """    final focusItems = <V2FocusItem>[];
    final timeline = <V2TimelineEntry>[];
""",
    """    final focusItems = <V2FocusItem>[];
    final closedItems = <V2FocusItem>[];
    final timeline = <V2TimelineEntry>[];
""",
)
old_loop = """    for (final profile in workspace.students) {
      for (final learningCase in profile.cases) {
        if (!_isActiveCase(learningCase)) {
          continue;
        }

        final primaryAction = learningCase.primaryAction;
        focusItems.add(
          V2FocusItem(
            id: learningCase.id,
            studentId: profile.id,
            title: learningCase.title,
            summary: _caseSummary(learningCase),
            nextStep: _nextStep(primaryAction),
            dueLabel: _dueLabel(primaryAction),
            subject: profile.subject,
            actionTiming: _actionTiming(primaryAction),
            pendingVerification:
                learningCase.status == LearningCaseStatus.pendingVerification,
          ),
        );
        bindings.add(
          V2CaseBinding(
            studentId: profile.id,
            profileId: profile.profileId,
            profileVersion: profile.profileVersion,
            caseId: learningCase.id,
            caseVersion: learningCase.version,
            subject: profile.subject,
          ),
        );

        final caseTimeline = learningCase.timeline.toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        for (final event in caseTimeline) {
          timeline.add(
            V2TimelineEntry(
              caseId: learningCase.id,
              date: _dateLabel(event.occurredAt),
              kind: event.typeLabel,
              body: event.text,
              // WorkspaceTimelineEvent currently has no historical actor name.
              // An empty value is intentional: never attribute old records to
              // the current viewer just to fill the UI.
              teacher: '',
              time: _timeLabel(event.occurredAt),
              evidenceId: event.evidenceId,
            ),
          );
        }
      }
    }
"""
new_loop = """    for (final profile in workspace.students) {
      for (final learningCase in profile.cases) {
        final closed = learningCase.status == LearningCaseStatus.closed;
        final primaryAction = closed ? null : learningCase.primaryAction;
        final item = V2FocusItem(
          id: learningCase.id,
          studentId: profile.id,
          title: learningCase.title,
          summary: _caseSummary(learningCase),
          nextStep: closed ? '跟进已结束' : _nextStep(primaryAction),
          dueLabel: closed ? '已结束' : _dueLabel(primaryAction),
          subject: profile.subject,
          actionTiming: closed ? null : _actionTiming(primaryAction),
          pendingVerification:
              !closed &&
              learningCase.status == LearningCaseStatus.pendingVerification,
          closed: closed,
        );
        if (closed) {
          closedItems.add(item);
        } else {
          focusItems.add(item);
        }
        bindings.add(
          V2CaseBinding(
            studentId: profile.id,
            profileId: profile.profileId,
            profileVersion: profile.profileVersion,
            caseId: learningCase.id,
            caseVersion: learningCase.version,
            subject: profile.subject,
          ),
        );

        final caseTimeline = learningCase.timeline.toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        for (final event in caseTimeline) {
          timeline.add(
            V2TimelineEntry(
              caseId: learningCase.id,
              date: _dateLabel(event.occurredAt),
              kind: event.typeLabel,
              body: event.text,
              // WorkspaceTimelineEvent currently has no historical actor name.
              // An empty value is intentional: never attribute old records to
              // the current viewer just to fill the UI.
              teacher: '',
              time: _timeLabel(event.occurredAt),
              evidenceId: event.evidenceId,
            ),
          );
        }
      }
    }
"""
replace_once(adapter, old_loop, new_loop)
replace_once(
    adapter,
    """      focusItems: List<V2FocusItem>.unmodifiable(focusItems),
      timeline: List<V2TimelineEntry>.unmodifiable(timeline),
""",
    """      focusItems: List<V2FocusItem>.unmodifiable(focusItems),
      closedItems: List<V2FocusItem>.unmodifiable(closedItems),
      timeline: List<V2TimelineEntry>.unmodifiable(timeline),
""",
)

preview = 'lib/features/design_v2/v2_workspace_preview.dart'
replace_once(
    preview,
    """    final focusItems = data.focusItemsForStudent(student);
    final timelineEntries = data.timelineForStudent(student);
""",
    """    final focusItems = data.focusItemsForStudent(student);
    final closedItems = data.closedItemsForStudent(student);
    final timelineEntries = data.timelineForStudent(student);
""",
)
replace_once(
    preview,
    """                        ],
                      const SizedBox(height: 34),
                      const _SectionTitle(title: '最近成长'),
""",
    """                        ],
                      if (closedItems.isNotEmpty) ...[
                        const SizedBox(height: 34),
                        _SectionTitle(title: '历史问题', count: closedItems.length),
                        const SizedBox(height: 8),
                        for (var i = 0; i < closedItems.length; i++) ...[
                          _FocusRow(
                            item: closedItems[i],
                            onTap: () => onOpenCase(closedItems[i]),
                          ),
                          if (i < closedItems.length - 1)
                            Divider(height: 1, color: scheme.outlineVariant),
                        ],
                      ],
                      const SizedBox(height: 34),
                      const _SectionTitle(title: '最近成长'),
""",
)
replace_once(
    preview,
    """                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            _showV2ProgressForCase(context, student, item),
                        icon: const Icon(Icons.edit_note_outlined, size: 18),
                        label: const Text('记进展'),
                      ),
""",
    """                      if (!item.closed) ...[
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              _showV2ProgressForCase(context, student, item),
                          icon: const Icon(Icons.edit_note_outlined, size: 18),
                          label: const Text('记进展'),
                        ),
                      ],
""",
)
replace_once(
    preview,
    """class _CaseIndexPaneState extends State<_CaseIndexPane> {
  final _searchController = TextEditingController();
  String _query = '';
""",
    """class _CaseIndexPaneState extends State<_CaseIndexPane> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showClosed = false;
""",
)
replace_once(
    preview,
    """    final validItems = data.focusItems
        .where((item) => data.studentForFocusItemOrNull(item) != null)
""",
    """    final sourceItems = _showClosed ? data.closedItems : data.focusItems;
    final validItems = sourceItems
        .where((item) => data.studentForFocusItemOrNull(item) != null)
""",
)
replace_once(
    preview,
    """              Text('找到仍需要复盘的问题', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 22),
              TextField(
""",
    """              Text(
                _showClosed ? '回看已经结束的跟进记录' : '找到仍需要复盘的问题',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                key: const Key('v2-case-history-toggle'),
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: false, label: Text('跟进中')),
                  ButtonSegment<bool>(value: true, label: Text('历史')),
                ],
                selected: <bool>{_showClosed},
                onSelectionChanged: (selection) {
                  setState(() {
                    _showClosed = selection.first;
                    _query = '';
                    _searchController.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
""",
)
replace_once(
    preview,
    """                _query.trim().isEmpty
                    ? '进行中 ${visibleItems.length}'
                    : '找到 ${visibleItems.length} 个问题',
""",
    """                _query.trim().isEmpty
                    ? (_showClosed
                          ? '历史 ${visibleItems.length}'
                          : '进行中 ${visibleItems.length}')
                    : '找到 ${visibleItems.length} 个问题',
""",
)

# Adapter contract test: closed history remains separate, keeps stable identity,
# and contributes to the student's longitudinal timeline without changing the
# active count.
test = 'test/features/design_v2_read_model_adapter_test.dart'
replace_once(
    test,
    """      final mathBinding = snapshot.bindingForCase('case-math');
      expect(mathBinding, isNotNull);
      expect(mathBinding!.profileId, 'profile-math');
      expect(mathBinding.profileVersion, 5);
      expect(mathBinding.caseVersion, 2);
    });
""",
    """      final mathBinding = snapshot.bindingForCase('case-math');
      expect(mathBinding, isNotNull);
      expect(mathBinding!.profileId, 'profile-math');
      expect(mathBinding.profileVersion, 5);
      expect(mathBinding.caseVersion, 2);

      expect(snapshot.closedItems.map((item) => item.id), ['case-cn-closed']);
      final closedBinding = snapshot.bindingForCase('case-cn-closed');
      expect(closedBinding, isNotNull);
      expect(closedBinding!.profileId, 'profile-cn');
      expect(closedBinding.caseVersion, 9);
      expect(snapshot.closedItems.single.closed, isTrue);
      expect(snapshot.closedItems.single.nextStep, '跟进已结束');
    });
""",
)
replace_once(
    test,
    """        expect(snapshot.organizationName, '测试机构');
      },
    );
  });
}
""",
    """        expect(snapshot.organizationName, '测试机构');
      },
    );

    test('closed history stays out of active work but remains longitudinal', () {
      final snapshot = V2ReadModelAdapter.fromWorkspace(_workspace());
      final student = snapshot.students.firstWhere(
        (item) => item.id == 'student-lin',
      );

      expect(student.openCaseCount, 3);
      expect(snapshot.focusItems.any((item) => item.id == 'case-cn-closed'), isFalse);
      expect(snapshot.closedItemsForStudent('student-lin'), hasLength(1));
      expect(snapshot.timelineForCase('case-cn-closed').single.body, '结束前已经稳定完成。');
      final allCaseIds = snapshot.workspaceData
          .timelineForStudent(student)
          .map((entry) => entry.caseId)
          .toSet();
      expect(allCaseIds, contains('case-cn-closed'));
    });
  });
}
""",
)
replace_once(
    test,
    """          _case(
            id: 'case-cn-stable',
""",
    """          _case(
            id: 'case-cn-closed',
            profileId: 'profile-cn',
            title: '曾经的概括问题',
            status: LearningCaseStatus.closed,
            version: 9,
            description: '这条问题已经结束跟进。',
            timeline: [
              WorkspaceTimelineEvent(
                id: 'event-closed',
                occurredAt: DateTime(2026, 8, 28, 17, 20),
                typeLabel: '结束跟进',
                text: '结束前已经稳定完成。',
              ),
            ],
          ),
          _case(
            id: 'case-cn-stable',
""",
)

ui_test = 'test/features/design_v2_workspace_data_injection_test.dart'
replace_once(
    ui_test,
    """  testWidgets('unknown historical author renders time without fake separator', (
""",
    """  testWidgets('closed history is visible but stays read-only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(_dataWithClosedHistory));
    await tester.pumpAndSettle();

    expect(find.text('历史问题'), findsOneWidget);
    expect(find.text('曾经的问题'), findsOneWidget);
    await tester.tap(find.text('曾经的问题'));
    await tester.pumpAndSettle();

    expect(find.text('跟进已结束'), findsOneWidget);
    expect(find.text('历史时间线内容。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '记进展'), findsNothing);

    await tester.tap(find.byTooltip('学情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('历史 1'), findsOneWidget);
    expect(find.text('曾经的问题'), findsOneWidget);
  });

  testWidgets('unknown historical author renders time without fake separator', (
""",
)
replace_once(
    ui_test,
    """const _emptyData = V2WorkspaceData(students: [], focusItems: [], timeline: []);
""",
    """const _dataWithClosedHistory = V2WorkspaceData(
  students: [
    V2Student(
      id: 'history-student',
      name: '历史学生',
      grade: '初三',
      subjects: ['语文'],
      openCaseCount: 1,
      updatedLabel: '已有更新',
      teacherSummary: '当前工作区 · 语文',
    ),
  ],
  focusItems: [
    V2FocusItem(
      id: 'active-case',
      studentId: 'history-student',
      title: '当前问题',
      summary: '还在跟进。',
      nextStep: '下次检查',
      dueLabel: '9 月 12 日',
      subject: '语文',
      actionTiming: V2ActionTiming.today,
    ),
  ],
  closedItems: [
    V2FocusItem(
      id: 'closed-case',
      studentId: 'history-student',
      title: '曾经的问题',
      summary: '已经结束跟进。',
      nextStep: '跟进已结束',
      dueLabel: '已结束',
      subject: '语文',
      closed: true,
    ),
  ],
  timeline: [
    V2TimelineEntry(
      caseId: 'closed-case',
      date: '8 月 28 日',
      kind: '结束跟进',
      body: '历史时间线内容。',
      teacher: '',
      time: '17:20',
    ),
  ],
);

const _emptyData = V2WorkspaceData(students: [], focusItems: [], timeline: []);
""",
)

print('V2 closed history patch applied')
