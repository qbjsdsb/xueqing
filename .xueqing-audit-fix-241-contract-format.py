from pathlib import Path

path = Path('test/features/windows_organization_navigation_contract_test.dart')
text = path.read_text(encoding='utf-8')
old = '''    expect(
      organization,
      contains("Key('v2-organization-management-scroll')"),
    );
'''
new = '''    expect(
      organization,
      contains("'v2-organization-management-scroll'"),
    );
'''
if text.count(old) != 1:
    raise SystemExit(f'expected one formatter-sensitive scroll-key contract, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
