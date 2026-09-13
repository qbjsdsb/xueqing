from pathlib import Path
import re

preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text(encoding='utf-8')

compact_pattern = re.compile(
    r"class _CompactWorkspaceState extends State<_CompactWorkspace> \{.*?\n\}\n\nclass _NavigationRail",
    re.S,
)
compact_replacement = r'''class _CompactWorkspaceState extends State<_CompactWorkspace> {
  late final PageController _pageController;
  bool _editingText = false;

  int get _destinationIndex =>
      _compactPrimaryDestinations.indexOf(widget.destination);

  @override
  void initState() {
    super.initState();
    final initialIndex = _destinationIndex;
    _pageController = PageController(initialPage: initialIndex < 0 ? 0 : initialIndex);
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CompactWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      _syncPagerToDestination();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    _pageController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final editing = focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() != null);
    if (!mounted || editing == _editingText) return;
    setState(() => _editingText = editing);
  }

  void _syncPagerToDestination() {
    final index = _destinationIndex;
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final currentPage =
          _pageController.page?.round() ?? _pageController.initialPage;
      if (currentPage != index) {
        _pageController.jumpToPage(index);
      }
    });
  }

  void _handlePageChanged(int index) {
    if (index < 0 || index >= _compactPrimaryDestinations.length) return;
    final destination = _compactPrimaryDestinations[index];
    if (destination != widget.destination) {
      widget.onDestinationChanged(destination);
    }
  }

  void _selectPrimaryDestination(int index) {
    if (index < 0 || index >= _compactPrimaryDestinations.length) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final destination = _compactPrimaryDestinations[index];
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
    if (destination != widget.destination) {
      widget.onDestinationChanged(destination);
    }
  }

  bool get _hasInternalHistory =>
      widget.destination == V2WorkspaceDestination.students &&
      (widget.showCase || widget.showStudentDetail);

  Widget _buildRootPager(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final pagingEnabled = Theme.of(context).platform == TargetPlatform.android &&
        !_editingText &&
        !keyboardVisible;

    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (notification) {
        notification.disallowIndicator();
        return false;
      },
      child: PageView(
        key: const Key('v2-compact-swipe-surface'),
        controller: _pageController,
        physics: pagingEnabled
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        onPageChanged: _handlePageChanged,
        children: [
          _KeepAlivePage(
            key: const ValueKey<String>('v2-compact-root-today'),
            child: _TodayPane(
              onOpenCase: widget.onOpenCase,
              onOpenStudent: (student) {
                widget.onStudentSelected(student);
                widget.onDestinationChanged(V2WorkspaceDestination.students);
              },
              compact: true,
              onOpenMore: widget.onOpenMore,
            ),
          ),
          _KeepAlivePage(
            key: const ValueKey<String>('v2-compact-root-students'),
            child: _StudentListPane(
              selectedStudent: widget.selectedStudent,
              compact: true,
              onOpenMore: widget.onOpenMore,
              onSelected: widget.onStudentSelected,
            ),
          ),
          _KeepAlivePage(
            key: const ValueKey<String>('v2-compact-root-learning'),
            child: _CaseIndexPane(
              onOpenCase: widget.onOpenCase,
              compact: true,
              onOpenMore: widget.onOpenMore,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildForegroundBody(BuildContext context) {
    if (widget.destination == V2WorkspaceDestination.students &&
        widget.showCase &&
        widget.selectedCase != null) {
      return _CaseDetailPane(
        student: widget.selectedStudent,
        item: widget.selectedCase!,
        onBack: widget.onBackFromCase,
        compact: true,
      );
    }
    if (widget.destination == V2WorkspaceDestination.students &&
        widget.showStudentDetail) {
      return _StudentDetailPane(
        student: widget.selectedStudent,
        onOpenCase: widget.onOpenCase,
        compact: true,
        onBack: widget.onBackFromStudent,
      );
    }
    if (widget.destination == V2WorkspaceDestination.organization) {
      return widget.organizationPageBuilder!(
        context,
        widget.onBackFromOrganization,
        widget.organizationSection,
        widget.onOrganizationSectionChanged,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final foregroundBody = _buildForegroundBody(context);
    final hasForegroundBody = foregroundBody != null;
    final handlesSystemBack =
        _hasInternalHistory ||
        (widget.destination != V2WorkspaceDestination.today &&
            widget.destination != V2WorkspaceDestination.organization);

    return PopScope<void>(
      canPop: !handlesSystemBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.destination == V2WorkspaceDestination.students &&
            widget.showCase) {
          widget.onBackFromCase();
          return;
        }
        if (widget.destination == V2WorkspaceDestination.students &&
            widget.showStudentDetail) {
          widget.onBackFromStudent();
          return;
        }
        if (widget.destination != V2WorkspaceDestination.today &&
            widget.destination != V2WorkspaceDestination.organization) {
          widget.onDestinationChanged(V2WorkspaceDestination.today);
        }
      },
      child: Scaffold(
        key: const Key('v2-compact-shell'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: IndexedStack(
            index: hasForegroundBody ? 1 : 0,
            children: [
              _buildRootPager(context),
              foregroundBody ?? const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: hasForegroundBody
            ? null
            : NavigationBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedIndex: _destinationIndex,
                onDestinationSelected: _selectPrimaryDestination,
                destinations: [
                  for (final destination in _compactPrimaryDestinations)
                    _compactNavigationDestination(destination),
                ],
              ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child, super.key});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _NavigationRail'''

