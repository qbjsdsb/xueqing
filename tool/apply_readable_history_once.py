from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing source anchor: {label}")
    return text.replace(old, new, 1)


repo_path = Path("lib/cloud/learning_repository.dart")
repo = repo_path.read_text()
repo = repo.replace(
    "LearningCaseStatus.stable => '稳定',\n    LearningCaseStatus.closed => '已关闭',",
    "LearningCaseStatus.stable => '暂时稳定',\n    LearningCaseStatus.closed => '已结束',",
)
repo = replace_once(
    repo,
    ".select('id,learning_case_id,event_type,occurred_at,metadata')",
    ".select(\n              'id,learning_case_id,event_type,occurred_at,metadata,operation_id',\n            )",
    "case event read fields",
)
old_timeline = """    final timeline = <WorkspaceTimelineEvent>[];
    for (final eventRow
        in eventRows[caseId] ?? const <Map<String, dynamic>>[]) {
      final eventType = _stringValue(eventRow['event_type']) ?? 'event';
      timeline.add(
        WorkspaceTimelineEvent(
          id: _requiredString(eventRow['id'], 'event_id'),
          occurredAt: _requiredDateTime(
            eventRow['occurred_at'],
            'event_occurred_at',
          ),
          typeLabel: _eventTypeLabel(eventType),
          text: _eventText(eventType, eventRow['metadata']),
        ),
      );
    }
    for (final item in evidence) {
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'evidence:${item.id}',
          occurredAt: item.observedAt,
          typeLabel: 'Evidence / 证据',
          text: '${item.title}：${item.summary}',
        ),
      );
    }
    for (final item in interventions) {
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'intervention:${item.id}',
          occurredAt: item.occurredAt,
          typeLabel: 'Intervention / 教学动作',
          text: item.strategy,
        ),
      );
    }
    for (final item in assessments) {
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'assessment:${item.id}',
          occurredAt: item.assessedAt,
          typeLabel: 'Assessment / 验证',
          text:
              '${_assessmentResultLabel(item.result)}：${item.evidenceSummary}',
        ),
      );
    }
    timeline.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
"""
new_timeline = """    final timeline = <WorkspaceTimelineEvent>[];
    final currentEventRows =
        eventRows[caseId] ?? const <Map<String, dynamic>>[];
    final evidenceById = <String, WorkspaceEvidence>{
      for (final item in evidence) item.id: item,
    };
    final progressByRecordId = <String, Map<String, dynamic>>{};
    final progressOperationIds = <String>{};
    final initialEvidenceIds = <String>{};

    for (final eventRow in currentEventRows) {
      final eventType = _stringValue(eventRow['event_type']) ?? 'event';
      final metadata = _metadataMap(eventRow['metadata']);
      if (eventType == 'case_created') {
        final evidenceId = _stringValue(metadata['evidence_id']);
        if (evidenceId != null) {
          initialEvidenceIds.add(evidenceId);
        }
      }
      final recordId = _stringValue(metadata['record_id']);
      if (recordId != null &&
          const <String>{
            'evidence_recorded',
            'intervention_recorded',
            'assessment_recorded',
          }.contains(eventType)) {
        progressByRecordId[recordId] = eventRow;
        final operationId = _stringValue(eventRow['operation_id']);
        if (operationId != null) {
          progressOperationIds.add(operationId);
        }
      }
    }

    String progressSuffix(Map<String, dynamic>? progressEvent) {
      if (progressEvent == null) {
        return '';
      }
      final metadata = _metadataMap(progressEvent['metadata']);
      final nextStep = _stringValue(metadata['next_step']);
      if (nextStep == 'close') {
        return '\\n结束跟进。';
      }
      if (nextStep != 'remind') {
        return '';
      }
      final nextActionId = _stringValue(metadata['next_action_id']);
      if (nextActionId != null) {
        for (final action in actions) {
          if (action.id == nextActionId) {
            return '\\n下一步：${action.title}';
          }
        }
      }
      return '\\n已设置后续提醒。';
    }

    for (final eventRow in currentEventRows) {
      final eventType = _stringValue(eventRow['event_type']) ?? 'event';
      final metadata = _metadataMap(eventRow['metadata']);
      if (const <String>{
        'evidence_recorded',
        'intervention_recorded',
        'assessment_recorded',
      }.contains(eventType)) {
        continue;
      }
      final operationId = _stringValue(eventRow['operation_id']);
      if (operationId != null &&
          progressOperationIds.contains(operationId) &&
          const <String>{
            'action_completed',
            'case_stabilized',
            'case_closed',
          }.contains(eventType)) {
        continue;
      }
      if (eventType == 'case_created') {
        final initialEvidenceId = _stringValue(metadata['evidence_id']);
        final initialEvidence = initialEvidenceId == null
            ? null
            : evidenceById[initialEvidenceId];
        final problemTitle = _requiredString(row['title'], 'case_title');
        timeline.add(
          WorkspaceTimelineEvent(
            id: _requiredString(eventRow['id'], 'event_id'),
            occurredAt: _requiredDateTime(
              eventRow['occurred_at'],
              'event_occurred_at',
            ),
            typeLabel: '发现问题',
            text: initialEvidence == null
                ? problemTitle
                : '$problemTitle\\n具体表现：${initialEvidence.summary}',
          ),
        );
        continue;
      }
      timeline.add(
        WorkspaceTimelineEvent(
          id: _requiredString(eventRow['id'], 'event_id'),
          occurredAt: _requiredDateTime(
            eventRow['occurred_at'],
            'event_occurred_at',
          ),
          typeLabel: _eventTypeLabel(eventType),
          text: _eventText(eventType, eventRow['metadata']),
        ),
      );
    }
    for (final item in evidence) {
      if (initialEvidenceIds.contains(item.id)) {
        continue;
      }
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'evidence:${item.id}',
          occurredAt: item.observedAt,
          typeLabel: '学生表现',
          text: '${item.summary}${progressSuffix(progressByRecordId[item.id])}',
        ),
      );
    }
    for (final item in interventions) {
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'intervention:${item.id}',
          occurredAt: item.occurredAt,
          typeLabel: '教学处理',
          text: '${item.strategy}${progressSuffix(progressByRecordId[item.id])}',
        ),
      );
    }
    for (final item in assessments) {
      timeline.add(
        WorkspaceTimelineEvent(
          id: 'assessment:${item.id}',
          occurredAt: item.assessedAt,
          typeLabel: '检查结果 · ${_assessmentResultLabel(item.result)}',
          text:
              '${item.evidenceSummary}${progressSuffix(progressByRecordId[item.id])}',
        ),
      );
    }
    timeline.sort((left, right) {
      final timeComparison = right.occurredAt.compareTo(left.occurredAt);
      return timeComparison != 0 ? timeComparison : left.id.compareTo(right.id);
    });
"""
repo = replace_once(repo, old_timeline, new_timeline, "timeline assembly")
old_labels = """String _eventTypeLabel(String value) {
  return switch (value) {
    'case_created' => 'Case / 创建',
    'case_confirmed' => 'Case / 确认',
    'evidence_recorded' => 'Evidence / 证据',
    'intervention_recorded' => 'Intervention / 教学动作',
    'assessment_recorded' => 'Assessment / 验证',
    'case_stabilized' => 'Case / 稳定',
    'case_closed' => 'Case / 关闭',
    'case_reopened' => 'Case / 重新打开',
    'action_completed' => 'Action / 完成',
    'action_rescheduled' => 'Action / 改期',
    _ => '记录',
  };
}

String _eventText(String eventType, dynamic rawMetadata) {
  final metadata = rawMetadata is Map
      ? Map<String, dynamic>.from(rawMetadata)
      : const <String, dynamic>{};
  return switch (eventType) {
    'case_created' => '创建了这条 Learning Case。',
    'case_confirmed' => 'Case 已确认，进入正式跟进。',
    'evidence_recorded' => '补充了一条 Evidence。',
    'intervention_recorded' => '记录了一次教学动作。',
    'assessment_recorded' =>
      '记录了一次验证：${_assessmentResultLabel(metadata['result'])}。',
    'case_stabilized' => '教师确认 Case 已稳定，仍可安排复查。',
    'case_closed' => 'Case 已关闭。',
    'case_reopened' => 'Case 因关闭后的新复发证据重新打开。',
    'action_completed' => '完成了当前行动，并安排了下一步。',
    'action_rescheduled' => '调整了下一行动的日期。',
    _ => '记录了一条 Case 事件。',
  };
}
"""
new_labels = """String _eventTypeLabel(String value) {
  return switch (value) {
    'case_created' => '发现问题',
    'case_confirmed' => '开始跟进',
    'evidence_recorded' => '学生表现',
    'intervention_recorded' => '教学处理',
    'assessment_recorded' => '检查结果',
    'case_stabilized' => '暂时稳定',
    'case_closed' => '结束跟进',
    'case_reopened' => '重新跟进',
    'action_completed' => '完成提醒',
    'action_rescheduled' => '调整提醒',
    _ => '记录',
  };
}

Map<String, dynamic> _metadataMap(dynamic rawMetadata) {
  return rawMetadata is Map
      ? Map<String, dynamic>.from(rawMetadata)
      : const <String, dynamic>{};
}

String _eventText(String eventType, dynamic rawMetadata) {
  final metadata = _metadataMap(rawMetadata);
  return switch (eventType) {
    'case_created' => '记录了一个需要关注的问题。',
    'case_confirmed' => '开始持续跟进这个问题。',
    'evidence_recorded' => '补充了新的学生表现。',
    'intervention_recorded' => '记录了一次教学处理。',
    'assessment_recorded' =>
      '检查结果：${_assessmentResultLabel(metadata['result'])}。',
    'case_stabilized' => '目前表现已经稳定。',
    'case_closed' => '本轮跟进已经结束，历史记录完整保留。',
    'case_reopened' => '出现新情况，重新开始跟进。',
    'action_completed' => '完成了当前提醒。',
    'action_rescheduled' => '调整了提醒时间。',
    _ => '补充了一条记录。',
  };
}
"""
repo = replace_once(repo, old_labels, new_labels, "event labels")
repo_path.write_text(repo)

