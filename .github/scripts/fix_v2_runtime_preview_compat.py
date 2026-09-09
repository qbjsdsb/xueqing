from pathlib import Path

path = Path('lib/features/design_v2/v2_real_preview_page.dart')
text = path.read_text()
old = '''class V2RealPreviewPage extends StatelessWidget {\n  const V2RealPreviewPage({\n    required this.learningRepository,\n    this.progressiveCaseRepository,\n    this.evidenceAttachmentRepository,\n    this.onSignOut,\n    super.key,\n  });\n\n  final LearningRepository learningRepository;\n  final ProgressiveCaseRepository? progressiveCaseRepository;\n  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final VoidCallback? onSignOut;'''
new = '''class V2RealPreviewPage extends StatelessWidget {\n  V2RealPreviewPage({\n    LearningRepository? learningRepository,\n    V2WorkspaceLoad? loadWorkspace,\n    this.progressiveCaseRepository,\n    this.evidenceAttachmentRepository,\n    this.onSignOut,\n    super.key,\n  }) : assert(learningRepository != null || loadWorkspace != null),\n       learningRepository = learningRepository,\n       loadWorkspace = loadWorkspace ?? learningRepository!.loadWorkspace;\n\n  final LearningRepository? learningRepository;\n  final V2WorkspaceLoad loadWorkspace;\n  final ProgressiveCaseRepository? progressiveCaseRepository;\n  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final VoidCallback? onSignOut;'''
if text.count(old) != 1:
    raise SystemExit(f'preview constructor: expected 1, found {text.count(old)}')
text = text.replace(old, new, 1)
old = '''                loadWorkspace: learningRepository.loadWorkspace,\n                learningRepository: learningRepository,'''
new = '''                loadWorkspace: loadWorkspace,\n                learningRepository: learningRepository,'''
if text.count(old) != 1:
    raise SystemExit(f'preview loader bridge: expected 1, found {text.count(old)}')
text = text.replace(old, new, 1)
path.write_text(text)

path = Path('test/features/design_v2_real_preview_page_test.dart')
text = path.read_text()
old = "expect(find.text('真实数据只读预览'), findsOneWidget);"
new = "expect(find.text('V2 真实学情预览'), findsOneWidget);"
if text.count(old) != 1:
    raise SystemExit(f'preview title assertion: expected 1, found {text.count(old)}')
path.write_text(text.replace(old, new, 1))
