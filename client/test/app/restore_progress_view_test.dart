import 'package:cestovni/app/pages/restore_progress_view.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/sync/restore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    CestovniTypography.useGoogleFonts = false;
  });
  tearDownAll(() {
    CestovniTypography.useGoogleFonts = true;
  });

  testWidgets('shows per-table progress and a retry button on failure',
      (tester) async {
    var retries = 0;
    var offline = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RestoreProgressView(
          snapshot: RestoreSnapshot(
            phase: RestoreRunPhase.failed,
            rowsApplied: 1,
            message: 'upstream',
            tables: const [
              RestoreTableProgress(
                table: 'vehicles',
                received: 1,
                total: 1,
                phase: RestoreTablePhase.done,
              ),
              RestoreTableProgress(
                table: 'fill_ups',
                received: 1,
                total: 2,
                phase: RestoreTablePhase.running,
              ),
              RestoreTableProgress(
                table: 'maintenance_events',
                received: 0,
                total: 4,
                phase: RestoreTablePhase.waiting,
              ),
            ],
          ),
          onRetry: () => retries += 1,
          onUseOffline: () => offline += 1,
        ),
      ),
    );

    expect(find.text('Vehicles: 1/1 ✓'), findsOneWidget);
    expect(find.text('Fill-ups: 1/2...'), findsOneWidget);
    expect(find.text('Maintenance: waiting...'), findsOneWidget);
    expect(find.text('upstream'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Use this device offline'));
    expect(retries, 1);
    expect(offline, 1);
  });
}
