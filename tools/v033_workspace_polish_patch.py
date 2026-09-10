from pathlib import Path

WORKSPACE = Path('lib/features/design_v2/v2_workspace_preview.dart')
TEST = Path('test/features/design_v2_workspace_test.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


source = WORKSPACE.read_text(encoding='utf-8')
test_source = TEST.read_text(encoding='utf-8')

if "../../app/layout/responsive.dart" not in source:
    source = replace_once(
        source,
        "import '../../app/theme/app_motion.dart';\n",
        "import '../../app/layout/responsive.dart';\nimport '../../app/theme/app_motion.dart';\n",
        'responsive import',
    )

old_layout = '''            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return _CompactWorkspace(
                    destination: _destination,
                    selectedStudent: selectedStudent,
                    selectedCase: _selectedCase,
                    showCase: _showCase,
                    onDestinationChanged: _changeDestination,
                    onStudentSelected: _openStudent,
                    onOpenCase: _openCase,
                    onBackFromCase: _closeCase,
                    onOpenMore: () => _showWorkspaceMenu(context),
                  );
                }
                return _DesktopWorkspace(
                  destination: _destination,
                  selectedStudent: selectedStudent,
                  selectedCase: _selectedCase,
                  showCase: _showCase,
                  onDestinationChanged: _changeDestination,
                  onStudentSelected: _openStudent,
                  onOpenCase: _openCase,
                  onBackFromCase: _closeCase,
                  onRefresh: widget.onRefresh == null
                      ? null
                      : () => _refreshWorkspace(),
                  refreshing: _refreshing,
                  onManage: widget.managementPageBuilder == null
                      ? null
                      : () => _openManagement(context),
                  onSettings: () => _showWorkspaceMenu(context),
                );
              },
            );'''
new_layout = '''            return LayoutBuilder(
              builder: (context, constraints) {
                final sizeClass = ResponsiveBreakpoints.classify(
                  constraints.maxWidth,
                );
                if (sizeClass == WindowSizeClass.compact) {
                  return _CompactWorkspace(
                    destination: _destination,
                    selectedStudent: selectedStudent,
                    selectedCase: _selectedCase,
                    showCase: _showCase,
                    onDestinationChanged: _changeDestination,
                    onStudentSelected: _openStudent,
                    onOpenCase: _openCase,
                    onBackFromCase: _closeCase,
                    onOpenMore: () => _showWorkspaceMenu(context),
                  );
                }
                if (sizeClass == WindowSizeClass.medium) {
                  return _MediumWorkspace(
                    destination: _destination,
                    selectedStudent: selectedStudent,
                    selectedCase: _selectedCase,
                    showCase: _showCase,
                    onDestinationChanged: _changeDestination,
                    onStudentSelected: _openStudent,
                    onOpenCase: _openCase,
                    onBackFromCase: _closeCase,
                    onRefresh: widget.onRefresh == null
                        ? null
                        : () => _refreshWorkspace(),
                    refreshing: _refreshing,
                    onManage: widget.managementPageBuilder == null
                        ? null
                        : () => _openManagement(context),
                    onSettings: () => _showWorkspaceMenu(context),
                  );
                }
                return _DesktopWorkspace(
                  destination: _destination,
                  selectedStudent: selectedStudent,
                  selectedCase: _selectedCase,
                  showCase: _showCase,
                  onDestinationChanged: _changeDestination,
                  onStudentSelected: _openStudent,
                  onOpenCase: _openCase,
                  onBackFromCase: _closeCase,
                  onRefresh: widget.onRefresh == null
                      ? null
                      : () => _refreshWorkspace(),
                  refreshing: _refreshing,
                  onManage: widget.managementPageBuilder == null
                      ? null
                      : () => _openManagement(context),
                  onSettings: () => _showWorkspaceMenu(context),
                );
              },
            );'''
if old_layout in source:
    source = replace_once(source, old_layout, new_layout, 'three-size workspace shell')
elif 'final sizeClass = ResponsiveBreakpoints.classify(' not in source:
    raise SystemExit('three-size workspace shell: neither baseline nor patched form found')

old_desktop_rail = '''            SizedBox(
              width: 72,
              child: _NavigationRail(
                selectedIndex: destination,
                onSelected: onDestinationChanged,
                onRefresh: onRefresh,
                refreshing: refreshing,
                onManage: onManage,
                onSettings: onSettings,
              ),
            ),'''
new_desktop_rail = '''            SizedBox(
              key: const Key('v2-expanded-rail'),
              width: 176,
              child: _NavigationRail(
                selectedIndex: destination,
                onSelected: onDestinationChanged,
                onRefresh: onRefresh,
                refreshing: refreshing,
                onManage: onManage,
                onSettings: onSettings,
                extended: true,
              ),
            ),'''
if old_desktop_rail in source:
    source = replace_once(source, old_desktop_rail, new_desktop_rail, 'expanded rail')
elif "Key('v2-expanded-rail')" not in source:
    raise SystemExit('expanded rail: neither baseline nor patched form found')

medium_class = '''
class _MediumWorkspace extends StatefulWidget {
  const _MediumWorkspace({
    required this.destination,
    required this.selectedStudent,
    required this.selectedCase,
    required this.showCase,
    required this.onDestinationChanged,
    required this.onStudentSelected,
    required this.onOpenCase,
    required this.onBackFromCase,
    required this.onSettings,
    required this.refreshing,
    this.onRefresh,
    this.onManage,
  });

  final int destination;
  final V2Student selectedStudent;
  final V2FocusItem? selectedCase;
  final bool showCase;
  final ValueChanged<int> onDestinationChanged;
  final ValueChanged<V2Student> onStudentSelected;
  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final VoidCallback? onManage;
  final VoidCallback onSettings;

  @override
  State<_MediumWorkspace> createState() => _MediumWorkspaceState();
}

class _MediumWorkspaceState extends State<_MediumWorkspace> {
  bool _studentOpen = false;

  void _backFromCase() {
    setState(() => _studentOpen = true);
    widget.onBackFromCase();
  }

  void _changeDestination(int value) {
    setState(() => _studentOpen = false);
    widget.onDestinationChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (widget.showCase && widget.selectedCase != null) {
      body = _CaseDetailPane(
        student: widget.selectedStudent,
        item: widget.selectedCase!,
        onBack: _backFromCase,
      );
    } else if (widget.destination == 1 && _studentOpen) {
      body = _StudentDetailPane(
        student: widget.selectedStudent,
        onOpenCase: widget.onOpenCase,
        onBack: () => setState(() => _studentOpen = false),
      );
    } else if (widget.destination == 1) {
      body = _StudentListPane(
        selectedStudent: widget.selectedStudent,
        onSelected: (student) {
          widget.onStudentSelected(student);
          setState(() => _studentOpen = true);
        },
      );
    } else if (widget.destination == 0) {
      body = _TodayPane(onOpenCase: widget.onOpenCase);
    } else {
      body = _CaseIndexPane(onOpenCase: widget.onOpenCase);
    }

    final hasInternalHistory = widget.showCase || _studentOpen;
    final handlesSystemBack = hasInternalHistory || widget.destination != 0;
    return PopScope<void>(
      canPop: !handlesSystemBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.showCase) {
          _backFromCase();
          return;
        }
        if (_studentOpen) {
          setState(() => _studentOpen = false);
          return;
        }
        if (widget.destination != 0) {
          _changeDestination(0);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              SizedBox(
                key: const Key('v2-medium-rail'),
                width: 72,
                child: _NavigationRail(
                  selectedIndex: widget.destination,
                  onSelected: _changeDestination,
                  onRefresh: widget.onRefresh,
                  refreshing: widget.refreshing,
                  onManage: widget.onManage,
                  onSettings: widget.onSettings,
                ),
              ),
              VerticalDivider(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: _QuietPaneTransition(
                  transitionKey: widget.showCase && widget.selectedCase != null
                      ? 'medium-case-${widget.selectedCase!.id}'
                      : widget.destination == 1 && _studentOpen
                      ? 'medium-student-${widget.selectedStudent.id}'
                      : 'medium-destination-${widget.destination}',
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

'''
compact_marker = 'class _CompactWorkspace extends StatefulWidget {'
if 'class _MediumWorkspace extends StatefulWidget' not in source:
    if compact_marker not in source:
        raise SystemExit('medium workspace insertion point missing')
    source = source.replace(compact_marker, medium_class + compact_marker, 1)

old_compact_case = '''      body = _CaseDetailPane(
        student: widget.selectedStudent,
        item: widget.selectedCase!,
        onBack: widget.onBackFromCase,
        compact: true,
      );'''
new_compact_case = '''      body = _CaseDetailPane(
        student: widget.selectedStudent,
        item: widget.selectedCase!,
        onBack: _backFromCase,
        compact: true,
      );'''
if old_compact_case in source:
    source = replace_once(source, old_compact_case, new_compact_case, 'compact case back target')

old_compact_state = '''class _CompactWorkspaceState extends State<_CompactWorkspace> {
  bool _studentOpen = false;

  @override'''
new_compact_state = '''class _CompactWorkspaceState extends State<_CompactWorkspace> {
  bool _studentOpen = false;

  void _backFromCase() {
    setState(() => _studentOpen = true);
    widget.onBackFromCase();
  }

  @override'''
if old_compact_state in source:
    source = replace_once(source, old_compact_state, new_compact_state, 'compact case back helper')
elif 'class _CompactWorkspaceState' in source and 'void _backFromCase()' not in source[source.index('class _CompactWorkspaceState'):source.index('class _NavigationRail')]:
    raise SystemExit('compact case back helper missing')

old_compact_pop = '''        if (widget.showCase) {
          widget.onBackFromCase();
          return;
        }'''
new_compact_pop = '''        if (widget.showCase) {
          _backFromCase();
          return;
        }'''
# There is one compact occurrence after medium has its own already-patched branch.
if old_compact_pop in source:
    source = replace_once(source, old_compact_pop, new_compact_pop, 'compact system case back')

old_navigation_ctor = '''class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
    required this.refreshing,
    this.onRefresh,
    this.onManage,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final VoidCallback? onManage;
  final VoidCallback onSettings;'''
new_navigation_ctor = '''class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
    required this.refreshing,
    this.onRefresh,
    this.onManage,
    this.extended = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final VoidCallback? onManage;
  final VoidCallback onSettings;
  final bool extended;'''
if old_navigation_ctor in source:
    source = replace_once(source, old_navigation_ctor, new_navigation_ctor, 'navigation rail extended flag')
elif 'final bool extended;' not in source:
    raise SystemExit('navigation rail extended flag missing')

old_rail_items = '''          for (final item in const [
            (Icons.today_outlined, '今日'),
            (Icons.people_outline, '学生'),
            (Icons.fact_check_outlined, '学情'),
          ].indexed)
            _RailItem(
              icon: item.$2.$1,
              tooltip: item.$2.$2,
              selected: selectedIndex == item.$1,
              onTap: () => onSelected(item.$1),
            ),
          const Spacer(),
          if (onRefresh != null)
            _RailItem(
              key: const Key('v2-workspace-refresh'),
              icon: Icons.refresh_outlined,
              tooltip: refreshing ? '正在刷新' : '刷新学情',
              onTap: refreshing ? null : onRefresh,
            ),
          if (onManage != null)
            _RailItem(
              icon: Icons.admin_panel_settings_outlined,
              tooltip: '管理',
              onTap: onManage,
            ),
          _RailItem(
            icon: Icons.settings_outlined,
            tooltip: '设置',
            onTap: onSettings,
          ),'''
new_rail_items = '''          for (final item in const [
            (Icons.today_outlined, '今日'),
            (Icons.people_outline, '学生'),
            (Icons.fact_check_outlined, '学情'),
          ].indexed)
            _RailItem(
              icon: item.$2.$1,
              label: item.$2.$2,
              tooltip: item.$2.$2,
              extended: extended,
              selected: selectedIndex == item.$1,
              onTap: () => onSelected(item.$1),
            ),
          const Spacer(),
          if (onRefresh != null)
            _RailItem(
              key: const Key('v2-workspace-refresh'),
              icon: Icons.refresh_outlined,
              label: refreshing ? '正在刷新' : '刷新学情',
              tooltip: refreshing ? '正在刷新' : '刷新学情',
              extended: extended,
              onTap: refreshing ? null : onRefresh,
            ),
          if (onManage != null)
            _RailItem(
              icon: Icons.admin_panel_settings_outlined,
              label: '机构管理',
              tooltip: '管理',
              extended: extended,
              onTap: onManage,
            ),
          _RailItem(
            icon: Icons.settings_outlined,
            label: '更多',
            tooltip: '设置',
            extended: extended,
            onTap: onSettings,
          ),'''
if old_rail_items in source:
    source = replace_once(source, old_rail_items, new_rail_items, 'visible rail labels')
elif "label: '机构管理'" not in source:
    raise SystemExit('visible rail labels missing')

old_rail_class = '''class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.icon,
    required this.tooltip,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: AppMotion.effectiveDuration(context, AppMotion.quick),
          curve: AppMotion.enter,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}'''
new_rail_class = '''class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.extended,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool extended;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 3,
        horizontal: extended ? 10 : 10,
      ),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: AppMotion.effectiveDuration(context, AppMotion.quick),
          curve: AppMotion.enter,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: onTap,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: extended
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(icon, size: 20, color: iconColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: iconColor,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(child: Icon(icon, size: 20, color: iconColor)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}'''
if old_rail_class in source:
    source = replace_once(source, old_rail_class, new_rail_class, 'extended rail item')
elif 'required this.extended,' not in source[source.index('class _RailItem'):source.index('class _StudentListPane')]:
    raise SystemExit('extended rail item missing')

old_timeline = '''  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attachmentRepository = _V2RuntimeScope.maybeOf(context)
        ?.evidenceAttachmentRepository;
    final canResolveRealPhotos =
        resolveEvidencePhotos &&
        entry.evidenceId != null &&
        attachmentRepository != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              entry.date,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  color: entry.kind == '新表现' ? scheme.primary : scheme.outline,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Container(
                  width: 1,
                  height: entry.photoCount > 0 || canResolveRealPhotos
                      ? 144
                      : 96,
                  color: scheme.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.kind,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(entry.body, style: Theme.of(context).textTheme.bodyMedium),
                if (canResolveRealPhotos) ...[
                  const SizedBox(height: 12),
                  _EvidencePhotoStrip(
                    evidenceId: entry.evidenceId!,
                    repository: attachmentRepository,
                  ),
                ] else if (entry.photoCount > 0) ...[
                  const SizedBox(height: 12),
                  _PhotoStrip(count: entry.photoCount),
                ],
                const SizedBox(height: 9),
                Text(
                  entry.teacher.trim().isEmpty
                      ? entry.time
                      : '${entry.teacher} · ${entry.time}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }'''
new_timeline = '''  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attachmentRepository = _V2RuntimeScope.maybeOf(context)
        ?.evidenceAttachmentRepository;
    final canResolveRealPhotos =
        resolveEvidencePhotos &&
        entry.evidenceId != null &&
        attachmentRepository != null;
    final attribution = entry.teacher.trim().isEmpty
        ? entry.time
        : '${entry.teacher} · ${entry.time}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactTimeline = constraints.maxWidth < 560;
        final metadata = compactTimeline
            ? [
                entry.date,
                attribution,
              ].where((value) => value.trim().isNotEmpty).join(' · ')
            : attribution;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compactTimeline)
                SizedBox(
                  width: 74,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      entry.date,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              SizedBox(
                width: 24,
                child: Stack(
                  children: [
                    if (!last)
                      Positioned(
                        top: 11,
                        bottom: 0,
                        left: 11.5,
                        child: SizedBox(
                          width: 1,
                          child: ColoredBox(color: scheme.outlineVariant),
                        ),
                      ),
                    Positioned(
                      top: 7,
                      left: 8.5,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: entry.kind == '新表现'
                              ? scheme.primary
                              : scheme.outline,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compactTimeline ? 6 : 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.kind,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entry.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (canResolveRealPhotos) ...[
                        const SizedBox(height: 12),
                        _EvidencePhotoStrip(
                          evidenceId: entry.evidenceId!,
                          repository: attachmentRepository,
                        ),
                      ] else if (entry.photoCount > 0) ...[
                        const SizedBox(height: 12),
                        _PhotoStrip(count: entry.photoCount),
                      ],
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Text(
                          metadata,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }'''
if old_timeline in source:
    source = replace_once(source, old_timeline, new_timeline, 'adaptive timeline')
elif 'final compactTimeline = constraints.maxWidth < 560;' not in source:
    raise SystemExit('adaptive timeline missing')

old_urls = '''  Future<List<String>> _loadSignedUrls() async {
    final attachments = await widget.repository.listForEvidence(
      widget.evidenceId,
    );
    final result = <String>[];
    for (final attachment in attachments.take(3)) {
      result.add(
        await widget.repository.createSignedUrl(attachment.storagePath),
      );
    }
    return List<String>.unmodifiable(result);
  }'''
new_urls = '''  Future<List<String>> _loadSignedUrls() async {
    final attachments = await widget.repository.listForEvidence(
      widget.evidenceId,
    );
    final urls = await Future.wait(
      attachments
          .take(3)
          .map(
            (attachment) =>
                widget.repository.createSignedUrl(attachment.storagePath),
          ),
    );
    return List<String>.unmodifiable(urls);
  }

  void _retry() {
    setState(() => _signedUrls = _loadSignedUrls());
  }'''
if old_urls in source:
    source = replace_once(source, old_urls, new_urls, 'parallel signed URLs')
elif 'final urls = await Future.wait(' not in source:
    raise SystemExit('parallel signed URLs missing')

old_photo_error = '''        if (snapshot.hasError) {
          return Text(
            '图片暂时无法加载',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          );
        }'''
new_photo_error = '''        if (snapshot.hasError) {
          return Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '图片暂时无法加载',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              TextButton(
                key: ValueKey<String>(
                  'v2-evidence-photos-retry-${widget.evidenceId}',
                ),
                onPressed: _retry,
                child: const Text('重试'),
              ),
            ],
          );
        }'''
if old_photo_error in source:
    source = replace_once(source, old_photo_error, new_photo_error, 'photo retry')
elif 'v2-evidence-photos-retry-' not in source:
    raise SystemExit('photo retry missing')

# Add responsive regression coverage without replacing the existing v0.3.2 tests.
if "medium width uses a rail with stacked student navigation" not in test_source:
    insert = '''

  testWidgets('compact boundary below 600 keeps bottom navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(599, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('v2-medium-rail')), findsNothing);
    expect(find.byKey(const Key('v2-expanded-rail')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium width uses a rail with stacked student navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('v2-medium-rail')), findsOneWidget);
    expect(find.text('最近成长'), findsNothing);

    await tester.tap(find.text('林同学'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-medium-rail')), findsOneWidget);
    expect(find.text('最近成长'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('最近成长'), findsNothing);
    expect(find.byKey(const Key('v2-medium-rail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded width keeps master-detail and visible rail labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('v2-expanded-rail')), findsOneWidget);
    expect(find.text('最近成长'), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact Case back returns to the selected student detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    navigation.onDestinationSelected(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('王同学 · 英语'));
    await tester.pumpAndSettle();

    expect(find.text('成长过程'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('最近成长'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
'''
    if not test_source.rstrip().endswith('}'):
        raise SystemExit('test file final brace missing')
    stripped = test_source.rstrip()
    test_source = stripped[:-1] + insert + '}\n'

WORKSPACE.write_text(source, encoding='utf-8')
TEST.write_text(test_source, encoding='utf-8')
print('v0.3.3 workspace polish patch applied or already present')
