import 'package:flutter/material.dart';

import '../db/app_database.dart';
import 'restore_scope.dart';
import 'shell.dart';
import 'theme/cestovni_theme.dart';
import '../sync/restore_controller.dart';

class CestovniApp extends StatefulWidget {
  const CestovniApp({super.key, required this.db});

  final AppDatabase db;

  @override
  State<CestovniApp> createState() => _CestovniAppState();
}

class _CestovniAppState extends State<CestovniApp> {
  late final RestoreController _restore;

  @override
  void initState() {
    super.initState();
    _restore = RestoreController(db: widget.db);
  }

  @override
  void dispose() {
    _restore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestoreScope(
      controller: _restore,
      child: MaterialApp(
        title: 'Cestovni',
        theme: CestovniTheme.light(),
        darkTheme: CestovniTheme.dark(),
        // Spec §1 / §5: dark is the first-load default. Light remains
        // available for a future user toggle (CES-56+).
        themeMode: ThemeMode.dark,
        home: CestovniShell(db: widget.db),
      ),
    );
  }
}
