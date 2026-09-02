import '../config/app_config.dart';
import '../core/logging/app_logger.dart';

Future<AppConfig> bootstrapFoundation() async {
  final config = AppConfig.fromDartDefines();
  AppLogger(environment: config.environment)
      .info('Application foundation initialized.');
  return config;
}
