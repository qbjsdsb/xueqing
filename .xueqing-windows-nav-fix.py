from pathlib import Path
import re

# 1) The first-stage script intentionally touches all adaptive shell calls. Its
# indentation-based replacements can overlap for Compact/Medium because a
# shorter whitespace prefix also matches inside the longer prefix. Collapse
# the two duplicated semantic argument blocks, regardless of their temporary
# indentation, then write them back using the correct call indentation.
preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text(encoding='utf-8')
duplicate_area = re.compile(
    r"(?m)^(?P<area1> +)organizationManagementArea: _organizationManagementArea,\n"
    r"(?P<changed1> +)onOrganizationManagementAreaChanged:\n"
    r"(?P<open1> +)_openOrganizationManagementArea,\n"
    r"(?P<area2> +)organizationManagementArea: _organizationManagementArea,\n"
    r"(?P<changed2> +)onOrganizationManagementAreaChanged:\n"
    r"(?P<open2> +)_openOrganizationManagementArea,\n"
)


def collapse_area(match: re.Match[str]) -> str:
    indent = max(match.group('area1'), match.group('area2'), key=len)
    return (
        f"{indent}organizationManagementArea: _organizationManagementArea,\n"
        f"{indent}onOrganizationManagementAreaChanged:\n"
        f"{indent}    _openOrganizationManagementArea,\n"
    )


preview, duplicate_count = duplicate_area.subn(collapse_area, preview)
if duplicate_count != 2:
    raise SystemExit(
        f'expected two duplicated management-area argument blocks, found {duplicate_count}'
    )
preview_path.write_text(preview, encoding='utf-8')

# 2) The compact/non-compact management body is a ternary. One branch is
# wrapped in SelectionArea and was updated by the first-stage pattern; the
# direct branch still needs the same explicit visibility contract.
organization_path = Path('lib/features/design_v2/v2_organization_workspace_page.dart')
organization = organization_path.read_text(encoding='utf-8')
old_management_call = ': _managementContent(),'
new_management_call = ': _managementContent(showAreaSwitcher: compact),'
if organization.count(old_management_call) != 1:
    raise SystemExit(
        'expected exactly one direct _managementContent() branch without showAreaSwitcher'
    )
organization = organization.replace(old_management_call, new_management_call, 1)
organization_path.write_text(organization, encoding='utf-8')

# 3) The public builder contract now carries the established management area.
# Update test-only builders to accept the two new inferred parameters without
# changing what those fixtures render.
builder_files = [
    Path('test/features/v2_adaptive_workspace_test.dart'),
    Path('test/features/v2_organization_capability_reconciliation_test.dart'),
    Path('test/features/v2_page_rhythm_test.dart'),
    Path('test/features/v2_typed_organization_navigation_test.dart'),
]
old_signature = '(context, onBackToPersonal, section, onSectionChanged)'
new_signature = (
    '(context, onBackToPersonal, section, onSectionChanged, '
    'managementArea, onManagementAreaChanged)'
)
for test_path in builder_files:
    content = test_path.read_text(encoding='utf-8')
    count = content.count(old_signature)
    if count < 1:
        raise SystemExit(f'missing old organization builder signature in {test_path}')
    content = content.replace(old_signature, new_signature)
    test_path.write_text(content, encoding='utf-8')

# 4) Windows rail tooltips are now scope-explicit. Update the existing widget
# tests to assert the new interaction language instead of weakening the UI back
# to ambiguous labels. This replacement is deliberately limited to exact
# byTooltip finders; visible Chinese labels and Compact segmented controls are
# untouched.
student_old = "find.byTooltip('学生')"
student_new = "find.byTooltip('我的学生')"
learning_old = "find.byTooltip('学情监督')"
learning_new = "find.byTooltip('机构学情监督')"
student_updates = 0
learning_updates = 0
for test_path in Path('test').rglob('*.dart'):
    content = test_path.read_text(encoding='utf-8')
    student_updates += content.count(student_old)
    learning_updates += content.count(learning_old)
    content = content.replace(student_old, student_new)
    content = content.replace(learning_old, learning_new)
    test_path.write_text(content, encoding='utf-8')
if student_updates < 1:
    raise SystemExit('expected legacy Personal Student tooltip tests to update')
if learning_updates < 1:
    raise SystemExit('expected legacy Organization Learning tooltip tests to update')

# 5) Desktop no longer has a generic "管理" rail destination. Existing state
# continuity tests should enter the management surface through a real peer
# destination; Members is the least destructive/read-mostly choice. Limit this
# to the typed Organization navigation suite, where these visits are desktop.
typed_path = Path('test/features/v2_typed_organization_navigation_test.dart')
typed = typed_path.read_text(encoding='utf-8')
old_tooltip = "find.byTooltip('管理')"
management_visits = typed.count(old_tooltip)
if management_visits < 1:
    raise SystemExit('expected at least one legacy desktop Management tooltip visit')
typed = typed.replace(old_tooltip, "find.byTooltip('机构成员')")
typed_path.write_text(typed, encoding='utf-8')
