from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1, found {count}')
    return text.replace(old, new, 1)

# 1) Read-model constants and strict companion matcher.
path = Path('lib/cloud/learning_repository.dart')
text = path.read_text()
needle = '''class WorkspaceEvidence {\n'''
insert = '''const String v2ObservationPhotoCompanionTitle = '本次表现图片';\nconst String v2InterventionPhotoCompanionTitle = '本次教学处理图片';\nconst String v2AssessmentPhotoCompanionTitle = '本次检查图片';\n\nString? v2ProgressPhotoCompanionEvidenceId({\n  required Iterable<WorkspaceEvidence> evidence,\n  required String expectedTitle,\n  required DateTime occurredAt,\n  required String summary,\n  String? excludingEvidenceId,\n}) {\n  final normalizedSummary = summary.trim();\n  final normalizedTime = occurredAt.toUtc();\n  for (final item in evidence) {\n    if (item.id == excludingEvidenceId ||\n        item.sourceType != 'observation' ||\n        item.title != expectedTitle ||\n        item.observedAt.toUtc() != normalizedTime ||\n        item.summary.trim() != normalizedSummary) {\n      continue;\n    }\n    return item.id;\n  }\n  return null;\n}\n\nclass WorkspaceEvidence {\n'''
text = replace_once(text, needle, insert, 'workspace evidence constants')

needle = '''    for (final item in evidence) {\n      if (initialEvidenceIds.contains(item.id)) {\n        continue;\n      }\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'evidence:${item.id}',\n          occurredAt: item.observedAt,\n          typeLabel: '学生表现',\n          text: '${item.summary}${progressSuffix(progressByRecordId[item.id])}',\n          evidenceId: item.id,\n        ),\n      );\n    }\n    for (final item in interventions) {\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'intervention:${item.id}',\n          occurredAt: item.occurredAt,\n          typeLabel: '教学处理',\n          text:\n              '${item.strategy}${progressSuffix(progressByRecordId[item.id])}',\n        ),\n      );\n    }\n    for (final item in assessments) {\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'assessment:${item.id}',\n          occurredAt: item.assessedAt,\n          typeLabel: '检查结果 · ${_assessmentResultLabel(item.result)}',\n          text:\n              '${item.evidenceSummary}${progressSuffix(progressByRecordId[item.id])}',\n        ),\n      );\n    }\n'''
replacement = '''    final progressPhotoEvidenceByRecordId = <String, String>{};\n    for (final item in evidence) {\n      if (initialEvidenceIds.contains(item.id) ||\n          progressByRecordId[item.id] == null) {\n        continue;\n      }\n      final companionId = v2ProgressPhotoCompanionEvidenceId(\n        evidence: evidence,\n        expectedTitle: v2ObservationPhotoCompanionTitle,\n        occurredAt: item.observedAt,\n        summary: item.summary,\n        excludingEvidenceId: item.id,\n      );\n      if (companionId != null) {\n        progressPhotoEvidenceByRecordId[item.id] = companionId;\n      }\n    }\n    for (final item in interventions) {\n      if (progressByRecordId[item.id] == null) {\n        continue;\n      }\n      final companionId = v2ProgressPhotoCompanionEvidenceId(\n        evidence: evidence,\n        expectedTitle: v2InterventionPhotoCompanionTitle,\n        occurredAt: item.occurredAt,\n        summary: item.strategy,\n      );\n      if (companionId != null) {\n        progressPhotoEvidenceByRecordId[item.id] = companionId;\n      }\n    }\n    for (final item in assessments) {\n      if (progressByRecordId[item.id] == null) {\n        continue;\n      }\n      final companionId = v2ProgressPhotoCompanionEvidenceId(\n        evidence: evidence,\n        expectedTitle: v2AssessmentPhotoCompanionTitle,\n        occurredAt: item.assessedAt,\n        summary: item.evidenceSummary,\n      );\n      if (companionId != null) {\n        progressPhotoEvidenceByRecordId[item.id] = companionId;\n      }\n    }\n    final linkedCompanionEvidenceIds =\n        progressPhotoEvidenceByRecordId.values.toSet();\n\n    for (final item in evidence) {\n      if (initialEvidenceIds.contains(item.id) ||\n          linkedCompanionEvidenceIds.contains(item.id)) {\n        continue;\n      }\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'evidence:${item.id}',\n          occurredAt: item.observedAt,\n          typeLabel: '学生表现',\n          text: '${item.summary}${progressSuffix(progressByRecordId[item.id])}',\n          evidenceId: progressPhotoEvidenceByRecordId[item.id] ?? item.id,\n        ),\n      );\n    }\n    for (final item in interventions) {\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'intervention:${item.id}',\n          occurredAt: item.occurredAt,\n          typeLabel: '教学处理',\n          text:\n              '${item.strategy}${progressSuffix(progressByRecordId[item.id])}',\n          evidenceId: progressPhotoEvidenceByRecordId[item.id],\n        ),\n      );\n    }\n    for (final item in assessments) {\n      timeline.add(\n        WorkspaceTimelineEvent(\n          id: 'assessment:${item.id}',\n          occurredAt: item.assessedAt,\n          typeLabel: '检查结果 · ${_assessmentResultLabel(item.result)}',\n          text:\n              '${item.evidenceSummary}${progressSuffix(progressByRecordId[item.id])}',\n          evidenceId: progressPhotoEvidenceByRecordId[item.id],\n        ),\n      );\n    }\n'''
text = replace_once(text, needle, replacement, 'timeline aggregation block')
path.write_text(text)

