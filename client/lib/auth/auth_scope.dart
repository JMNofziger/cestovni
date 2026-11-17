import 'package:flutter/widgets.dart';

import 'auth_session.dart';

/// The one [AuthSession] for this process. The sign-in screen (CES-89)
/// and the sync client both read it from here.
class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.session, required super.child});

  final AuthSession session;

  static AuthSession? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.session;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) =>
      !identical(session, oldWidget.session);
}
