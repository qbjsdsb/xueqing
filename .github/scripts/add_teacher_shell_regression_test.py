from pathlib import Path

path = Path('test/features/teacher_workspace_test.dart')
text = path.read_text(encoding='utf-8')

old_signature = '''Future<void> _pumpWorkspace(
  WidgetTester tester,
  _FakeLearningRepository repository, {
  CaseReopenDraftStore? draftStore,
  String? sessionUserId,
}) async {
'''
new_signature = '''Future<void> _pumpWorkspace(
  WidgetTester tester,
  _FakeLearningRepository repository, {
  CaseReopenDraftStore? draftStore,
  String? sessionUserId,
  VoidCallback? onSignOut,
}) async {
'''
if text.count(old_signature) != 1:
    raise SystemExit(f'Expected one _pumpWorkspace signature, found {text.count(old_signature)}')
text = text.replace(old_signature, new_signature, 1)

old_page_args = '''        caseReopenDraftStore: draftStore,
        sessionUserId: sessionUserId,
      ),
'''
new_page_args = '''        caseReopenDraftStore: draftStore,
        sessionUserId: sessionUserId,
        onSignOut: onSignOut,
      ),
'''
if text.count(old_page_args) != 1:
    raise SystemExit(f'Expected one TeacherWorkspacePage helper call, found {text.count(old_page_args)}')
text = text.replace(old_page_args, new_page_args, 1)

marker = 'void main() {\n'
test = '''void main() {
  testWidgets('medium-width rail keeps labels and sign out reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var signOutCount = 0;
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(
      tester,
      repository,
      onSignOut: () => signOutCount++,
    );

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.labelType, NavigationRailLabelType.all);
    expect(find.byKey(const Key('workspace-rail-sign-out')), findsOneWidget);
    expect(find.text('开发数据'), findsNothing);

    await tester.tap(find.byKey(const Key('workspace-rail-sign-out')));
    expect(signOutCount, 1);
  });

'''
if text.count(marker) != 1:
    raise SystemExit(f'Expected one main marker, found {text.count(marker)}')
text = text.replace(marker, test, 1)

path.write_text(text, encoding='utf-8')
