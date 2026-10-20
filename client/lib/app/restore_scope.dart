import 'package:flutter/material.dart';

import '../sync/restore_controller.dart';

class RestoreScope extends InheritedNotifier<RestoreController> {
  const RestoreScope({
    super.key,
    required RestoreController controller,
    required super.child,
  }) : super(notifier: controller);

  static RestoreController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RestoreScope>()
        ?.notifier;
  }
}
