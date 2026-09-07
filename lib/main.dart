import 'package:flutter/widgets.dart';

import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/bootstrap.dart';
import 'bootstrap/error_handling.dart';
import 'features/teacher_workspace/presentation/evidence_attachment_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureGlobalErrorHandling();
  primeLostEvidenceAttachmentRecovery();
  runApp(AppBootstrap(loader: bootstrapFoundation));
}
