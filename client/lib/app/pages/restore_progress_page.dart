import 'package:flutter/material.dart';

import '../../sync/restore_controller.dart';
import '../../sync/restore_service.dart';
import '../restore_scope.dart';
import 'restore_progress_view.dart';

/// Route that drives [RestoreController] and leaves once vehicles and
/// fill-ups are caught up.
class RestoreProgressPage extends StatefulWidget {
  const RestoreProgressPage({super.key, required this.reason});

  final RestoreReason reason;

  @override
  State<RestoreProgressPage> createState() => _RestoreProgressPageState();
}

class _RestoreProgressPageState extends State<RestoreProgressPage> {
  RestoreController? _controller;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = RestoreScope.maybeOf(context);
    if (!identical(next, _controller)) {
      _controller?.removeListener(_onUpdate);
      _controller = next;
      _controller?.addListener(_onUpdate);
    }
    if (!_started && _controller != null) {
      _started = true;
      final controller = _controller!;
      if (!controller.isRunning &&
          controller.snapshot.phase != RestoreRunPhase.complete) {
        controller.start(widget.reason);
      }
    }
  }

  void _onUpdate() {
    if (!mounted || _left) return;
    final snap = _controller?.snapshot;
    if (snap == null) return;
    final coreUnblocked = snap.coreReady && snap.phase == RestoreRunPhase.running;
    if (coreUnblocked || snap.phase == RestoreRunPhase.complete) {
      _left = true;
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  var _left = false;

  @override
  void dispose() {
    _controller?.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        body: Center(child: Text('Sync is not configured')),
      );
    }
    return RestoreProgressView(
      snapshot: controller.snapshot,
      onRetry: () => controller.start(widget.reason),
      onUseOffline: () {
        controller.cancel();
        _left = true;
        Navigator.of(context).pop();
      },
    );
  }
}
