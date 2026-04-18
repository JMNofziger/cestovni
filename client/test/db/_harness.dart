import 'package:cestovni/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart' show Uuid;

/// Minimal harness for DB tests. Uses an in-memory SQLite executor so
/// tests are hermetic and fast; no temp files required.
AppDatabase openInMemoryDb() {
  return AppDatabase.withExecutor(NativeDatabase.memory());
}

/// Deterministic UUID helper. Every test gets a fresh [Uuid] instance
/// so even "equal" fixtures produce distinct IDs.
String newId() => const Uuid().v4();

String nowIso() => DateTime.now().toUtc().toIso8601String();
