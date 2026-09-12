import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable release backend gate is version-aware for v0.3.8', () {
    final workflow = File('.github/workflows/publish-release-assets.yml')
        .readAsStringSync();

    expect(workflow, contains('required_schema="20260911193000"'));
    expect(workflow, contains('RELEASE_VERSION_NAME="$version_name"'));
    expect(workflow, contains('version >= (0, 3, 8)'));
    expect(workflow, contains('"responsibility_read_model"'));
    expect(workflow, contains('"responsibility_safe_quick_capture"'));
    expect(
      workflow,
      contains(
        'required += ["responsibility_read_model", '
        '"responsibility_safe_quick_capture"] if version >= (0, 3, 8) else []',
      ),
    );
  });
}
