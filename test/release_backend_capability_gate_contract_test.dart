import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable release backend gate is version-aware for v0.3.8', () {
    final workflow = File('.github/workflows/publish-release-assets.yml')
        .readAsStringSync();

    expect(workflow, contains('required_schema = "20260911193000"'));
    expect(workflow, contains(r'RELEASE_VERSION_NAME="$version_name"'));
    expect(
      workflow,
      contains(
        "BACKEND_JSON=\"\$backend_json\" "
        "RELEASE_VERSION_NAME=\"\$version_name\" python3 - <<'PY'",
      ),
    );
    expect(
      workflow,
      isNot(contains("python3 -c 'import json, os; required_schema=")),
    );
    expect(workflow, contains('version >= (0, 3, 8)'));
    expect(workflow, contains('"responsibility_read_model"'));
    expect(workflow, contains('"organization_profile_responsibility"'));
    expect(workflow, contains('"responsibility_safe_quick_capture"'));
    expect(
      workflow,
      contains(
        'required += [\n'
        '              "responsibility_read_model",\n'
        '              "organization_profile_responsibility",\n'
        '              "responsibility_safe_quick_capture",\n'
        '          ] if version >= (0, 3, 8) else []',
      ),
    );
  });
}
