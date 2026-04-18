import 'package:drift/drift.dart';

/// One step in the client schema history.
///
/// v1 has only a single `0001_init` step. `down` is defined for every
/// step from day one so M5 (CES-47) rollback tooling has a home to
/// slot into — it is not called in v1 (Drift runs forward-only) but
/// the structure is load-bearing for the rollback spec.
class MigrationStep {
  const MigrationStep({
    required this.from,
    required this.to,
    required this.up,
    required this.down,
    required this.name,
  });

  /// Schema version this step migrates **from**.
  final int from;

  /// Schema version this step migrates **to**.
  final int to;

  /// Human-readable identifier; matches the server migration basename
  /// per data-model.md §"Migration alignment (client ↔ server)".
  final String name;

  /// Forward migration.
  final Future<void> Function(Migrator m) up;

  /// Backward migration. In v1 the earliest schema is v1, so the
  /// `0001_init.down` below drops everything; wiring this in and
  /// letting M5 drive it from the UI is future work (CES-47).
  final Future<void> Function(Migrator m) down;
}

/// Runs a list of [MigrationStep]s in order. Chooses the right subset
/// based on `from` → `to`.
class MigrationRunner {
  const MigrationRunner(this.steps);

  final List<MigrationStep> steps;

  Future<void> upgrade(Migrator m, int from, int to) async {
    for (final step in steps) {
      if (step.from >= from && step.to <= to && step.from < step.to) {
        await step.up(m);
      }
    }
  }

  Future<void> downgrade(Migrator m, int from, int to) async {
    for (final step in steps.reversed) {
      if (step.to <= from && step.from >= to && step.from < step.to) {
        await step.down(m);
      }
    }
  }
}
