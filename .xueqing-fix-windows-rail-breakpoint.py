from pathlib import Path

path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text()

old = '''                return _DesktopWorkspace(\n                  destination: _destination,'''
new = '''                return _DesktopWorkspace(\n                  expandedRail: constraints.maxWidth >= 1280,\n                  destination: _destination,'''
assert old in text, 'DesktopWorkspace construction anchor not found'
text = text.replace(old, new, 1)

old = '''  const _DesktopWorkspace({\n    required this.destination,'''
new = '''  const _DesktopWorkspace({\n    required this.expandedRail,\n    required this.destination,'''
assert old in text, 'DesktopWorkspace constructor anchor not found'
text = text.replace(old, new, 1)

old = '''  final V2WorkspaceDestination destination;'''
# Target only the field block after _DesktopWorkspace class declaration.
class_anchor = 'class _DesktopWorkspace extends StatelessWidget {'
class_index = text.index(class_anchor)
field_index = text.index(old, class_index)
text = text[:field_index] + '  final bool expandedRail;\n' + text[field_index:]

old = '''    final border = Theme.of(context).colorScheme.outlineVariant;\n    final width = MediaQuery.sizeOf(context).width;\n    final expandedRail = width >= 1280;\n    final studentPaneWidth = expandedRail ? 320.0 : 288.0;'''
new = '''    final border = Theme.of(context).colorScheme.outlineVariant;\n    final studentPaneWidth = expandedRail ? 320.0 : 288.0;'''
assert old in text, 'DesktopWorkspace MediaQuery breakpoint anchor not found'
text = text.replace(old, new, 1)

path.write_text(text)
