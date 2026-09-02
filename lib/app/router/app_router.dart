import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../features/bootstrap/presentation/bootstrap_page.dart';

abstract final class AppRoutes {
  static const bootstrap = '/';
  static const routeCheck = '/route-check';
  static const notFound = '/not-found';
}

class XueqingRouter {
  const XueqingRouter({required this.config});

  final AppConfig config;

  Route<void> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.bootstrap:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BootstrapPage(config: config),
        );
      case AppRoutes.routeCheck:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const _RouteCheckPage(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const _NotFoundPage(),
        );
    }
  }
}

class _RouteCheckPage extends StatelessWidget {
  const _RouteCheckPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('路由自检')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '路由可用',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(
        child: Text(
          '未找到对应路由。',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
