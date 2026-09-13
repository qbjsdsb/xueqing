from pathlib import Path

workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
workspace = workspace_path.read_text()

anchor = "const int _studentFocusPreviewLimit = 3;"
replacement = """const List<V2WorkspaceDestination> _compactPrimaryDestinations =
    <V2WorkspaceDestination>[
      V2WorkspaceDestination.today,
      V2WorkspaceDestination.students,
      V2WorkspaceDestination.learning,
    ];

const int _studentFocusPreviewLimit = 3;"""
if anchor not in workspace:
    raise SystemExit('compact destination anchor not found')
workspace = workspace.replace(anchor, replacement, 1)

start = workspace.index('class _CompactWorkspaceState extends State<_CompactWorkspace> {')
end = workspace.index('class _NavigationRail extends StatelessWidget {', start)
new_class = r'''class _CompactWorkspaceState extends State<_CompactWorkspace> {
  static const double _edgeSafetyInset = 8;
  static const double _minimumFlingDistance = 24;
  static const double _minimumFlingVelocity = 700;

  bool _horizontalDragEnabled = false;
  double _horizontalDragDistance = 0;
  int _transitionDirection = 0;

  @override
  void didUpdateWidget(covariant _CompactWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIndex = _compactPrimaryDestinations.indexOf(oldWidget.destination);
    final newIndex = _compactPrimaryDestinations.indexOf(widget.destination);
    if (oldIndex >= 0 && newIndex >= 0 && oldIndex != newIndex) {
      _transitionDirection = newIndex > oldIndex ? 1 : -1;
    }
  }

  void _resetHorizontalDrag() {
    _horizontalDragEnabled = false;
    _horizontalDragDistance = 0;
  }

  void _handleHorizontalDragDown(DragDownDetails details) {
    final media = MediaQuery.of(context);
    final gestureInsets = media.systemGestureInsets;
    final x = details.localPosition.dx;
    final leftGuard = gestureInsets.left + _edgeSafetyInset;
    final rightGuard = media.size.width - gestureInsets.right - _edgeSafetyInset;

    _horizontalDragDistance = 0;
    _horizontalDragEnabled =
        media.viewInsets.bottom <= 0 && x > leftGuard && x < rightGuard;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_horizontalDragEnabled) return;
    _horizontalDragDistance += details.delta.dx;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!_horizontalDragEnabled) {
      _resetHorizontalDrag();
      return;
    }

    final distance = _horizontalDragDistance;
    final velocity = details.primaryVelocity ?? 0;
    final width = MediaQuery.sizeOf(context).width;
    final distanceThreshold = (width * 0.16).clamp(52.0, 72.0).toDouble();
    final commitsByDistance = distance.abs() >= distanceThreshold;
    final commitsByFling =
        distance.abs() >= _minimumFlingDistance &&
        velocity.abs() >= _minimumFlingVelocity &&
        (velocity == 0 || distance == 0 || velocity.sign == distance.sign);

    _resetHorizontalDrag();
    if (!commitsByDistance && !commitsByFling) return;

    final motion = commitsByDistance ? distance : velocity;
    _moveToAdjacentDestination(motion < 0 ? 1 : -1);
  }

  void _moveToAdjacentDestination(int step) {
    final currentIndex = _compactPrimaryDestinations.indexOf(widget.destination);
    if (currentIndex < 0) return;
    final nextIndex = currentIndex + step;
    if (nextIndex < 0 || nextIndex >= _compactPrimaryDestinations.length) {
      return;
    }
    widget.onDestinationChanged(_compactPrimaryDestinations[nextIndex]);
  }

  Widget _buildSwipeSurface(BuildContext context, Widget body) {
    final currentKey = ValueKey<String>(
      'v2-compact-primary-${widget.destination.name}',
    );
    return GestureDetector(
      key: const Key('v2-compact-swipe-surface'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragDown: _handleHorizontalDragDown,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onHorizontalDragCancel: _resetHorizontalDrag,
      child: AnimatedSwitcher(
        duration: AppMotion.effectiveDuration(context, AppMotion.quick),
        reverseDuration: AppMotion.effectiveDuration(context, AppMotion.quick),
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.enter,
            reverseCurve: AppMotion.exit,
          );
          final incoming = child.key == currentKey;
          final horizontalOffset = _transitionDirection == 0
              ? 0.0
              : _transitionDirection * (incoming ? 0.018 : -0.012);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(horizontalOffset, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: currentKey, child: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (widget.destination == V2WorkspaceDestination.students &&
        widget.showCase &&
        widget.selectedCase != null) {
      body = _CaseDetailPane(
        student: widget.selectedStudent,
        item: widget.selectedCase!,
        onBack: widget.onBackFromCase,
        compact: true,
      );
    } else if (widget.destination == V2WorkspaceDestination.students &&
        widget.showStudentDetail) {
      body = _StudentDetailPane(
        student: widget.selectedStudent,
        onOpenCase: widget.onOpenCase,
        compact: true,
        onBack: widget.onBackFromStudent,
      );
    } else if (widget.destination == V2WorkspaceDestination.students) {
      body = _StudentListPane(
        selectedStudent: widget.selectedStudent,
        compact: true,
        onOpenMore: widget.onOpenMore,
        onSelected: widget.onStudentSelected,
      );
    } else if (widget.destination == V2WorkspaceDestination.today) {
      body = _TodayPane(
        onOpenCase: widget.onOpenCase,
        onOpenStudent: (student) {
          widget.onStudentSelected(student);
          widget.onDestinationChanged(V2WorkspaceDestination.students);
        },
        compact: true,
        onOpenMore: widget.onOpenMore,
      );
    } else if (widget.destination == V2WorkspaceDestination.learning) {
      body = _CaseIndexPane(
        onOpenCase: widget.onOpenCase,
        compact: true,
        onOpenMore: widget.onOpenMore,
      );
    } else {
      body = widget.organizationPageBuilder!(
        context,
        widget.onBackFromOrganization,
        widget.organizationSection,
        widget.onOrganizationSectionChanged,
      );
    }

    final hasInternalHistory =
        widget.destination == V2WorkspaceDestination.students &&
        (widget.showCase || widget.showStudentDetail);
    final handlesSystemBack =
        hasInternalHistory ||
        (widget.destination != V2WorkspaceDestination.today &&
            widget.destination != V2WorkspaceDestination.organization);
    final supportsPrimarySwipe =
        Theme.of(context).platform == TargetPlatform.android &&
        !hasInternalHistory &&
        _compactPrimaryDestinations.contains(widget.destination);
    final visibleBody = supportsPrimarySwipe
        ? _buildSwipeSurface(context, body)
        : body;

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
        body: SafeArea(child: visibleBody),
        bottomNavigationBar:
            hasInternalHistory ||
                widget.destination == V2WorkspaceDestination.organization
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  NavigationBar(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    selectedIndex: _compactPrimaryDestinations.indexOf(
                      widget.destination,
                    ),
                    onDestinationSelected: (index) {
                      widget.onDestinationChanged(
                        _compactPrimaryDestinations[index],
                      );
                    },
                    destinations: [
                      for (final destination in _compactPrimaryDestinations)
                        _compactNavigationDestination(destination),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}'''
