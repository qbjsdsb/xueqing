import 'package:flutter/material.dart';

import '../app/app.dart';
import '../config/app_config.dart';
import '../core/error/app_failure.dart';
import '../features/bootstrap/presentation/bootstrap_status_page.dart';

typedef AppConfigLoader = Future<AppConfig> Function();

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({required this.loader, super.key});

  final AppConfigLoader loader;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<AppConfig> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = widget.loader();
  }

  void _retry() {
    setState(() {
      _configFuture = widget.loader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppConfig>(
      future: _configFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const BootstrapStatusApp(state: BootstrapStatus.loading);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return BootstrapStatusApp(
            state: BootstrapStatus.failure,
            failure: const AppFailure.bootstrap(),
            onRetry: _retry,
          );
        }

        return XueqingApp(config: snapshot.data!);
      },
    );
  }
}