page_path = Path("lib/features/teacher_workspace/presentation/teacher_workspace_page.dart")
page = page_path.read_text()
page = replace_once(
    page,
    "import '../../../core/logging/app_logger.dart';\n",
    "import '../../../core/logging/app_logger.dart';\nimport '../../../export/learning_record_export.dart';\n",
    "export import",
)
method_anchor = """  Widget _buildStudentDetail(
    WorkspaceStudent student,
    WindowSizeClass sizeClass,
  ) {
"""
method = """  Future<void> _exportStudentSubject(WorkspaceStudent student) async {
    final rows = LearningRecordExport.rowsForStudentSubject(student);
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可导出的记录。')),
        );
      }
      return;
    }
    try {
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension: LearningRecordExport.studentSubjectFileName(
          student,
        ),
        rows: rows,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(savedPath == null ? '已取消导出。' : '学情记录表已生成。')),
      );
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'student_subject_export_failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败，请重试。')),
        );
      }
    }
  }

"""
page = replace_once(page, method_anchor, method + method_anchor, "student export method")
header_actions = """          actions: [
            FilledButton.icon(
              onPressed: () => _showQuickCapture(student: student),
              icon: Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
"""
new_header_actions = """          actions: [
            OutlinedButton.icon(
              key: const Key('student-detail-export'),
              onPressed: () => unawaited(_exportStudentSubject(student)),
              icon: const Icon(Icons.download_outlined),
              label: const Text('导出学情记录'),
            ),
            FilledButton.icon(
              onPressed: () => _showQuickCapture(student: student),
              icon: Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
"""
page = replace_once(page, header_actions, new_header_actions, "student detail actions")
for old, new in (
    ("title: '已采取的方法',", "title: '教学处理',"),
    ("? '尚未记录教学动作。'", "? '尚未记录教学处理。'"),
    ("title: '验证记录',", "title: '检查结果',"),
    ("? '尚未记录验证。'", "? '尚未记录检查结果。'"),
    ("title: '历史 timeline',", "title: '成长记录',"),
    ("child: Text(_showAllCaseTimeline ? '收起历史' : '展开历史'),", "child: Text(_showAllCaseTimeline ? '收起记录' : '查看更早记录'),"),
):
    page = replace_once(page, old, new, old)
page_path.write_text(page)
