/// Repository for the single-row `settings` table.
///
/// Spec: `docs/specs/data-model.md` §`settings` +
/// `docs/product/ux/DATA_CONTRACTS.md` §"Units and storage" +
/// `docs/product/ux/DELIVERY_ACCEPTANCE.md` §Settings & vehicles.
///
/// v1 contract: exactly one row per user. The `id` column equals the
/// user_id (both UUIDv4); see `client/lib/db/tables/settings.dart`.
/// On a fresh install we have no `user_id` yet, so [bootstrap]
/// generates a local UUID and reuses it as the row id. The server-
/// assigned `user_id` lands on first sync (M3).
library;

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'protocol_writes.dart';

/// Defaults for a brand-new install. Aligned with M1 brief — Czech
/// market lead, but harmless on other locales.
const _defaultDistanceUnit = 'km';
const _defaultVolumeUnit = 'L';
const _defaultCurrencyCode = 'EUR';
const _defaultTimezone = 'UTC';

class SettingsRepository {
  SettingsRepository(
    this._db, {
    String Function()? newId,
    String Function()? now,
  })  : _newId = newId ?? newUuid,
        _now = now ?? nowIsoUtc;

  final AppDatabase _db;
  final String Function() _newId;
  final String Function() _now;

  /// Read the single settings row, creating it with defaults if it
  /// does not yet exist. Always returns a row.
  Future<SettingsRow> getOrBootstrap() async {
    final existing =
        await _db.select(_db.appSettings).getSingleOrNull();
    if (existing != null) return existing;
    return _bootstrap();
  }

  /// Stream the single settings row. Emits `null` until [getOrBootstrap]
  /// has run at least once for a fresh install.
  Stream<SettingsRow?> watchSingle() {
    return _db.select(_db.appSettings).watchSingleOrNull();
  }

  /// Update preferences in place. Pass `null` to leave a field
  /// unchanged. Bootstraps the row first if necessary so the UI never
  /// has to special-case "settings not yet created".
  Future<SettingsRow> update({
    String? preferredDistanceUnit,
    String? preferredVolumeUnit,
    String? currencyCode,
    String? timezone,
  }) async {
    final row = await getOrBootstrap();
    await (_db.update(_db.appSettings)..where((s) => s.id.equals(row.id)))
        .write(
      AppSettingsCompanion(
        preferredDistanceUnit: preferredDistanceUnit == null
            ? const Value.absent()
            : Value(preferredDistanceUnit),
        preferredVolumeUnit: preferredVolumeUnit == null
            ? const Value.absent()
            : Value(preferredVolumeUnit),
        currencyCode: currencyCode == null
            ? const Value.absent()
            : Value(currencyCode),
        timezone:
            timezone == null ? const Value.absent() : Value(timezone),
        updatedAt: Value(_now()),
        mutationId: Value(_newId()),
      ),
    );
    final updated =
        await (_db.select(_db.appSettings)..where((s) => s.id.equals(row.id)))
            .getSingle();
    return updated;
  }

  Future<SettingsRow> _bootstrap() async {
    final id = _newId();
    await _db.into(_db.appSettings).insert(
          AppSettingsCompanion(
            id: Value(id),
            preferredDistanceUnit: const Value(_defaultDistanceUnit),
            preferredVolumeUnit: const Value(_defaultVolumeUnit),
            currencyCode: const Value(_defaultCurrencyCode),
            timezone: const Value(_defaultTimezone),
            updatedAt: Value(_now()),
            mutationId: Value(_newId()),
          ),
        );
    return (_db.select(_db.appSettings)..where((s) => s.id.equals(id)))
        .getSingle();
  }
}