workspace = workspace[:start] + new_class + '\n\n' + workspace[end:]
workspace_path.write_text(workspace)

# Add Android-only swipe behavior tests without changing the existing desktop/mobile contracts.
test_path = Path('test/features/design_v2_workspace_test.dart')
test = test_path.read_text()
helper_anchor = """  Widget app() =>
      MaterialApp(theme: V2Theme.light(), home: const V2WorkspacePreview());
"""
helper_replacement = """  Widget app() =>
      MaterialApp(theme: V2Theme.light(), home: const V2WorkspacePreview());

  Widget androidApp({
    EdgeInsets systemGestureInsets = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) => MaterialApp(
    theme: V2Theme.light().copyWith(platform: TargetPlatform.android),
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          systemGestureInsets: systemGestureInsets,
          viewInsets: viewInsets,
        ),
        child: child!,
      );
    },
    home: const V2WorkspacePreview(),
  );
"""
if helper_anchor not in test:
    raise SystemExit('workspace test helper anchor not found')
test = test.replace(helper_anchor, helper_replacement, 1)

insert_anchor = """  testWidgets('student search filters real people without changing identity', (
"""
new_tests = r'''  testWidgets(
    'Android compact root swipes one step between Today Students and Learning',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();

      NavigationBar navigation() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      Finder swipeSurface() =>
          find.byKey(const Key('v2-compact-swipe-surface'));

      expect(swipeSurface(), findsOneWidget);
      expect(navigation().selectedIndex, 0);

      // No circular wrap before Today.
      await tester.drag(swipeSurface(), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 0);

      await tester.drag(swipeSurface(), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 1);

      await tester.drag(swipeSurface(), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 2);

      // No circular wrap after Learning.
      await tester.drag(swipeSurface(), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 2);

      await tester.drag(swipeSurface(), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 1);

      await tester.drag(swipeSurface(), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact page swipe leaves system gesture edges to Back',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        androidApp(
          systemGestureInsets: const EdgeInsets.symmetric(horizontal: 24),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();

      NavigationBar navigation() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation().selectedIndex, 1);

      final leftEdge = await tester.startGesture(const Offset(4, 300));
      await leftEdge.moveBy(const Offset(190, 0));
      await leftEdge.up();
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 1);

      final rightEdge = await tester.startGesture(const Offset(386, 300));
      await rightEdge.moveBy(const Offset(-190, 0));
      await rightEdge.up();
      await tester.pumpAndSettle();
      expect(navigation().selectedIndex, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android compact page swipe yields while the keyboard is visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        androidApp(viewInsets: const EdgeInsets.only(bottom: 280)),
      );
      await tester.pumpAndSettle();

      final surface = find.byKey(const Key('v2-compact-swipe-surface'));
      expect(surface, findsOneWidget);
      await tester.drag(surface, const Offset(-220, 0));
      await tester.pumpAndSettle();

      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigation.selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android page swipe is disabled for student detail and medium layout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('林同学'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('v2-compact-swipe-surface')),
        findsNothing,
      );
      expect(find.byType(NavigationBar), findsNothing);

      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(
        find.byKey(const Key('v2-compact-swipe-surface')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

'''
if insert_anchor not in test:
    raise SystemExit('workspace test insertion anchor not found')
test = test.replace(insert_anchor, new_tests + insert_anchor, 1)
test_path.write_text(test)
