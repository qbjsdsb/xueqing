import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class XueqingApp extends StatelessWidget {
  const XueqingApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final router = XueqingRouter(config: config);

    return MaterialApp(
      title: '学情闭环',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: config.showDeveloperTools
          ? AppRoutes.bootstrap
          : AppRoutes.teacherWorkspace,
      onGenerateRoute: router.onGenerateRoute,
    );
  }
}