preview, count = compact_pattern.subn(lambda _: compact_replacement, preview, count=1)
if count != 1:
    raise SystemExit(f'expected one compact workspace block, found {count}')
preview_path.write_text(preview, encoding='utf-8')

test_path = Path('test/features/design_v2_workspace_test.dart')
tests = test_path.read_text(encoding='utf-8')

edge_test_pattern = re.compile(
    r"  testWidgets\(\n    'Android compact page swipe leaves system gesture edges to Back',.*?\n  \);\n\n  testWidgets\(\n    'Android compact page swipe yields while the keyboard is visible',",
    re.S,
)
edge_test_replacement = r'''  testWidgets(
    'Android compact direct manipulation updates page offset before release',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('v2-compact-swipe-surface'));
      final pageView = tester.widget<PageView>(surface);
      expect(pageView.controller, isNotNull);
      expect(pageView.controller!.page, closeTo(0, 0.01));

      final gesture = await tester.startGesture(tester.getCenter(surface));
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();

      final draggedPage = pageView.controller!.page!;
      expect(draggedPage, greaterThan(0.05));
      expect(draggedPage, lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact center paging remains usable with system gesture insets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        androidApp(
          systemGestureInsets: const EdgeInsets.symmetric(horizontal: 24),
        ),
      );
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('v2-compact-swipe-surface'));
      await tester.drag(surface, const Offset(-220, 0));
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.selectedIndex, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact page swipe yields while the keyboard is visible','''

tests, count = edge_test_pattern.subn(lambda _: edge_test_replacement, tests, count=1)
if count != 1:
    raise SystemExit(f'expected one edge swipe test block, found {count}')

insert_before = "  testWidgets('student search filters real people without changing identity', (\n"
if insert_before not in tests:
    raise SystemExit('student search test insertion point not found')
state_tests = r'''  testWidgets(
    'Android compact root paging pauses while a text field is actively edited',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();

      final search = find.byKey(const Key('v2-student-search'));
      await tester.tap(search);
      await tester.enterText(search, '王同学');
      await tester.pump();

      final surface = find.byKey(const Key('v2-compact-swipe-surface'));
      await tester.drag(surface, const Offset(-220, 0));
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.selectedIndex, 1);
      expect(tester.widget<TextField>(search).controller!.text, '王同学');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact root pages preserve student search across destination changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();

      final search = find.byKey(const Key('v2-student-search'));
      await tester.enterText(search, '王同学');
      await tester.pump();
      expect(find.text('找到 1 位'), findsOneWidget);

      await tester.tap(find.text('学情').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生').last);
      await tester.pumpAndSettle();

      final restoredSearch = find.byKey(const Key('v2-student-search'));
      expect(tester.widget<TextField>(restoredSearch).controller!.text, '王同学');
      expect(find.text('找到 1 位'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

'''
tests = tests.replace(insert_before, state_tests + insert_before, 1)
test_path.write_text(tests, encoding='utf-8')

doc_path = Path('docs/design/ANDROID_SWIPE_NAVIGATION_AUDIT.md')
doc = doc_path.read_text(encoding='utf-8')
doc = doc.replace(
    '- The system gesture edge insets are excluded from page swipe handling so Android Back keeps priority.\n',
    '- The root pager does not install a competing custom edge gesture recognizer; Android system Back keeps platform priority. Edge behavior remains a real-device acceptance gate.\n',
)
doc = doc.replace(
    'Root destination changes use the existing short motion token and a restrained fade / very small horizontal translation. There are no spring, overshoot, glow, gradient, or decorative navigation effects.\n',
    'Root destination swipes use direct manipulation: content tracks the finger through `PageView` and settles with platform paging physics. Bottom-navigation taps jump directly to the selected peer without animating through intermediate destinations. The root pager suppresses only its own overscroll indicator; inner lists keep platform scrolling behavior.\n\n## State continuity\n\nThe Personal root pager stays mounted while Student detail, Case detail, or the embedded Organization workspace is in the foreground. Today / Students / Learning therefore retain their local search and scroll state instead of being rebuilt as a side effect of drill-down navigation. Workspace destination remains the canonical navigation state above the adaptive Compact presentation.\n',
)
doc_path.write_text(doc, encoding='utf-8')
