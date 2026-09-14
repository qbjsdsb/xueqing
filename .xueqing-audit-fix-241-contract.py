from pathlib import Path

path = Path('test/features/windows_organization_navigation_contract_test.dart')
text = path.read_text(encoding='utf-8')
old = '''      contains("v2-organization-management-scroll-${_managementArea?.name ?? 'default'}"),
'''
new = '''      contains(r"v2-organization-management-scroll-${_managementArea?.name ?? 'default'}"),
'''
if text.count(old) != 1:
    raise SystemExit(f'expected one interpolated source-contract string, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
