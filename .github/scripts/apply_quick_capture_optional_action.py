from pathlib import Path


def replace_once(text: str, label: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


repository_path = Path('lib/cloud/learning_repository.dart')
repository = repository_path.read_text()

repository = replace_once(
    repository,
    'QuickCaptureCommand constructor optional Action',
    '''    required this.evidenceSummary,\n    required this.nextActionTitle,\n    required this.nextActionDueAt,\n    this.organizationCaseTypeId,''',
    '''    required this.evidenceSummary,\n    this.nextActionTitle,\n    this.nextActionDueAt,\n    this.organizationCaseTypeId,''',
)
repository = replace_once(
    repository,
    'QuickCaptureCommand nullable Action field',
    '''  final String evidenceSummary;\n  final String nextActionTitle;\n  final DateTime? nextActionDueAt;''',
    '''  final String evidenceSummary;\n  final String? nextActionTitle;\n  final DateTime? nextActionDueAt;''',
)
repository = replace_once(
    repository,
    'QuickCaptureCommand optional Action validation',
    '''    if (nextActionTitle.trim().isEmpty) {\n      throw ArgumentError('nextActionTitle cannot be empty.');\n    }\n    if (organizationCaseTypeId != null &&''',
    '''    final normalizedNextActionTitle = nextActionTitle?.trim();\n    if (normalizedNextActionTitle != null &&\n        normalizedNextActionTitle.isEmpty) {\n      throw ArgumentError('nextActionTitle cannot be blank.');\n    }\n    if (normalizedNextActionTitle == null && nextActionDueAt != null) {\n      throw ArgumentError(\n        'nextActionDueAt requires an explicit nextActionTitle.',\n      );\n    }\n    if (organizationCaseTypeId != null &&''',
)
repository = replace_once(
    repository,
    'QuickCaptureReceipt optional Action constructor',
    '''    required this.caseId,\n    required this.evidenceId,\n    required this.actionId,\n    required this.status,''',
    '''    required this.caseId,\n    required this.evidenceId,\n    this.actionId,\n    required this.status,''',
)
repository = replace_once(
    repository,
    'QuickCaptureReceipt nullable Action field',
    '''  final String caseId;\n  final String evidenceId;\n  final String actionId;\n  final String status;''',
    '''  final String caseId;\n  final String evidenceId;\n  final String? actionId;\n  final String status;''',
)
repository = replace_once(
    repository,
    'QuickCaptureReceipt nullable Action parse',
    '''    final evidenceId = _requiredString(json['evidence_id'], 'evidence_id');\n    final actionId = _requiredString(json['action_id'], 'action_id');''',
    '''    final evidenceId = _requiredString(json['evidence_id'], 'evidence_id');\n    final actionId = _stringValue(json['action_id']);''',
)
repository = replace_once(
    repository,
    'Supabase Quick Capture nullable Action param',
    "      'p_next_action_title': command.nextActionTitle.trim(),",
    "      'p_next_action_title': command.nextActionTitle?.trim(),",
)
repository_path.write_text(repository)

workspace_path = Path(
    'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart'
)
workspace = workspace_path.read_text()
workspace = replace_once(
    workspace,
    'Teacher workspace removes manufactured Quick Capture Action',
    '''          evidenceSummary: _evidenceController.text.trim(),\n          nextActionTitle: '补充证据并确认下一步',\n          nextActionDueAt: null,\n        ),''',
    '''          evidenceSummary: _evidenceController.text.trim(),\n        ),''',
)
workspace_path.write_text(workspace)
