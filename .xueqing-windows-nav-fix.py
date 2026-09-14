from pathlib import Path
import re

# 1) The first-stage script intentionally touches all adaptive shell calls. Its
# indentation-based replacements can overlap for Compact/Medium because a
# shorter whitespace prefix also matches inside the longer prefix. Collapse
# only the exact duplicated management-area argument blocks produced there.
preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text(encoding='utf-8')
duplicate_area = re.compile(
    r"(?m)^(?P<indent> +)organizationManagementArea: _organizationManagementArea,\n"
    r"(?P=indent)onOrganizationManagementAreaChanged:\n"
    r"(?P<callback1> +)_openOrganizationManagementArea,\n"
    r"(?P=indent)organizationManagementArea: _organizationManagementArea,\n"
    r"(?P=indent)onOrganizationManagementAreaChanged:\n"
    r"(?P<callback2> +)_openOrganizationManagementArea,\n"
)

def collapse_area(match: re.Match[str]) -> str:
    indent = match.group('indent')
    callback = match.group('callback1')
    return (
        f"{indent}organizationManagementArea: _organizationManagementArea,\n"
        f"{indent}onOrganizationManagementAreaChanged:\n"
        f"{callback}_openOrganizationManagementArea,\n"
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

# 4) Desktop no longer has a generic "管理" rail destination. Existing state
# continuity tests should enter the management surface through a real peer
# destination; Members is the least destructive/read-mostly choice.
typed_path = Path('test/features/v2_typed_organization_navigation_test.dart')
typed = typed_path.read_text(encoding='utf-8')
old_tooltip = "find.byTooltip('管理')"
management_visits = typed.count(old_tooltip)
if management_visits < 1:
    raise SystemExit('expected at least one legacy desktop Management tooltip visit')
typed = typed.replace(old_tooltip, "find.byTooltip('机构成员')")
typed_path.write_text(typed, encoding='utf-8')
