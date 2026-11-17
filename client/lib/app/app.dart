import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../auth/auth_session.dart';
import '../auth/sync_wiring.dart';
import '../db/app_database.dart';
import '../sync/restore_controller.dart';
import '../sync/settings_rebind.dart';
import '../sync/sync_config.dart';
import 'restore_scope.dart';
import 'shell.dart';
import 'theme/cestovni_theme.dart';

class CestovniApp extends StatefulWidget {
  const CestovniApp({super.key, required this.db});

  final AppDatabase db;

  @override
  State<CestovniApp> createState() => _CestovniAppState();
}

class _CestovniAppState extends State<CestovniApp> {
  late final AuthSession _auth;
  late final RestoreController _restore;

  @override
  void initState() {
    super.initState();
    const cfg = SyncConfig.fromEnvironment;
    _auth = AuthSession(
      baseUrl: cfg.baseUrl,
      beforeSignedIn: (userId, accessToken) {
        return rebindSettingsOnSignIn(
          db: widget.db,
          baseUrl: cfg.baseUrl,
          accessToken: accessToken,
          userId: userId,
        );
      },
    );
    _restore = RestoreController(
      db: widget.db,
      openClient: () {
        if (cfg.baseUrl.isEmpty) return null;
        return syncClientFor(cfg, session: _auth);
      },
    );
  }

  @override
  void dispose() {
    _restore.dispose();
    _auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      session: _auth,
      child: RestoreScope(
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
      ),
    );
  }
}
