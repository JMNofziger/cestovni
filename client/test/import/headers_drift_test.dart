import 'package:cestovni/export/headers.dart';
import 'package:cestovni/import/validate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec: import expected headers *are* the export constants — never a
/// parallel copy that can drift.
void main() {
  test('importCsvHeaders is the export constant set', () {
    expect(importCsvHeaders, {
      'vehicles.csv': vehiclesCsvHeader,
      'fill_ups.csv': fillUpsCsvHeader,
      'maintenance_rules.csv': maintenanceRulesCsvHeader,
      'maintenance_events.csv': maintenanceEventsCsvHeader,
      'settings.csv': settingsCsvHeader,
    });
    expect(importCsvHeaders['vehicles.csv'], same(vehiclesCsvHeader));
    expect(importCsvHeaders['fill_ups.csv'], same(fillUpsCsvHeader));
    expect(
      importCsvHeaders['maintenance_rules.csv'],
      same(maintenanceRulesCsvHeader),
    );
    expect(
      importCsvHeaders['maintenance_events.csv'],
      same(maintenanceEventsCsvHeader),
    );
    expect(importCsvHeaders['settings.csv'], same(settingsCsvHeader));
  });
}
