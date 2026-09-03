import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/router/app_router.dart';
import 'package:xueqing/bootstrap/app_bootstrap.dart';
import 'package:xueqing/config/app_config.dart';

void main() {
  final config = AppConfig.fromValues(
    environmentValue: 'development',
    appVersion: '0.1.0+1',
  );

  testWidgets('shows a loading state before configuration is ready', (
    tester,
  ) async {
    final completer = Completer<AppConfig>();

    await tester.pumpWidget(AppBootstrap(loader: () => completer.future));

    expect(find.text('正在加载工程配置'), findsOneWidget);

    completer.complete(config);
    await tester.pumpAndSettle();
  });

  testWidgets('renders the bootstrap page after configuration loads', (
    tester,
  ) async {
    await tester.pumpWidget(AppBootstrap(loader: () async => config));
    await tester.pumpAndSettle();

    expect(find.text('教师工作台预览'), findsOneWidget);
    expect(find.text('Android / Windows'), findsOneWidget);
    expect(find.text('0B.1A 界面验证'), findsOneWidget);
  });

  testWidgets('shows a safe fallback when bootstrap fails', (tester) async {
    await tester.pumpWidget(
      AppBootstrap(
        loader: () async => throw StateError('not shown to the user'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('工程启动失败'), findsOneWidget);
    expect(find.text('not shown to the user'), findsNothing);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('can navigate through the router smoke path', (tester) async {
    await tester.pumpWidget(AppBootstrap(loader: () async => config));
    await tester.pumpAndSettle();

    await tester.tap(find.text('路由自检'));
    await tester.pumpAndSettle();

    expect(find.text('路由可用'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(AppRoutes.routeCheck, '/route-check');
  });
}
