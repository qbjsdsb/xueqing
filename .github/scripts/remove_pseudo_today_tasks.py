from pathlib import Path
import re

workspace_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = workspace_path.read_text(encoding='utf-8')

text = text.replace("    final pendingVerification = <WorkspaceCaseWithContext>[];\n", "", 1)
text = text.replace(
    "        if (learningCase.status == LearningCaseStatus.pendingVerification) {\n          pendingVerification.add(\n            WorkspaceCaseWithContext(\n              student: student,\n              learningCase: learningCase,\n            ),\n          );\n          continue;\n        }",
    "        if (learningCase.status == LearningCaseStatus.pendingVerification &&\n            learningCase.primaryAction == null) {\n          // A completed check is a student fact, not a second confirmation task.\n          continue;\n        }",
    1,
)
text = text.replace(
    "    final hasImmediateWork =\n        hasScheduledWork ||\n        pendingVerification.isNotEmpty ||\n        undated.isNotEmpty;\n    final hasBlockBeforeFuture =\n        hasScheduledWork ||\n        !hasImmediateWork ||\n        pendingVerification.isNotEmpty;",
    "    final hasImmediateWork = hasScheduledWork || undated.isNotEmpty;\n    final hasBlockBeforeFuture = hasScheduledWork || !hasImmediateWork;",
    1,
)
pattern = re.compile(
    r"\n        if \(pendingVerification\.isNotEmpty\) \.\.\.\[.*?\n        \],\n        if \(future\.isNotEmpty\)",
    re.S,
)
text, count = pattern.subn("\n        if (future.isNotEmpty)", text, count=1)
if count != 1:
    raise RuntimeError(f'expected one pending-verification Today section, found {count}')
text = text.replace(
    "                : '可以回看最近学生，或在课堂中先记录一句问题。',",
    "                : '可以回看最近学生，或在课堂中随手记下一条新情况。',",
    1,
)
workspace_path.write_text(text, encoding='utf-8')

learning_path = Path('lib/cloud/learning_repository.dart')
text = learning_path.read_text(encoding='utf-8')
text = text.replace("    LearningCaseStatus.confirmed => '已确认',", "    LearningCaseStatus.confirmed => '跟进中',", 1)
text = text.replace("    LearningCaseStatus.intervening => '干预中',", "    LearningCaseStatus.intervening => '跟进中',", 1)
text = text.replace("    LearningCaseStatus.pendingVerification => '待验证',", "    LearningCaseStatus.pendingVerification => '继续关注',", 1)
learning_path.write_text(text, encoding='utf-8')

export_path = Path('lib/export/learning_record_export.dart')
text = export_path.read_text(encoding='utf-8')
text = text.replace("      LearningCaseStatus.pendingVerification => '待验证',", "      LearningCaseStatus.pendingVerification => '继续关注',", 1)
export_path.write_text(text, encoding='utf-8')

print('Removed pseudo Today tasks and softened status labels.')
