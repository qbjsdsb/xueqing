import 'package:flutter/widgets.dart';

import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/bootstrap.dart';
import 'bootstrap/error_handling.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureGlobalErrorHandling();
  runApp(AppBootstrap(loader: bootstrapFoundation));
}
