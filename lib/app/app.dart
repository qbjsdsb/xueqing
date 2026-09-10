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
      title: '学情',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // Always start from the root route. The router decides whether that
      // root renders developer bootstrap tools or the teacher workspace.
      // Using /teacher-workspace as initialRoute makes Flutter also create
      // the '/' route beneath it, which duplicates the workspace on startup.
      initialRoute: AppRoutes.bootstrap,
      onGenerateRoute: router.onGenerateRoute,
    );
  }
}
