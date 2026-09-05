import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/logging/app_logger.dart';

void configureGlobalErrorHandling() {
  const logger = AppLogger(environment: AppEnvironment.production);

  FlutterError.onError = (details) {
    logger.error(
      'Flutter framework error.',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    logger.error(
      'Uncaught asynchronous error.',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };
}
