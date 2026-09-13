from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)

areas_path = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
layout_path = Path('lib/features/organization_management/presentation/organization_management_layout.dart')
test_path = Path('test/features/management_visual_density_test.dart')
organization_test_path = Path('test/features/organization_management_test.dart')

areas = areas_path.read_text()
areas = replace_once(
    areas,
    """        _ManagementAreaSwitcher(\n          selectedArea: _selectedArea,\n          onChanged: (area) {\n            if (area == _selectedArea) return;\n            setState(() => _selectedArea = area);\n          },\n        ),\n        if (widget.onExportStudentRecords != null ||\n            widget.onExportTeacherRecords != null) ...[\n          const SizedBox(height: AppSpacing.sm),\n          Align(\n            alignment: Alignment.centerRight,\n            child: OutlinedButton.icon(\n              key: const Key('management-export-records'),\n              onPressed: widget.busy ? null : _showExportRecords,\n              icon: const Icon(Icons.download_outlined, size: 18),\n              label: const Text('导出记录'),\n            ),\n          ),\n        ],\n        const SizedBox(height: AppSpacing.lg),\n""",
    """        _ManagementToolbar(\n          selectedArea: _selectedArea,\n          onChanged: (area) {\n            if (area == _selectedArea) return;\n            setState(() => _selectedArea = area);\n          },\n          busy: widget.busy,\n          onExport:\n              widget.onExportStudentRecords != null ||\n                  widget.onExportTeacherRecords != null\n              ? _showExportRecords\n              : null,\n        ),\n        const SizedBox(height: AppSpacing.lg),\n""",
    'replace area switcher/export block',
)

areas = replace_once(
    areas,
    """    return _ManagementAreaCard(\n      icon: Icons.people_outline,\n      title: '成员',\n      description: widget.isOwner\n          ? '管理机构成员、账号状态和老师可教学科。邮箱只用于登录，日常协作优先显示姓名。'\n          : '查看机构成员并管理老师可教学科；邀请、停用和账号凭据由负责人处理。',\n      child: Column(\n""",
    """    return _ManagementAreaCard(\n      child: Column(\n""",
    'quiet people area intro',
)

areas = replace_once(
    areas,
    """    return _ManagementAreaCard(\n      icon: Icons.school_outlined,\n      title: '学生',\n      description: '学生、学科和当前负责老师都在这里处理；历史任课按需查看。',\n      child: Column(\n""",
    """    return _ManagementAreaCard(\n      child: Column(\n""",
    'quiet students area intro',
)

areas = replace_once(
    areas,
    """    return _ManagementAreaCard(\n      icon: Icons.tune_outlined,\n      title: '基础设置',\n      description: '新增机构学科、维护问题类型和其他必要配置都在这里处理。',\n      child: Column(\n""",
    """    return _ManagementAreaCard(\n      child: Column(\n""",
    'quiet settings area intro',
)
areas_path.write_text(areas)

layout = layout_path.read_text()
area_card_start = layout.index('class _ManagementAreaCard extends StatelessWidget {')
section_start = layout.index('class _ManagementSection extends StatelessWidget {')
old_area_card = layout[area_card_start:section_start]
new_area_card = """class _ManagementAreaCard extends StatelessWidget {\n  const _ManagementAreaCard({required this.child});\n\n  final Widget child;\n\n  @override\n  Widget build(BuildContext context) => child;\n}\n\n"""
layout = layout[:area_card_start] + new_area_card + layout[section_start:]

switcher_marker = 'class _ManagementAreaSwitcher extends StatelessWidget {'
toolbar = """class _ManagementToolbar extends StatelessWidget {\n  const _ManagementToolbar({\n    required this.selectedArea,\n    required this.onChanged,\n    required this.busy,\n    this.onExport,\n  });\n\n  final _ManagementArea selectedArea;\n  final ValueChanged<_ManagementArea> onChanged;\n  final bool busy;\n  final VoidCallback? onExport;\n\n  @override\n  Widget build(BuildContext context) {\n    return LayoutBuilder(\n      builder: (context, constraints) {\n        final switcher = _ManagementAreaSwitcher(\n          selectedArea: selectedArea,\n          onChanged: onChanged,\n        );\n        if (onExport == null) return switcher;\n\n        final Widget exportAction = constraints.maxWidth < 520\n            ? IconButton(\n                key: const Key('management-export-records'),\n                tooltip: '导出记录',\n                onPressed: busy ? null : onExport,\n                icon: const Icon(Icons.download_outlined),\n              )\n            : TextButton.icon(\n                key: const Key('management-export-records'),\n                onPressed: busy ? null : onExport,\n                icon: const Icon(Icons.download_outlined, size: 18),\n                label: const Text('导出记录'),\n              );\n\n        return Row(\n          crossAxisAlignment: CrossAxisAlignment.center,\n          children: [\n            Expanded(child: switcher),\n            const SizedBox(width: AppSpacing.sm),\n            exportAction,\n          ],\n        );\n      },\n    );\n  }\n}\n\n"""
if toolbar in layout:
    raise SystemExit('toolbar already present')
layout = replace_once(layout, switcher_marker, toolbar + switcher_marker, 'insert management toolbar')
layout_path.write_text(layout)

test = test_path.read_text()
test = replace_once(
    test,
    """    final rows = File(\n      'lib/features/organization_management/presentation/'\n      'organization_management_rows.dart',\n    ).readAsStringSync();\n""",
    """    final rows = File(\n      'lib/features/organization_management/presentation/'\n      'organization_management_rows.dart',\n    ).readAsStringSync();\n    final layout = File(\n      'lib/features/organization_management/presentation/'\n      'organization_management_layout.dart',\n    ).readAsStringSync();\n""",
    'load management layout in density contract',
)
needle = """    expect(statusBlock, contains('AppRadii.small'));\n  });\n}\n"""
replacement = """    expect(statusBlock, contains('AppRadii.small'));\n\n    final areaCardStart = layout.indexOf('class _ManagementAreaCard');\n    final sectionStart = layout.indexOf('class _ManagementSection');\n    expect(areaCardStart, greaterThanOrEqualTo(0));\n    expect(sectionStart, greaterThan(areaCardStart));\n    final areaCardBlock = layout.substring(areaCardStart, sectionStart);\n    expect(areaCardBlock, contains('Widget build(BuildContext context) => child;'));\n    expect(areaCardBlock, isNot(contains('Divider(')));\n    expect(areaCardBlock, isNot(contains('description')));\n\n    expect(layout, contains('class _ManagementToolbar'));\n    expect(layout, contains("tooltip: '导出记录'"));\n    expect(layout, contains("label: const Text('导出记录')"));\n  });\n}\n"""
test = replace_once(test, needle, replacement, 'extend density contract')
test_path.write_text(test)

organization_test = organization_test_path.read_text()
organization_test = replace_once(
    organization_test,
    "    expect(find.text('基础设置'), findsOneWidget);\n",
    "    expect(find.text('机构学科'), findsOneWidget);\n",
    'update settings-first behavior contract',
)
organization_test_path.write_text(organization_test)
