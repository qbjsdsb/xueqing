import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standalone management uses the quiet V2 header action model', () {
    final source = File('lib/features/design_v2/v2_management_page.dart')
        .readAsStringSync();

    expect(source, contains("import 'v2_page_header.dart';"));
    expect(source, contains('V2PageHeader('));
    expect(source, contains("key: const Key('v2-management-page-header')"));
    expect(source, contains("key: const Key('v2-management-more')"));
    expect(source, contains('PopupMenuButton<_ManagementPageAction>'));
    expect(source, contains("tooltip: '更多操作'"));
    expect(source, contains("'检查更新'"));
    expect(source, contains("'退出登录'"));
    expect(source, contains("'当前版本 \${widget.runtime.appVersion}'"));

    expect(source, isNot(contains('appBar: AppBar(')));
    expect(source, isNot(contains("tooltip: '检查更新'")));
    expect(source, isNot(contains("tooltip: '退出登录'")));

    // Preserve existing local modal/scroll ergonomics; this visual cut does
    // not redefine the management feature's behavior or data boundary.
    expect(source, contains('MediaQuery.sizeOf(context).width < 720'));
    expect(source, contains('MediaQuery.sizeOf(context).width >= 720'));
    expect(source, contains('showHeaderTitle: false'));
  });
}
