import 'package:flutter_test/flutter_test.dart';

import '_harness.dart';

/// The index coverage from docs/specs/data-model.md is a load-bearing
/// performance guardrail per ADR 001 §"Index and performance
/// guardrails". This test locks the *set* so a later migration can't
/// silently drop one.
void main() {
  test('all data-model.md indexes exist after onCreate', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();

    expect(names, containsAll(<String>{
      'fill_ups_user_row_version_idx',
      'fill_ups_user_vehicle_time_idx',
      'fill_ups_vehicle_id_idx',
      'maintenance_events_user_row_version_idx',
      'maintenance_events_user_vehicle_time_idx',
      'maintenance_rules_user_row_version_idx',
      'maintenance_rules_user_vehicle_idx',
      'settings_row_version_idx',
      'settings_user_id_uidx',
      'vehicles_row_version_idx',
      'vehicles_user_id_idx',
      'vehicles_user_live_idx',
    }));
  });
}
