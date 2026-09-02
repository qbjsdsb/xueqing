import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/logging/app_logger.dart';

void configureGlobalErrorHandling() {
  const logger = AppLogger(environment: AppEnvironment.production);

  FlutterError.onError = (details) {
    logger.error('Flutter framework error.');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (_error, _stack) {
    logger.error('Uncaught asynchronous error.');
    return true;
  };
}
