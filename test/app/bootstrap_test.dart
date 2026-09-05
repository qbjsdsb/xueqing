import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/router/app_router.dart';
import 'package:xueqing/bootstrap/app_bootstrap.dart';
import 'package:xueqing/cloud/cloud_config.dart';
import 'package:xueqing/config/app_config.dart';

void main() {
  final config = AppConfig.fromValues(
    environmentValue: 'development',
    appVersion: '0.1.0+1',
  );
  final productionConfig = AppConfig.fromValues(
    environmentValue: 'production',
    appVersion: '0.1.0+1',
    cloudConfig: const CloudConfig(
      url: 'https://example.supabase.co',
      publishableKey: 'fictional-production-key',
      allowedHosts: ['example.supabase.co'],
    ),
    showDeveloperTools: true,
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

    expect(find.text('教师工作台'), findsOneWidget);
    expect(find.text('Android / Windows'), findsOneWidget);
    expect(find.text('0B.0-D 数据接入验证'), findsOneWidget);
  });

  testWidgets('hides development-only controls and routes in production', (
    tester,
  ) async {
    await tester.pumpWidget(AppBootstrap(loader: () async => productionConfig));
    await tester.pumpAndSettle();

    expect(find.text('生产配置'), findsOneWidget);
    expect(find.text('生产发布前置检查'), findsOneWidget);
    expect(find.text('打开虚构数据预览'), findsNothing);
    expect(find.text('打开云端连接测试'), findsNothing);
    expect(find.text('路由自检'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.designPreview,
        onGenerateRoute: XueqingRouter(config: productionConfig)
            .onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('页面不存在'), findsOneWidget);
  });

  testWidgets('normal builds skip the developer bootstrap', (tester) async {
    final normalTestConfig = AppConfig.fromValues(
      environmentValue: 'development',
      appVersion: '0.1.0+1',
      showDeveloperTools: false,
    );

    await tester.pumpWidget(AppBootstrap(loader: () async => normalTestConfig));
    await tester.pumpAndSettle();

    expect(find.text('教师工作台'), findsOneWidget);
    expect(find.text('开发云端尚未配置'), findsOneWidget);
    expect(find.text('打开虚构数据预览'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.designPreview,
        onGenerateRoute: XueqingRouter(config: normalTestConfig)
            .onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('页面不存在'), findsOneWidget);
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

    final routeCheckButton = find.text('路由自检');
    await tester.ensureVisible(routeCheckButton);
    await tester.tap(routeCheckButton);
    await tester.pumpAndSettle();

    expect(find.text('路由可用'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