# 2) Writer shares the same occurredAt and imports the domain marker constants.
path = Path('lib/features/design_v2/v2_workflow_controller.dart')
text = path.read_text()
needle = '''    final needsCompanionEvidence =\n        write.attachments.isNotEmpty &&\n        (write.progressKind != CaseProgressKind.observation ||\n            write.nextStep == CaseProgressNextStep.close);\n\n    var expectedCaseVersion = learningCase.version;\n'''
replacement = '''    final needsCompanionEvidence =\n        write.attachments.isNotEmpty &&\n        (write.progressKind != CaseProgressKind.observation ||\n            write.nextStep == CaseProgressNextStep.close);\n    final progressOccurredAt = needsCompanionEvidence\n        ? (write.occurredAt ?? _now())\n        : write.occurredAt;\n\n    var expectedCaseVersion = learningCase.version;\n'''
text = replace_once(text, needle, replacement, 'shared occurredAt')
text = replace_once(
    text,
    '''            observedAt: write.occurredAt ?? _now(),\n''',
    '''            observedAt: progressOccurredAt!,\n''',
    'companion observedAt',
)
text = replace_once(
    text,
    '''        occurredAt: write.occurredAt,\n''',
    '''        occurredAt: progressOccurredAt,\n''',
    'progress occurredAt',
)
needle = '''  String _photoEvidenceTitle(CaseProgressKind kind) => switch (kind) {\n    CaseProgressKind.observation => '本次表现图片',\n    CaseProgressKind.intervention => '本次教学处理图片',\n    CaseProgressKind.assessment => '本次检查图片',\n  };\n'''
replacement = '''  String _photoEvidenceTitle(CaseProgressKind kind) => switch (kind) {\n    CaseProgressKind.observation => v2ObservationPhotoCompanionTitle,\n    CaseProgressKind.intervention => v2InterventionPhotoCompanionTitle,\n    CaseProgressKind.assessment => v2AssessmentPhotoCompanionTitle,\n  };\n'''
text = replace_once(text, needle, replacement, 'companion title constants')
path.write_text(text)

# 3) Strengthen controller test: writer identity must support deterministic grouping.
path = Path('test/features/design_v2_workflow_controller_test.dart')
test = path.read_text()
needle = '''      final controller = V2WorkflowController(\n        workspace: _workspace(),\n        learningRepository: learning,\n        progressiveCaseRepository: progress,\n        evidenceAttachmentRepository: attachments,\n      );\n\n      await controller.recordProgress(\n'''
replacement = '''      final occurredAt = DateTime.utc(2026, 9, 9, 10, 30);\n      final controller = V2WorkflowController(\n        workspace: _workspace(),\n        learningRepository: learning,\n        progressiveCaseRepository: progress,\n        evidenceAttachmentRepository: attachments,\n        now: () => occurredAt,\n      );\n\n      await controller.recordProgress(\n'''
# This exact shape appears first in intervention test; only replace once.
test = replace_once(test, needle, replacement, 'intervention fixed timestamp')
needle = '''      expect(learning.addEvidenceCalls.single.expectedCaseVersion, 3);\n      expect(progress.calls.single.expectedCaseVersion, 4);\n      expect(progress.calls.single.progressKind, CaseProgressKind.intervention);\n      expect(attachments.uploads.single.evidenceId, 'evidence-photo');\n'''
replacement = '''      expect(learning.addEvidenceCalls.single.expectedCaseVersion, 3);\n      expect(learning.addEvidenceCalls.single.title, v2InterventionPhotoCompanionTitle);\n      expect(learning.addEvidenceCalls.single.observedAt, occurredAt);\n      expect(progress.calls.single.expectedCaseVersion, 4);\n      expect(progress.calls.single.progressKind, CaseProgressKind.intervention);\n      expect(progress.calls.single.occurredAt, occurredAt);\n      expect(attachments.uploads.single.evidenceId, 'evidence-photo');\n'''
test = replace_once(test, needle, replacement, 'intervention grouping assertions')
path.write_text(test)
