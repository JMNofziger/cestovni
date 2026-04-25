import 'package:flutter/material.dart';

import '../db/app_database.dart';
import 'shell.dart';
import 'theme/cestovni_theme.dart';

class CestovniApp extends StatelessWidget {
  const CestovniApp({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cestovni',
      theme: CestovniTheme.light(),
      darkTheme: CestovniTheme.dark(),
      // Spec §1 / §5: dark is the first-load default. Light remains
      // available for a future user toggle (CES-56+).
      themeMode: ThemeMode.dark,
      home: CestovniShell(db: db),
    );
  }
}
