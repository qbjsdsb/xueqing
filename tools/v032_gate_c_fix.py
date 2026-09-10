from pathlib import Path

path = Path('lib/features/design_v2/v2_composers.dart')
text = path.read_text(encoding='utf-8')
old = "import 'package:flutter/material.dart';\n"
new = "import 'dart:async';\n\nimport 'package:flutter/material.dart';\n"
if text.count(old) != 1:
    raise SystemExit(f'expected one Flutter import, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Gate C dart:async import fixed')
