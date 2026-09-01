import 'package:flutter/material.dart';

void main() {
  runApp(const XueqingApp());
}

class XueqingApp extends StatelessWidget {
  const XueqingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学情闭环',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF315F52),
      ),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '学情闭环',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '机构教学协作与学生成长管理平台',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 28),
                  Text('V0.1 · 项目底座已建立'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
