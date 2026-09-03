import 'dart:developer' as developer;

import '../../config/app_config.dart';

class AppLogger {
  const AppLogger({required this.environment, this.name = 'xueqing'});

  final AppEnvironment environment;
  final String name;

  void info(String message) {
    if (!environment.isProduction) {
      developer.log(message, name: name);
    }
  }

  void warning(String message) {
    developer.log(message, name: name, level: 900);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: name,
      level: 1000,
      object: error,
      stackTrace: stackTrace,
    );
  }
}
