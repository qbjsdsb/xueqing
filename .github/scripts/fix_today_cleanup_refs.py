from pathlib import Path

path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = path.read_text(encoding='utf-8')
text = text.replace('  bool _showAllPendingVerification = false;\n', '', 1)
old = """    final hasImmediateWork =
        hasScheduledWork ||
        pendingVerification.isNotEmpty ||
        undated.isNotEmpty;
    final hasBlockBeforeFuture =
        hasScheduledWork || !hasImmediateWork || pendingVerification.isNotEmpty;
"""
new = """    final hasImmediateWork = hasScheduledWork || undated.isNotEmpty;
    final hasBlockBeforeFuture = hasScheduledWork || !hasImmediateWork;
"""
if old not in text:
    raise RuntimeError('Today work-state block not found')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
