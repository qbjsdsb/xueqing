import 'package:flutter/material.dart';

import '../features/bootstrap/presentation/bootstrap_page.dart';

class XueqingApp extends StatelessWidget {
  const XueqingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学情闭环',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315F52),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const BootstrapPage(),
    );
  }
}
