from pathlib import Path

path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text()
old = """          builder: (context) {
            if (widget.data.students.isEmpty) {
              final hasMenuActions =
                  widget.managementPageBuilder != null ||
                  widget.updateService != null &&
                      widget.updateInstaller != null ||
                  widget.onSignOut != null;
              return _EmptyWorkspacePreview(
"""
new = """          builder: (context) {
            final hasMenuActions =
                widget.managementPageBuilder != null ||
                widget.updateService != null && widget.updateInstaller != null ||
                widget.onSignOut != null;
            if (widget.data.students.isEmpty) {
              return _EmptyWorkspacePreview(
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one hasMenuActions block, found {count}')
path.write_text(text.replace(old, new, 1))
print('V2 final ergonomics follow-up applied')
