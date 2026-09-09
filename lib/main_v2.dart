import 'package:flutter/material.dart';

import 'features/design_v2/v2_theme.dart';
import 'features/design_v2/v2_workspace_preview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XueqingV2PreviewApp());
}

class XueqingV2PreviewApp extends StatelessWidget {
  const XueqingV2PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Xueqing V2 Preview',
      theme: V2Theme.light(),
      darkTheme: V2Theme.dark(),
      themeMode: ThemeMode.system,
      home: const V2WorkspacePreview(),
    );
  }
}
