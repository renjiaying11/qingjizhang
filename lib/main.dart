import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'db/database_helper.dart';
import 'pages/main_shell.dart';
import 'providers/app_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 预热数据库：触发建表与预置分类
  await DatabaseHelper.instance.database;
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppData(),
      child: const QingjizhangApp(),
    ),
  );
}

class QingjizhangApp extends StatelessWidget {
  const QingjizhangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '轻记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D5B)),
        scaffoldBackgroundColor: const Color(0xFFF7F8F7),
      ),
      home: const MainShell(),
    );
  }
}
