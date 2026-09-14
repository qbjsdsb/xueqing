import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows organization navigation v2 contract stays documented', () {
    final doc = File('docs/design/WINDOWS_ORGANIZATION_NAVIGATION_V2.md')
        .readAsStringSync();

    expect(doc, contains('OrganizationManagementArea'));
    expect(doc, contains('192px'));
    expect(doc, contains('更多'));
    expect(doc, contains('我的学生'));
    expect(doc, contains('机构设置'));
    expect(doc, contains('Compact and standalone Organization pages retain'));
    expect(doc, contains('No Supabase, RLS, RPC'));
  });
}
