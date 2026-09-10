from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if text.count(old) != 1:
        raise SystemExit(f'expected one match in {path}, found {text.count(old)}: {old!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/features/design_v2/v2_update_flow.dart',
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';\n",
)
replace_once(
    'lib/features/design_v2/v2_update_flow.dart',
    '    if (!context.mounted || installResult == null) return;\n',
    '    if (!context.mounted) return;\n',
)
replace_once(
    'test/features/v032_real_device_ux_contract_test.dart',
    "    expect(feedback, contains('保存位置：$savedPath'));\n",
    "    expect(feedback, contains(r'保存位置：$savedPath'));\n",
)
replace_once(
    'test/features/v2_shell_production_capabilities_test.dart',
    "    expect(updateFlow, contains('service.download(result)'));\n",
    "    expect(updateFlow, contains('service.download('));\n"
    "    expect(updateFlow, contains('onProgress:'));\n",
)

print('Gate A analyzer and contract fixes applied')
