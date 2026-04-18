import 'package:flutter/material.dart';

import '../db/app_database.dart';
import 'shell.dart';

class CestovniApp extends StatelessWidget {
  const CestovniApp({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cestovni',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32),
      ),
      home: CestovniShell(db: db),
    );
  }
}
