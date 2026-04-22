// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VehiclesTable extends Vehicles
    with TableInfo<$VehiclesTable, VehicleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  @override
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
    'make',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 80),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 80),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (year IS NULL OR (year BETWEEN 1900 AND 2100))',
  );
  static const VerificationMeta _vinMeta = const VerificationMeta('vin');
  @override
  late final GeneratedColumn<String> vin = GeneratedColumn<String>(
    'vin',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 32),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelTypeMeta = const VerificationMeta(
    'fuelType',
  );
  @override
  late final GeneratedColumn<String> fuelType = GeneratedColumn<String>(
    'fuel_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (fuel_type IN (\'gasoline\',\'diesel\',\'lpg\',\'cng\',\'ev_kwh\',\'other\'))',
  );
  static const VerificationMeta _tankCapacityULMeta = const VerificationMeta(
    'tankCapacityUL',
  );
  @override
  late final GeneratedColumn<int> tankCapacityUL = GeneratedColumn<int>(
    'tank_capacity_uL',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (tank_capacity_uL IS NULL OR tank_capacity_uL >= 0)',
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    name,
    make,
    model,
    year,
    vin,
    fuelType,
    tankCapacityUL,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehicleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('make')) {
      context.handle(
        _makeMeta,
        make.isAcceptableOrUnknown(data['make']!, _makeMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('vin')) {
      context.handle(
        _vinMeta,
        vin.isAcceptableOrUnknown(data['vin']!, _vinMeta),
      );
    }
    if (data.containsKey('fuel_type')) {
      context.handle(
        _fuelTypeMeta,
        fuelType.isAcceptableOrUnknown(data['fuel_type']!, _fuelTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_fuelTypeMeta);
    }
    if (data.containsKey('tank_capacity_uL')) {
      context.handle(
        _tankCapacityULMeta,
        tankCapacityUL.isAcceptableOrUnknown(
          data['tank_capacity_uL']!,
          _tankCapacityULMeta,
        ),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehicleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      make: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}make'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      vin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vin'],
      ),
      fuelType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuel_type'],
      )!,
      tankCapacityUL: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tank_capacity_uL'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }
}

class VehicleRow extends DataClass implements Insertable<VehicleRow> {
  /// Client-generated UUIDv4 at creation; primary key.
  final String id;

  /// Server-assigned. Nullable on-device until the first successful
  /// server hydrate so rows inserted while offline still satisfy
  /// NOT NULL once the outbox drains.
  final String? userId;

  /// Server-assigned from `cestovni_row_version_seq`. Nullable on-device
  /// until first hydrate (ADR 002: "never written by the client").
  final int? rowVersion;

  /// Local/server wall-clock for human readability only (ISO-8601 UTC).
  final String updatedAt;

  /// Soft-delete marker; NULL when live.
  final String? deletedAt;

  /// Last idempotency key that touched the row; server dedupes retries.
  final String mutationId;
  final String name;
  final String? make;
  final String? model;
  final int? year;
  final String? vin;
  final String fuelType;

  /// Canonical µL; optional (informational).
  final int? tankCapacityUL;
  final String? archivedAt;
  const VehicleRow({
    required this.id,
    this.userId,
    this.rowVersion,
    required this.updatedAt,
    this.deletedAt,
    required this.mutationId,
    required this.name,
    this.make,
    this.model,
    this.year,
    this.vin,
    required this.fuelType,
    this.tankCapacityUL,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || rowVersion != null) {
      map['row_version'] = Variable<int>(rowVersion);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['mutation_id'] = Variable<String>(mutationId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || make != null) {
      map['make'] = Variable<String>(make);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || vin != null) {
      map['vin'] = Variable<String>(vin);
    }
    map['fuel_type'] = Variable<String>(fuelType);
    if (!nullToAbsent || tankCapacityUL != null) {
      map['tank_capacity_uL'] = Variable<int>(tankCapacityUL);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      rowVersion: rowVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(rowVersion),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      mutationId: Value(mutationId),
      name: Value(name),
      make: make == null && nullToAbsent ? const Value.absent() : Value(make),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      vin: vin == null && nullToAbsent ? const Value.absent() : Value(vin),
      fuelType: Value(fuelType),
      tankCapacityUL: tankCapacityUL == null && nullToAbsent
          ? const Value.absent()
          : Value(tankCapacityUL),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory VehicleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      rowVersion: serializer.fromJson<int?>(json['rowVersion']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      name: serializer.fromJson<String>(json['name']),
      make: serializer.fromJson<String?>(json['make']),
      model: serializer.fromJson<String?>(json['model']),
      year: serializer.fromJson<int?>(json['year']),
      vin: serializer.fromJson<String?>(json['vin']),
      fuelType: serializer.fromJson<String>(json['fuelType']),
      tankCapacityUL: serializer.fromJson<int?>(json['tankCapacityUL']),
      archivedAt: serializer.fromJson<String?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'rowVersion': serializer.toJson<int?>(rowVersion),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'mutationId': serializer.toJson<String>(mutationId),
      'name': serializer.toJson<String>(name),
      'make': serializer.toJson<String?>(make),
      'model': serializer.toJson<String?>(model),
      'year': serializer.toJson<int?>(year),
      'vin': serializer.toJson<String?>(vin),
      'fuelType': serializer.toJson<String>(fuelType),
      'tankCapacityUL': serializer.toJson<int?>(tankCapacityUL),
      'archivedAt': serializer.toJson<String?>(archivedAt),
    };
  }

  VehicleRow copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<int?> rowVersion = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    String? mutationId,
    String? name,
    Value<String?> make = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> vin = const Value.absent(),
    String? fuelType,
    Value<int?> tankCapacityUL = const Value.absent(),
    Value<String?> archivedAt = const Value.absent(),
  }) => VehicleRow(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    rowVersion: rowVersion.present ? rowVersion.value : this.rowVersion,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    mutationId: mutationId ?? this.mutationId,
    name: name ?? this.name,
    make: make.present ? make.value : this.make,
    model: model.present ? model.value : this.model,
    year: year.present ? year.value : this.year,
    vin: vin.present ? vin.value : this.vin,
    fuelType: fuelType ?? this.fuelType,
    tankCapacityUL: tankCapacityUL.present
        ? tankCapacityUL.value
        : this.tankCapacityUL,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  VehicleRow copyWithCompanion(VehiclesCompanion data) {
    return VehicleRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      name: data.name.present ? data.name.value : this.name,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      year: data.year.present ? data.year.value : this.year,
      vin: data.vin.present ? data.vin.value : this.vin,
      fuelType: data.fuelType.present ? data.fuelType.value : this.fuelType,
      tankCapacityUL: data.tankCapacityUL.present
          ? data.tankCapacityUL.value
          : this.tankCapacityUL,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('name: $name, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('vin: $vin, ')
          ..write('fuelType: $fuelType, ')
          ..write('tankCapacityUL: $tankCapacityUL, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    name,
    make,
    model,
    year,
    vin,
    fuelType,
    tankCapacityUL,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.rowVersion == this.rowVersion &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.mutationId == this.mutationId &&
          other.name == this.name &&
          other.make == this.make &&
          other.model == this.model &&
          other.year == this.year &&
          other.vin == this.vin &&
          other.fuelType == this.fuelType &&
          other.tankCapacityUL == this.tankCapacityUL &&
          other.archivedAt == this.archivedAt);
}

class VehiclesCompanion extends UpdateCompanion<VehicleRow> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<int?> rowVersion;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> mutationId;
  final Value<String> name;
  final Value<String?> make;
  final Value<String?> model;
  final Value<int?> year;
  final Value<String?> vin;
  final Value<String> fuelType;
  final Value<int?> tankCapacityUL;
  final Value<String?> archivedAt;
  final Value<int> rowid;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.name = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.vin = const Value.absent(),
    this.fuelType = const Value.absent(),
    this.tankCapacityUL = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiclesCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required String mutationId,
    required String name,
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.vin = const Value.absent(),
    required String fuelType,
    this.tankCapacityUL = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       mutationId = Value(mutationId),
       name = Value(name),
       fuelType = Value(fuelType);
  static Insertable<VehicleRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<int>? rowVersion,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? mutationId,
    Expression<String>? name,
    Expression<String>? make,
    Expression<String>? model,
    Expression<int>? year,
    Expression<String>? vin,
    Expression<String>? fuelType,
    Expression<int>? tankCapacityUL,
    Expression<String>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (rowVersion != null) 'row_version': rowVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (mutationId != null) 'mutation_id': mutationId,
      if (name != null) 'name': name,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (year != null) 'year': year,
      if (vin != null) 'vin': vin,
      if (fuelType != null) 'fuel_type': fuelType,
      if (tankCapacityUL != null) 'tank_capacity_uL': tankCapacityUL,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiclesCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<int?>? rowVersion,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? mutationId,
    Value<String>? name,
    Value<String?>? make,
    Value<String?>? model,
    Value<int?>? year,
    Value<String?>? vin,
    Value<String>? fuelType,
    Value<int?>? tankCapacityUL,
    Value<String?>? archivedAt,
    Value<int>? rowid,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rowVersion: rowVersion ?? this.rowVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      mutationId: mutationId ?? this.mutationId,
      name: name ?? this.name,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      vin: vin ?? this.vin,
      fuelType: fuelType ?? this.fuelType,
      tankCapacityUL: tankCapacityUL ?? this.tankCapacityUL,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (vin.present) {
      map['vin'] = Variable<String>(vin.value);
    }
    if (fuelType.present) {
      map['fuel_type'] = Variable<String>(fuelType.value);
    }
    if (tankCapacityUL.present) {
      map['tank_capacity_uL'] = Variable<int>(tankCapacityUL.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('name: $name, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('vin: $vin, ')
          ..write('fuelType: $fuelType, ')
          ..write('tankCapacityUL: $tankCapacityUL, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FillUpsTable extends FillUps with TableInfo<$FillUpsTable, FillUpRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FillUpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id)',
    ),
  );
  static const VerificationMeta _filledAtMeta = const VerificationMeta(
    'filledAt',
  );
  @override
  late final GeneratedColumn<String> filledAt = GeneratedColumn<String>(
    'filled_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMMeta = const VerificationMeta(
    'odometerM',
  );
  @override
  late final GeneratedColumn<int> odometerM = GeneratedColumn<int>(
    'odometer_m',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (odometer_m >= 0)',
  );
  static const VerificationMeta _volumeULMeta = const VerificationMeta(
    'volumeUL',
  );
  @override
  late final GeneratedColumn<int> volumeUL = GeneratedColumn<int>(
    'volume_uL',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (volume_uL >= 0)',
  );
  static const VerificationMeta _totalPriceCentsMeta = const VerificationMeta(
    'totalPriceCents',
  );
  @override
  late final GeneratedColumn<int> totalPriceCents = GeneratedColumn<int>(
    'total_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (total_price_cents >= 0)',
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (currency_code GLOB \'[A-Z][A-Z][A-Z]\')',
  );
  static const VerificationMeta _isFullMeta = const VerificationMeta('isFull');
  @override
  late final GeneratedColumn<bool> isFull = GeneratedColumn<bool>(
    'is_full',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_full" IN (0, 1))',
    ),
  );
  static const VerificationMeta _missedBeforeMeta = const VerificationMeta(
    'missedBefore',
  );
  @override
  late final GeneratedColumn<bool> missedBefore = GeneratedColumn<bool>(
    'missed_before',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missed_before" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _odometerResetMeta = const VerificationMeta(
    'odometerReset',
  );
  @override
  late final GeneratedColumn<bool> odometerReset = GeneratedColumn<bool>(
    'odometer_reset',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("odometer_reset" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 500),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    vehicleId,
    filledAt,
    odometerM,
    volumeUL,
    totalPriceCents,
    currencyCode,
    isFull,
    missedBefore,
    odometerReset,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fill_ups';
  @override
  VerificationContext validateIntegrity(
    Insertable<FillUpRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('filled_at')) {
      context.handle(
        _filledAtMeta,
        filledAt.isAcceptableOrUnknown(data['filled_at']!, _filledAtMeta),
      );
    } else if (isInserting) {
      context.missing(_filledAtMeta);
    }
    if (data.containsKey('odometer_m')) {
      context.handle(
        _odometerMMeta,
        odometerM.isAcceptableOrUnknown(data['odometer_m']!, _odometerMMeta),
      );
    } else if (isInserting) {
      context.missing(_odometerMMeta);
    }
    if (data.containsKey('volume_uL')) {
      context.handle(
        _volumeULMeta,
        volumeUL.isAcceptableOrUnknown(data['volume_uL']!, _volumeULMeta),
      );
    } else if (isInserting) {
      context.missing(_volumeULMeta);
    }
    if (data.containsKey('total_price_cents')) {
      context.handle(
        _totalPriceCentsMeta,
        totalPriceCents.isAcceptableOrUnknown(
          data['total_price_cents']!,
          _totalPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPriceCentsMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('is_full')) {
      context.handle(
        _isFullMeta,
        isFull.isAcceptableOrUnknown(data['is_full']!, _isFullMeta),
      );
    } else if (isInserting) {
      context.missing(_isFullMeta);
    }
    if (data.containsKey('missed_before')) {
      context.handle(
        _missedBeforeMeta,
        missedBefore.isAcceptableOrUnknown(
          data['missed_before']!,
          _missedBeforeMeta,
        ),
      );
    }
    if (data.containsKey('odometer_reset')) {
      context.handle(
        _odometerResetMeta,
        odometerReset.isAcceptableOrUnknown(
          data['odometer_reset']!,
          _odometerResetMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FillUpRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FillUpRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      filledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filled_at'],
      )!,
      odometerM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}odometer_m'],
      )!,
      volumeUL: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume_uL'],
      )!,
      totalPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_price_cents'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      isFull: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_full'],
      )!,
      missedBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missed_before'],
      )!,
      odometerReset: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}odometer_reset'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $FillUpsTable createAlias(String alias) {
    return $FillUpsTable(attachedDatabase, alias);
  }
}

class FillUpRow extends DataClass implements Insertable<FillUpRow> {
  /// Client-generated UUIDv4 at creation; primary key.
  final String id;

  /// Server-assigned. Nullable on-device until the first successful
  /// server hydrate so rows inserted while offline still satisfy
  /// NOT NULL once the outbox drains.
  final String? userId;

  /// Server-assigned from `cestovni_row_version_seq`. Nullable on-device
  /// until first hydrate (ADR 002: "never written by the client").
  final int? rowVersion;

  /// Local/server wall-clock for human readability only (ISO-8601 UTC).
  final String updatedAt;

  /// Soft-delete marker; NULL when live.
  final String? deletedAt;

  /// Last idempotency key that touched the row; server dedupes retries.
  final String mutationId;
  final String vehicleId;
  final String filledAt;
  final int odometerM;
  final int volumeUL;
  final int totalPriceCents;
  final String currencyCode;
  final bool isFull;
  final bool missedBefore;
  final bool odometerReset;
  final String? notes;
  const FillUpRow({
    required this.id,
    this.userId,
    this.rowVersion,
    required this.updatedAt,
    this.deletedAt,
    required this.mutationId,
    required this.vehicleId,
    required this.filledAt,
    required this.odometerM,
    required this.volumeUL,
    required this.totalPriceCents,
    required this.currencyCode,
    required this.isFull,
    required this.missedBefore,
    required this.odometerReset,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || rowVersion != null) {
      map['row_version'] = Variable<int>(rowVersion);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['mutation_id'] = Variable<String>(mutationId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['filled_at'] = Variable<String>(filledAt);
    map['odometer_m'] = Variable<int>(odometerM);
    map['volume_uL'] = Variable<int>(volumeUL);
    map['total_price_cents'] = Variable<int>(totalPriceCents);
    map['currency_code'] = Variable<String>(currencyCode);
    map['is_full'] = Variable<bool>(isFull);
    map['missed_before'] = Variable<bool>(missedBefore);
    map['odometer_reset'] = Variable<bool>(odometerReset);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  FillUpsCompanion toCompanion(bool nullToAbsent) {
    return FillUpsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      rowVersion: rowVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(rowVersion),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      mutationId: Value(mutationId),
      vehicleId: Value(vehicleId),
      filledAt: Value(filledAt),
      odometerM: Value(odometerM),
      volumeUL: Value(volumeUL),
      totalPriceCents: Value(totalPriceCents),
      currencyCode: Value(currencyCode),
      isFull: Value(isFull),
      missedBefore: Value(missedBefore),
      odometerReset: Value(odometerReset),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory FillUpRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FillUpRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      rowVersion: serializer.fromJson<int?>(json['rowVersion']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      filledAt: serializer.fromJson<String>(json['filledAt']),
      odometerM: serializer.fromJson<int>(json['odometerM']),
      volumeUL: serializer.fromJson<int>(json['volumeUL']),
      totalPriceCents: serializer.fromJson<int>(json['totalPriceCents']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      isFull: serializer.fromJson<bool>(json['isFull']),
      missedBefore: serializer.fromJson<bool>(json['missedBefore']),
      odometerReset: serializer.fromJson<bool>(json['odometerReset']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'rowVersion': serializer.toJson<int?>(rowVersion),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'mutationId': serializer.toJson<String>(mutationId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'filledAt': serializer.toJson<String>(filledAt),
      'odometerM': serializer.toJson<int>(odometerM),
      'volumeUL': serializer.toJson<int>(volumeUL),
      'totalPriceCents': serializer.toJson<int>(totalPriceCents),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'isFull': serializer.toJson<bool>(isFull),
      'missedBefore': serializer.toJson<bool>(missedBefore),
      'odometerReset': serializer.toJson<bool>(odometerReset),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  FillUpRow copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<int?> rowVersion = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    String? mutationId,
    String? vehicleId,
    String? filledAt,
    int? odometerM,
    int? volumeUL,
    int? totalPriceCents,
    String? currencyCode,
    bool? isFull,
    bool? missedBefore,
    bool? odometerReset,
    Value<String?> notes = const Value.absent(),
  }) => FillUpRow(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    rowVersion: rowVersion.present ? rowVersion.value : this.rowVersion,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    mutationId: mutationId ?? this.mutationId,
    vehicleId: vehicleId ?? this.vehicleId,
    filledAt: filledAt ?? this.filledAt,
    odometerM: odometerM ?? this.odometerM,
    volumeUL: volumeUL ?? this.volumeUL,
    totalPriceCents: totalPriceCents ?? this.totalPriceCents,
    currencyCode: currencyCode ?? this.currencyCode,
    isFull: isFull ?? this.isFull,
    missedBefore: missedBefore ?? this.missedBefore,
    odometerReset: odometerReset ?? this.odometerReset,
    notes: notes.present ? notes.value : this.notes,
  );
  FillUpRow copyWithCompanion(FillUpsCompanion data) {
    return FillUpRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      filledAt: data.filledAt.present ? data.filledAt.value : this.filledAt,
      odometerM: data.odometerM.present ? data.odometerM.value : this.odometerM,
      volumeUL: data.volumeUL.present ? data.volumeUL.value : this.volumeUL,
      totalPriceCents: data.totalPriceCents.present
          ? data.totalPriceCents.value
          : this.totalPriceCents,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      isFull: data.isFull.present ? data.isFull.value : this.isFull,
      missedBefore: data.missedBefore.present
          ? data.missedBefore.value
          : this.missedBefore,
      odometerReset: data.odometerReset.present
          ? data.odometerReset.value
          : this.odometerReset,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FillUpRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('filledAt: $filledAt, ')
          ..write('odometerM: $odometerM, ')
          ..write('volumeUL: $volumeUL, ')
          ..write('totalPriceCents: $totalPriceCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('isFull: $isFull, ')
          ..write('missedBefore: $missedBefore, ')
          ..write('odometerReset: $odometerReset, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    vehicleId,
    filledAt,
    odometerM,
    volumeUL,
    totalPriceCents,
    currencyCode,
    isFull,
    missedBefore,
    odometerReset,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FillUpRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.rowVersion == this.rowVersion &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.mutationId == this.mutationId &&
          other.vehicleId == this.vehicleId &&
          other.filledAt == this.filledAt &&
          other.odometerM == this.odometerM &&
          other.volumeUL == this.volumeUL &&
          other.totalPriceCents == this.totalPriceCents &&
          other.currencyCode == this.currencyCode &&
          other.isFull == this.isFull &&
          other.missedBefore == this.missedBefore &&
          other.odometerReset == this.odometerReset &&
          other.notes == this.notes);
}

class FillUpsCompanion extends UpdateCompanion<FillUpRow> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<int?> rowVersion;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> mutationId;
  final Value<String> vehicleId;
  final Value<String> filledAt;
  final Value<int> odometerM;
  final Value<int> volumeUL;
  final Value<int> totalPriceCents;
  final Value<String> currencyCode;
  final Value<bool> isFull;
  final Value<bool> missedBefore;
  final Value<bool> odometerReset;
  final Value<String?> notes;
  final Value<int> rowid;
  const FillUpsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.filledAt = const Value.absent(),
    this.odometerM = const Value.absent(),
    this.volumeUL = const Value.absent(),
    this.totalPriceCents = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.isFull = const Value.absent(),
    this.missedBefore = const Value.absent(),
    this.odometerReset = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FillUpsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required String mutationId,
    required String vehicleId,
    required String filledAt,
    required int odometerM,
    required int volumeUL,
    required int totalPriceCents,
    required String currencyCode,
    required bool isFull,
    this.missedBefore = const Value.absent(),
    this.odometerReset = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       mutationId = Value(mutationId),
       vehicleId = Value(vehicleId),
       filledAt = Value(filledAt),
       odometerM = Value(odometerM),
       volumeUL = Value(volumeUL),
       totalPriceCents = Value(totalPriceCents),
       currencyCode = Value(currencyCode),
       isFull = Value(isFull);
  static Insertable<FillUpRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<int>? rowVersion,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? mutationId,
    Expression<String>? vehicleId,
    Expression<String>? filledAt,
    Expression<int>? odometerM,
    Expression<int>? volumeUL,
    Expression<int>? totalPriceCents,
    Expression<String>? currencyCode,
    Expression<bool>? isFull,
    Expression<bool>? missedBefore,
    Expression<bool>? odometerReset,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (rowVersion != null) 'row_version': rowVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (mutationId != null) 'mutation_id': mutationId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (filledAt != null) 'filled_at': filledAt,
      if (odometerM != null) 'odometer_m': odometerM,
      if (volumeUL != null) 'volume_uL': volumeUL,
      if (totalPriceCents != null) 'total_price_cents': totalPriceCents,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (isFull != null) 'is_full': isFull,
      if (missedBefore != null) 'missed_before': missedBefore,
      if (odometerReset != null) 'odometer_reset': odometerReset,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FillUpsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<int?>? rowVersion,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? mutationId,
    Value<String>? vehicleId,
    Value<String>? filledAt,
    Value<int>? odometerM,
    Value<int>? volumeUL,
    Value<int>? totalPriceCents,
    Value<String>? currencyCode,
    Value<bool>? isFull,
    Value<bool>? missedBefore,
    Value<bool>? odometerReset,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return FillUpsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rowVersion: rowVersion ?? this.rowVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      mutationId: mutationId ?? this.mutationId,
      vehicleId: vehicleId ?? this.vehicleId,
      filledAt: filledAt ?? this.filledAt,
      odometerM: odometerM ?? this.odometerM,
      volumeUL: volumeUL ?? this.volumeUL,
      totalPriceCents: totalPriceCents ?? this.totalPriceCents,
      currencyCode: currencyCode ?? this.currencyCode,
      isFull: isFull ?? this.isFull,
      missedBefore: missedBefore ?? this.missedBefore,
      odometerReset: odometerReset ?? this.odometerReset,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (filledAt.present) {
      map['filled_at'] = Variable<String>(filledAt.value);
    }
    if (odometerM.present) {
      map['odometer_m'] = Variable<int>(odometerM.value);
    }
    if (volumeUL.present) {
      map['volume_uL'] = Variable<int>(volumeUL.value);
    }
    if (totalPriceCents.present) {
      map['total_price_cents'] = Variable<int>(totalPriceCents.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (isFull.present) {
      map['is_full'] = Variable<bool>(isFull.value);
    }
    if (missedBefore.present) {
      map['missed_before'] = Variable<bool>(missedBefore.value);
    }
    if (odometerReset.present) {
      map['odometer_reset'] = Variable<bool>(odometerReset.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FillUpsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('filledAt: $filledAt, ')
          ..write('odometerM: $odometerM, ')
          ..write('volumeUL: $volumeUL, ')
          ..write('totalPriceCents: $totalPriceCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('isFull: $isFull, ')
          ..write('missedBefore: $missedBefore, ')
          ..write('odometerReset: $odometerReset, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MaintenanceRulesTable extends MaintenanceRules
    with TableInfo<$MaintenanceRulesTable, MaintenanceRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaintenanceRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cadenceKmMeta = const VerificationMeta(
    'cadenceKm',
  );
  @override
  late final GeneratedColumn<int> cadenceKm = GeneratedColumn<int>(
    'cadence_km',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (cadence_km IS NULL OR cadence_km > 0)',
  );
  static const VerificationMeta _cadenceDaysMeta = const VerificationMeta(
    'cadenceDays',
  );
  @override
  late final GeneratedColumn<int> cadenceDays = GeneratedColumn<int>(
    'cadence_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (cadence_days IS NULL OR cadence_days > 0)',
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 500),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    vehicleId,
    name,
    cadenceKm,
    cadenceDays,
    enabled,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'maintenance_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaintenanceRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cadence_km')) {
      context.handle(
        _cadenceKmMeta,
        cadenceKm.isAcceptableOrUnknown(data['cadence_km']!, _cadenceKmMeta),
      );
    }
    if (data.containsKey('cadence_days')) {
      context.handle(
        _cadenceDaysMeta,
        cadenceDays.isAcceptableOrUnknown(
          data['cadence_days']!,
          _cadenceDaysMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaintenanceRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaintenanceRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cadenceKm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cadence_km'],
      ),
      cadenceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cadence_days'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $MaintenanceRulesTable createAlias(String alias) {
    return $MaintenanceRulesTable(attachedDatabase, alias);
  }
}

class MaintenanceRuleRow extends DataClass
    implements Insertable<MaintenanceRuleRow> {
  /// Client-generated UUIDv4 at creation; primary key.
  final String id;

  /// Server-assigned. Nullable on-device until the first successful
  /// server hydrate so rows inserted while offline still satisfy
  /// NOT NULL once the outbox drains.
  final String? userId;

  /// Server-assigned from `cestovni_row_version_seq`. Nullable on-device
  /// until first hydrate (ADR 002: "never written by the client").
  final int? rowVersion;

  /// Local/server wall-clock for human readability only (ISO-8601 UTC).
  final String updatedAt;

  /// Soft-delete marker; NULL when live.
  final String? deletedAt;

  /// Last idempotency key that touched the row; server dedupes retries.
  final String mutationId;
  final String vehicleId;
  final String name;

  /// Canonical meters.
  final int? cadenceKm;
  final int? cadenceDays;
  final bool enabled;
  final String? notes;
  const MaintenanceRuleRow({
    required this.id,
    this.userId,
    this.rowVersion,
    required this.updatedAt,
    this.deletedAt,
    required this.mutationId,
    required this.vehicleId,
    required this.name,
    this.cadenceKm,
    this.cadenceDays,
    required this.enabled,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || rowVersion != null) {
      map['row_version'] = Variable<int>(rowVersion);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['mutation_id'] = Variable<String>(mutationId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || cadenceKm != null) {
      map['cadence_km'] = Variable<int>(cadenceKm);
    }
    if (!nullToAbsent || cadenceDays != null) {
      map['cadence_days'] = Variable<int>(cadenceDays);
    }
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  MaintenanceRulesCompanion toCompanion(bool nullToAbsent) {
    return MaintenanceRulesCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      rowVersion: rowVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(rowVersion),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      mutationId: Value(mutationId),
      vehicleId: Value(vehicleId),
      name: Value(name),
      cadenceKm: cadenceKm == null && nullToAbsent
          ? const Value.absent()
          : Value(cadenceKm),
      cadenceDays: cadenceDays == null && nullToAbsent
          ? const Value.absent()
          : Value(cadenceDays),
      enabled: Value(enabled),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory MaintenanceRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaintenanceRuleRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      rowVersion: serializer.fromJson<int?>(json['rowVersion']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      name: serializer.fromJson<String>(json['name']),
      cadenceKm: serializer.fromJson<int?>(json['cadenceKm']),
      cadenceDays: serializer.fromJson<int?>(json['cadenceDays']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'rowVersion': serializer.toJson<int?>(rowVersion),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'mutationId': serializer.toJson<String>(mutationId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'name': serializer.toJson<String>(name),
      'cadenceKm': serializer.toJson<int?>(cadenceKm),
      'cadenceDays': serializer.toJson<int?>(cadenceDays),
      'enabled': serializer.toJson<bool>(enabled),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  MaintenanceRuleRow copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<int?> rowVersion = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    String? mutationId,
    String? vehicleId,
    String? name,
    Value<int?> cadenceKm = const Value.absent(),
    Value<int?> cadenceDays = const Value.absent(),
    bool? enabled,
    Value<String?> notes = const Value.absent(),
  }) => MaintenanceRuleRow(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    rowVersion: rowVersion.present ? rowVersion.value : this.rowVersion,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    mutationId: mutationId ?? this.mutationId,
    vehicleId: vehicleId ?? this.vehicleId,
    name: name ?? this.name,
    cadenceKm: cadenceKm.present ? cadenceKm.value : this.cadenceKm,
    cadenceDays: cadenceDays.present ? cadenceDays.value : this.cadenceDays,
    enabled: enabled ?? this.enabled,
    notes: notes.present ? notes.value : this.notes,
  );
  MaintenanceRuleRow copyWithCompanion(MaintenanceRulesCompanion data) {
    return MaintenanceRuleRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      name: data.name.present ? data.name.value : this.name,
      cadenceKm: data.cadenceKm.present ? data.cadenceKm.value : this.cadenceKm,
      cadenceDays: data.cadenceDays.present
          ? data.cadenceDays.value
          : this.cadenceDays,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceRuleRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('cadenceKm: $cadenceKm, ')
          ..write('cadenceDays: $cadenceDays, ')
          ..write('enabled: $enabled, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    vehicleId,
    name,
    cadenceKm,
    cadenceDays,
    enabled,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaintenanceRuleRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.rowVersion == this.rowVersion &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.mutationId == this.mutationId &&
          other.vehicleId == this.vehicleId &&
          other.name == this.name &&
          other.cadenceKm == this.cadenceKm &&
          other.cadenceDays == this.cadenceDays &&
          other.enabled == this.enabled &&
          other.notes == this.notes);
}

class MaintenanceRulesCompanion extends UpdateCompanion<MaintenanceRuleRow> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<int?> rowVersion;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> mutationId;
  final Value<String> vehicleId;
  final Value<String> name;
  final Value<int?> cadenceKm;
  final Value<int?> cadenceDays;
  final Value<bool> enabled;
  final Value<String?> notes;
  final Value<int> rowid;
  const MaintenanceRulesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.name = const Value.absent(),
    this.cadenceKm = const Value.absent(),
    this.cadenceDays = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MaintenanceRulesCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required String mutationId,
    required String vehicleId,
    required String name,
    this.cadenceKm = const Value.absent(),
    this.cadenceDays = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       mutationId = Value(mutationId),
       vehicleId = Value(vehicleId),
       name = Value(name);
  static Insertable<MaintenanceRuleRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<int>? rowVersion,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? mutationId,
    Expression<String>? vehicleId,
    Expression<String>? name,
    Expression<int>? cadenceKm,
    Expression<int>? cadenceDays,
    Expression<bool>? enabled,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (rowVersion != null) 'row_version': rowVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (mutationId != null) 'mutation_id': mutationId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (name != null) 'name': name,
      if (cadenceKm != null) 'cadence_km': cadenceKm,
      if (cadenceDays != null) 'cadence_days': cadenceDays,
      if (enabled != null) 'enabled': enabled,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MaintenanceRulesCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<int?>? rowVersion,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? mutationId,
    Value<String>? vehicleId,
    Value<String>? name,
    Value<int?>? cadenceKm,
    Value<int?>? cadenceDays,
    Value<bool>? enabled,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return MaintenanceRulesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rowVersion: rowVersion ?? this.rowVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      mutationId: mutationId ?? this.mutationId,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      cadenceKm: cadenceKm ?? this.cadenceKm,
      cadenceDays: cadenceDays ?? this.cadenceDays,
      enabled: enabled ?? this.enabled,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cadenceKm.present) {
      map['cadence_km'] = Variable<int>(cadenceKm.value);
    }
    if (cadenceDays.present) {
      map['cadence_days'] = Variable<int>(cadenceDays.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceRulesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('cadenceKm: $cadenceKm, ')
          ..write('cadenceDays: $cadenceDays, ')
          ..write('enabled: $enabled, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MaintenanceEventsTable extends MaintenanceEvents
    with TableInfo<$MaintenanceEventsTable, MaintenanceEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaintenanceEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id)',
    ),
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<String> ruleId = GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES maintenance_rules (id)',
    ),
  );
  static const VerificationMeta _performedAtMeta = const VerificationMeta(
    'performedAt',
  );
  @override
  late final GeneratedColumn<String> performedAt = GeneratedColumn<String>(
    'performed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMMeta = const VerificationMeta(
    'odometerM',
  );
  @override
  late final GeneratedColumn<int> odometerM = GeneratedColumn<int>(
    'odometer_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (odometer_m IS NULL OR odometer_m >= 0)',
  );
  static const VerificationMeta _costCentsMeta = const VerificationMeta(
    'costCents',
  );
  @override
  late final GeneratedColumn<int> costCents = GeneratedColumn<int>(
    'cost_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (cost_cents >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (currency_code GLOB \'[A-Z][A-Z][A-Z]\')',
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'other\' CHECK (category IN (\'oil\',\'tires\',\'brakes\',\'inspection\',\'battery\',\'fluid\',\'other\'))',
    defaultValue: const CustomExpression('\'other\''),
  );
  static const VerificationMeta _shopMeta = const VerificationMeta('shop');
  @override
  late final GeneratedColumn<String> shop = GeneratedColumn<String>(
    'shop',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (shop IS NULL OR length(shop) BETWEEN 1 AND 120)',
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 500),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    vehicleId,
    ruleId,
    performedAt,
    odometerM,
    costCents,
    currencyCode,
    category,
    shop,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'maintenance_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaintenanceEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    }
    if (data.containsKey('performed_at')) {
      context.handle(
        _performedAtMeta,
        performedAt.isAcceptableOrUnknown(
          data['performed_at']!,
          _performedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_performedAtMeta);
    }
    if (data.containsKey('odometer_m')) {
      context.handle(
        _odometerMMeta,
        odometerM.isAcceptableOrUnknown(data['odometer_m']!, _odometerMMeta),
      );
    }
    if (data.containsKey('cost_cents')) {
      context.handle(
        _costCentsMeta,
        costCents.isAcceptableOrUnknown(data['cost_cents']!, _costCentsMeta),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('shop')) {
      context.handle(
        _shopMeta,
        shop.isAcceptableOrUnknown(data['shop']!, _shopMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaintenanceEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaintenanceEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      ),
      performedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}performed_at'],
      )!,
      odometerM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}odometer_m'],
      ),
      costCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_cents'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      shop: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $MaintenanceEventsTable createAlias(String alias) {
    return $MaintenanceEventsTable(attachedDatabase, alias);
  }
}

class MaintenanceEventRow extends DataClass
    implements Insertable<MaintenanceEventRow> {
  /// Client-generated UUIDv4 at creation; primary key.
  final String id;

  /// Server-assigned. Nullable on-device until the first successful
  /// server hydrate so rows inserted while offline still satisfy
  /// NOT NULL once the outbox drains.
  final String? userId;

  /// Server-assigned from `cestovni_row_version_seq`. Nullable on-device
  /// until first hydrate (ADR 002: "never written by the client").
  final int? rowVersion;

  /// Local/server wall-clock for human readability only (ISO-8601 UTC).
  final String updatedAt;

  /// Soft-delete marker; NULL when live.
  final String? deletedAt;

  /// Last idempotency key that touched the row; server dedupes retries.
  final String mutationId;
  final String vehicleId;

  /// Nullable — one-off events are allowed (no rule attached).
  final String? ruleId;
  final String performedAt;

  /// Optional. UX allows leaving odometer blank on maintenance entries
  /// (oil change at the shop with no dashboard reading at hand).
  /// Cost stays mandatory at the schema level — the form writes 0 when
  /// the user leaves it empty (DATA_CONTRACTS.md §Maintenance). See
  /// [CES-53](https://linear.app/personal-interests-llc/issue/CES-53).
  final int? odometerM;
  final int costCents;
  final String currencyCode;

  /// Maintenance category. Closed enum mirrored in DATA_CONTRACTS.md
  /// so the form and the metrics bucketing stay in lockstep. Added in
  /// schema v2 with a `'other'` default so v1 rows round-trip cleanly
  /// through the 0002 migration.
  final String category;

  /// Optional shop / vendor name (free text). Added in v2.
  final String? shop;
  final String? notes;
  const MaintenanceEventRow({
    required this.id,
    this.userId,
    this.rowVersion,
    required this.updatedAt,
    this.deletedAt,
    required this.mutationId,
    required this.vehicleId,
    this.ruleId,
    required this.performedAt,
    this.odometerM,
    required this.costCents,
    required this.currencyCode,
    required this.category,
    this.shop,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || rowVersion != null) {
      map['row_version'] = Variable<int>(rowVersion);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['mutation_id'] = Variable<String>(mutationId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    if (!nullToAbsent || ruleId != null) {
      map['rule_id'] = Variable<String>(ruleId);
    }
    map['performed_at'] = Variable<String>(performedAt);
    if (!nullToAbsent || odometerM != null) {
      map['odometer_m'] = Variable<int>(odometerM);
    }
    map['cost_cents'] = Variable<int>(costCents);
    map['currency_code'] = Variable<String>(currencyCode);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || shop != null) {
      map['shop'] = Variable<String>(shop);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  MaintenanceEventsCompanion toCompanion(bool nullToAbsent) {
    return MaintenanceEventsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      rowVersion: rowVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(rowVersion),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      mutationId: Value(mutationId),
      vehicleId: Value(vehicleId),
      ruleId: ruleId == null && nullToAbsent
          ? const Value.absent()
          : Value(ruleId),
      performedAt: Value(performedAt),
      odometerM: odometerM == null && nullToAbsent
          ? const Value.absent()
          : Value(odometerM),
      costCents: Value(costCents),
      currencyCode: Value(currencyCode),
      category: Value(category),
      shop: shop == null && nullToAbsent ? const Value.absent() : Value(shop),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory MaintenanceEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaintenanceEventRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      rowVersion: serializer.fromJson<int?>(json['rowVersion']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      ruleId: serializer.fromJson<String?>(json['ruleId']),
      performedAt: serializer.fromJson<String>(json['performedAt']),
      odometerM: serializer.fromJson<int?>(json['odometerM']),
      costCents: serializer.fromJson<int>(json['costCents']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      category: serializer.fromJson<String>(json['category']),
      shop: serializer.fromJson<String?>(json['shop']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'rowVersion': serializer.toJson<int?>(rowVersion),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'mutationId': serializer.toJson<String>(mutationId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'ruleId': serializer.toJson<String?>(ruleId),
      'performedAt': serializer.toJson<String>(performedAt),
      'odometerM': serializer.toJson<int?>(odometerM),
      'costCents': serializer.toJson<int>(costCents),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'category': serializer.toJson<String>(category),
      'shop': serializer.toJson<String?>(shop),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  MaintenanceEventRow copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<int?> rowVersion = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    String? mutationId,
    String? vehicleId,
    Value<String?> ruleId = const Value.absent(),
    String? performedAt,
    Value<int?> odometerM = const Value.absent(),
    int? costCents,
    String? currencyCode,
    String? category,
    Value<String?> shop = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => MaintenanceEventRow(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    rowVersion: rowVersion.present ? rowVersion.value : this.rowVersion,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    mutationId: mutationId ?? this.mutationId,
    vehicleId: vehicleId ?? this.vehicleId,
    ruleId: ruleId.present ? ruleId.value : this.ruleId,
    performedAt: performedAt ?? this.performedAt,
    odometerM: odometerM.present ? odometerM.value : this.odometerM,
    costCents: costCents ?? this.costCents,
    currencyCode: currencyCode ?? this.currencyCode,
    category: category ?? this.category,
    shop: shop.present ? shop.value : this.shop,
    notes: notes.present ? notes.value : this.notes,
  );
  MaintenanceEventRow copyWithCompanion(MaintenanceEventsCompanion data) {
    return MaintenanceEventRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      performedAt: data.performedAt.present
          ? data.performedAt.value
          : this.performedAt,
      odometerM: data.odometerM.present ? data.odometerM.value : this.odometerM,
      costCents: data.costCents.present ? data.costCents.value : this.costCents,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      category: data.category.present ? data.category.value : this.category,
      shop: data.shop.present ? data.shop.value : this.shop,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceEventRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('ruleId: $ruleId, ')
          ..write('performedAt: $performedAt, ')
          ..write('odometerM: $odometerM, ')
          ..write('costCents: $costCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('category: $category, ')
          ..write('shop: $shop, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    vehicleId,
    ruleId,
    performedAt,
    odometerM,
    costCents,
    currencyCode,
    category,
    shop,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaintenanceEventRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.rowVersion == this.rowVersion &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.mutationId == this.mutationId &&
          other.vehicleId == this.vehicleId &&
          other.ruleId == this.ruleId &&
          other.performedAt == this.performedAt &&
          other.odometerM == this.odometerM &&
          other.costCents == this.costCents &&
          other.currencyCode == this.currencyCode &&
          other.category == this.category &&
          other.shop == this.shop &&
          other.notes == this.notes);
}

class MaintenanceEventsCompanion extends UpdateCompanion<MaintenanceEventRow> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<int?> rowVersion;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> mutationId;
  final Value<String> vehicleId;
  final Value<String?> ruleId;
  final Value<String> performedAt;
  final Value<int?> odometerM;
  final Value<int> costCents;
  final Value<String> currencyCode;
  final Value<String> category;
  final Value<String?> shop;
  final Value<String?> notes;
  final Value<int> rowid;
  const MaintenanceEventsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.performedAt = const Value.absent(),
    this.odometerM = const Value.absent(),
    this.costCents = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.category = const Value.absent(),
    this.shop = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MaintenanceEventsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required String mutationId,
    required String vehicleId,
    this.ruleId = const Value.absent(),
    required String performedAt,
    this.odometerM = const Value.absent(),
    this.costCents = const Value.absent(),
    required String currencyCode,
    this.category = const Value.absent(),
    this.shop = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       mutationId = Value(mutationId),
       vehicleId = Value(vehicleId),
       performedAt = Value(performedAt),
       currencyCode = Value(currencyCode);
  static Insertable<MaintenanceEventRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<int>? rowVersion,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? mutationId,
    Expression<String>? vehicleId,
    Expression<String>? ruleId,
    Expression<String>? performedAt,
    Expression<int>? odometerM,
    Expression<int>? costCents,
    Expression<String>? currencyCode,
    Expression<String>? category,
    Expression<String>? shop,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (rowVersion != null) 'row_version': rowVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (mutationId != null) 'mutation_id': mutationId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (ruleId != null) 'rule_id': ruleId,
      if (performedAt != null) 'performed_at': performedAt,
      if (odometerM != null) 'odometer_m': odometerM,
      if (costCents != null) 'cost_cents': costCents,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (category != null) 'category': category,
      if (shop != null) 'shop': shop,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MaintenanceEventsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<int?>? rowVersion,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? mutationId,
    Value<String>? vehicleId,
    Value<String?>? ruleId,
    Value<String>? performedAt,
    Value<int?>? odometerM,
    Value<int>? costCents,
    Value<String>? currencyCode,
    Value<String>? category,
    Value<String?>? shop,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return MaintenanceEventsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rowVersion: rowVersion ?? this.rowVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      mutationId: mutationId ?? this.mutationId,
      vehicleId: vehicleId ?? this.vehicleId,
      ruleId: ruleId ?? this.ruleId,
      performedAt: performedAt ?? this.performedAt,
      odometerM: odometerM ?? this.odometerM,
      costCents: costCents ?? this.costCents,
      currencyCode: currencyCode ?? this.currencyCode,
      category: category ?? this.category,
      shop: shop ?? this.shop,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<String>(ruleId.value);
    }
    if (performedAt.present) {
      map['performed_at'] = Variable<String>(performedAt.value);
    }
    if (odometerM.present) {
      map['odometer_m'] = Variable<int>(odometerM.value);
    }
    if (costCents.present) {
      map['cost_cents'] = Variable<int>(costCents.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (shop.present) {
      map['shop'] = Variable<String>(shop.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceEventsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('ruleId: $ruleId, ')
          ..write('performedAt: $performedAt, ')
          ..write('odometerM: $odometerM, ')
          ..write('costCents: $costCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('category: $category, ')
          ..write('shop: $shop, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preferredDistanceUnitMeta =
      const VerificationMeta('preferredDistanceUnit');
  @override
  late final GeneratedColumn<String> preferredDistanceUnit =
      GeneratedColumn<String>(
        'preferred_distance_unit',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints:
            'NOT NULL CHECK (preferred_distance_unit IN (\'km\',\'mi\'))',
      );
  static const VerificationMeta _preferredVolumeUnitMeta =
      const VerificationMeta('preferredVolumeUnit');
  @override
  late final GeneratedColumn<String> preferredVolumeUnit =
      GeneratedColumn<String>(
        'preferred_volume_unit',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints:
            'NOT NULL CHECK (preferred_volume_unit IN (\'L\',\'gal\'))',
      );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (currency_code GLOB \'[A-Z][A-Z][A-Z]\')',
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    preferredDistanceUnit,
    preferredVolumeUnit,
    currencyCode,
    timezone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('preferred_distance_unit')) {
      context.handle(
        _preferredDistanceUnitMeta,
        preferredDistanceUnit.isAcceptableOrUnknown(
          data['preferred_distance_unit']!,
          _preferredDistanceUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preferredDistanceUnitMeta);
    }
    if (data.containsKey('preferred_volume_unit')) {
      context.handle(
        _preferredVolumeUnitMeta,
        preferredVolumeUnit.isAcceptableOrUnknown(
          data['preferred_volume_unit']!,
          _preferredVolumeUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preferredVolumeUnitMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      preferredDistanceUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_distance_unit'],
      )!,
      preferredVolumeUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_volume_unit'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  /// Client-generated UUIDv4 at creation; primary key.
  final String id;

  /// Server-assigned. Nullable on-device until the first successful
  /// server hydrate so rows inserted while offline still satisfy
  /// NOT NULL once the outbox drains.
  final String? userId;

  /// Server-assigned from `cestovni_row_version_seq`. Nullable on-device
  /// until first hydrate (ADR 002: "never written by the client").
  final int? rowVersion;

  /// Local/server wall-clock for human readability only (ISO-8601 UTC).
  final String updatedAt;

  /// Soft-delete marker; NULL when live.
  final String? deletedAt;

  /// Last idempotency key that touched the row; server dedupes retries.
  final String mutationId;
  final String preferredDistanceUnit;
  final String preferredVolumeUnit;
  final String currencyCode;
  final String timezone;
  const SettingsRow({
    required this.id,
    this.userId,
    this.rowVersion,
    required this.updatedAt,
    this.deletedAt,
    required this.mutationId,
    required this.preferredDistanceUnit,
    required this.preferredVolumeUnit,
    required this.currencyCode,
    required this.timezone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || rowVersion != null) {
      map['row_version'] = Variable<int>(rowVersion);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['mutation_id'] = Variable<String>(mutationId);
    map['preferred_distance_unit'] = Variable<String>(preferredDistanceUnit);
    map['preferred_volume_unit'] = Variable<String>(preferredVolumeUnit);
    map['currency_code'] = Variable<String>(currencyCode);
    map['timezone'] = Variable<String>(timezone);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      rowVersion: rowVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(rowVersion),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      mutationId: Value(mutationId),
      preferredDistanceUnit: Value(preferredDistanceUnit),
      preferredVolumeUnit: Value(preferredVolumeUnit),
      currencyCode: Value(currencyCode),
      timezone: Value(timezone),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      rowVersion: serializer.fromJson<int?>(json['rowVersion']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      preferredDistanceUnit: serializer.fromJson<String>(
        json['preferredDistanceUnit'],
      ),
      preferredVolumeUnit: serializer.fromJson<String>(
        json['preferredVolumeUnit'],
      ),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      timezone: serializer.fromJson<String>(json['timezone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'rowVersion': serializer.toJson<int?>(rowVersion),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'mutationId': serializer.toJson<String>(mutationId),
      'preferredDistanceUnit': serializer.toJson<String>(preferredDistanceUnit),
      'preferredVolumeUnit': serializer.toJson<String>(preferredVolumeUnit),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'timezone': serializer.toJson<String>(timezone),
    };
  }

  SettingsRow copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<int?> rowVersion = const Value.absent(),
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
    String? mutationId,
    String? preferredDistanceUnit,
    String? preferredVolumeUnit,
    String? currencyCode,
    String? timezone,
  }) => SettingsRow(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    rowVersion: rowVersion.present ? rowVersion.value : this.rowVersion,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    mutationId: mutationId ?? this.mutationId,
    preferredDistanceUnit: preferredDistanceUnit ?? this.preferredDistanceUnit,
    preferredVolumeUnit: preferredVolumeUnit ?? this.preferredVolumeUnit,
    currencyCode: currencyCode ?? this.currencyCode,
    timezone: timezone ?? this.timezone,
  );
  SettingsRow copyWithCompanion(AppSettingsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      preferredDistanceUnit: data.preferredDistanceUnit.present
          ? data.preferredDistanceUnit.value
          : this.preferredDistanceUnit,
      preferredVolumeUnit: data.preferredVolumeUnit.present
          ? data.preferredVolumeUnit.value
          : this.preferredVolumeUnit,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('preferredDistanceUnit: $preferredDistanceUnit, ')
          ..write('preferredVolumeUnit: $preferredVolumeUnit, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('timezone: $timezone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    rowVersion,
    updatedAt,
    deletedAt,
    mutationId,
    preferredDistanceUnit,
    preferredVolumeUnit,
    currencyCode,
    timezone,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.rowVersion == this.rowVersion &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.mutationId == this.mutationId &&
          other.preferredDistanceUnit == this.preferredDistanceUnit &&
          other.preferredVolumeUnit == this.preferredVolumeUnit &&
          other.currencyCode == this.currencyCode &&
          other.timezone == this.timezone);
}

class AppSettingsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<int?> rowVersion;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> mutationId;
  final Value<String> preferredDistanceUnit;
  final Value<String> preferredVolumeUnit;
  final Value<String> currencyCode;
  final Value<String> timezone;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.preferredDistanceUnit = const Value.absent(),
    this.preferredVolumeUnit = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.timezone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.rowVersion = const Value.absent(),
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    required String mutationId,
    required String preferredDistanceUnit,
    required String preferredVolumeUnit,
    required String currencyCode,
    required String timezone,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt),
       mutationId = Value(mutationId),
       preferredDistanceUnit = Value(preferredDistanceUnit),
       preferredVolumeUnit = Value(preferredVolumeUnit),
       currencyCode = Value(currencyCode),
       timezone = Value(timezone);
  static Insertable<SettingsRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<int>? rowVersion,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? mutationId,
    Expression<String>? preferredDistanceUnit,
    Expression<String>? preferredVolumeUnit,
    Expression<String>? currencyCode,
    Expression<String>? timezone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (rowVersion != null) 'row_version': rowVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (mutationId != null) 'mutation_id': mutationId,
      if (preferredDistanceUnit != null)
        'preferred_distance_unit': preferredDistanceUnit,
      if (preferredVolumeUnit != null)
        'preferred_volume_unit': preferredVolumeUnit,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (timezone != null) 'timezone': timezone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<int?>? rowVersion,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? mutationId,
    Value<String>? preferredDistanceUnit,
    Value<String>? preferredVolumeUnit,
    Value<String>? currencyCode,
    Value<String>? timezone,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rowVersion: rowVersion ?? this.rowVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      mutationId: mutationId ?? this.mutationId,
      preferredDistanceUnit:
          preferredDistanceUnit ?? this.preferredDistanceUnit,
      preferredVolumeUnit: preferredVolumeUnit ?? this.preferredVolumeUnit,
      currencyCode: currencyCode ?? this.currencyCode,
      timezone: timezone ?? this.timezone,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (preferredDistanceUnit.present) {
      map['preferred_distance_unit'] = Variable<String>(
        preferredDistanceUnit.value,
      );
    }
    if (preferredVolumeUnit.present) {
      map['preferred_volume_unit'] = Variable<String>(
        preferredVolumeUnit.value,
      );
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('mutationId: $mutationId, ')
          ..write('preferredDistanceUnit: $preferredDistanceUnit, ')
          ..write('preferredVolumeUnit: $preferredVolumeUnit, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('timezone: $timezone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, DraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filledAtMeta = const VerificationMeta(
    'filledAt',
  );
  @override
  late final GeneratedColumn<String> filledAt = GeneratedColumn<String>(
    'filled_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _odometerMMeta = const VerificationMeta(
    'odometerM',
  );
  @override
  late final GeneratedColumn<int> odometerM = GeneratedColumn<int>(
    'odometer_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (odometer_m IS NULL OR odometer_m >= 0)',
  );
  static const VerificationMeta _volumeULMeta = const VerificationMeta(
    'volumeUL',
  );
  @override
  late final GeneratedColumn<int> volumeUL = GeneratedColumn<int>(
    'volume_uL',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (volume_uL IS NULL OR volume_uL >= 0)',
  );
  static const VerificationMeta _totalPriceCentsMeta = const VerificationMeta(
    'totalPriceCents',
  );
  @override
  late final GeneratedColumn<int> totalPriceCents = GeneratedColumn<int>(
    'total_price_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (total_price_cents IS NULL OR total_price_cents >= 0)',
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFullMeta = const VerificationMeta('isFull');
  @override
  late final GeneratedColumn<int> isFull = GeneratedColumn<int>(
    'is_full',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missedBeforeMeta = const VerificationMeta(
    'missedBefore',
  );
  @override
  late final GeneratedColumn<int> missedBefore = GeneratedColumn<int>(
    'missed_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _odometerResetMeta = const VerificationMeta(
    'odometerReset',
  );
  @override
  late final GeneratedColumn<int> odometerReset = GeneratedColumn<int>(
    'odometer_reset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 500),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    createdAt,
    filledAt,
    odometerM,
    volumeUL,
    totalPriceCents,
    currencyCode,
    isFull,
    missedBefore,
    odometerReset,
    notes,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('filled_at')) {
      context.handle(
        _filledAtMeta,
        filledAt.isAcceptableOrUnknown(data['filled_at']!, _filledAtMeta),
      );
    }
    if (data.containsKey('odometer_m')) {
      context.handle(
        _odometerMMeta,
        odometerM.isAcceptableOrUnknown(data['odometer_m']!, _odometerMMeta),
      );
    }
    if (data.containsKey('volume_uL')) {
      context.handle(
        _volumeULMeta,
        volumeUL.isAcceptableOrUnknown(data['volume_uL']!, _volumeULMeta),
      );
    }
    if (data.containsKey('total_price_cents')) {
      context.handle(
        _totalPriceCentsMeta,
        totalPriceCents.isAcceptableOrUnknown(
          data['total_price_cents']!,
          _totalPriceCentsMeta,
        ),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('is_full')) {
      context.handle(
        _isFullMeta,
        isFull.isAcceptableOrUnknown(data['is_full']!, _isFullMeta),
      );
    }
    if (data.containsKey('missed_before')) {
      context.handle(
        _missedBeforeMeta,
        missedBefore.isAcceptableOrUnknown(
          data['missed_before']!,
          _missedBeforeMeta,
        ),
      );
    }
    if (data.containsKey('odometer_reset')) {
      context.handle(
        _odometerResetMeta,
        odometerReset.isAcceptableOrUnknown(
          data['odometer_reset']!,
          _odometerResetMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      filledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filled_at'],
      ),
      odometerM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}odometer_m'],
      ),
      volumeUL: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume_uL'],
      ),
      totalPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_price_cents'],
      ),
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      ),
      isFull: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_full'],
      ),
      missedBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}missed_before'],
      ),
      odometerReset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}odometer_reset'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class DraftRow extends DataClass implements Insertable<DraftRow> {
  final String id;
  final String? vehicleId;
  final String createdAt;
  final String? filledAt;
  final int? odometerM;
  final int? volumeUL;
  final int? totalPriceCents;
  final String? currencyCode;
  final int? isFull;
  final int? missedBefore;
  final int? odometerReset;
  final String? notes;

  /// Set when promoted; drives photo 7-day post-completion TTL.
  final String? completedAt;
  const DraftRow({
    required this.id,
    this.vehicleId,
    required this.createdAt,
    this.filledAt,
    this.odometerM,
    this.volumeUL,
    this.totalPriceCents,
    this.currencyCode,
    this.isFull,
    this.missedBefore,
    this.odometerReset,
    this.notes,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || vehicleId != null) {
      map['vehicle_id'] = Variable<String>(vehicleId);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || filledAt != null) {
      map['filled_at'] = Variable<String>(filledAt);
    }
    if (!nullToAbsent || odometerM != null) {
      map['odometer_m'] = Variable<int>(odometerM);
    }
    if (!nullToAbsent || volumeUL != null) {
      map['volume_uL'] = Variable<int>(volumeUL);
    }
    if (!nullToAbsent || totalPriceCents != null) {
      map['total_price_cents'] = Variable<int>(totalPriceCents);
    }
    if (!nullToAbsent || currencyCode != null) {
      map['currency_code'] = Variable<String>(currencyCode);
    }
    if (!nullToAbsent || isFull != null) {
      map['is_full'] = Variable<int>(isFull);
    }
    if (!nullToAbsent || missedBefore != null) {
      map['missed_before'] = Variable<int>(missedBefore);
    }
    if (!nullToAbsent || odometerReset != null) {
      map['odometer_reset'] = Variable<int>(odometerReset);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      vehicleId: vehicleId == null && nullToAbsent
          ? const Value.absent()
          : Value(vehicleId),
      createdAt: Value(createdAt),
      filledAt: filledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(filledAt),
      odometerM: odometerM == null && nullToAbsent
          ? const Value.absent()
          : Value(odometerM),
      volumeUL: volumeUL == null && nullToAbsent
          ? const Value.absent()
          : Value(volumeUL),
      totalPriceCents: totalPriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(totalPriceCents),
      currencyCode: currencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyCode),
      isFull: isFull == null && nullToAbsent
          ? const Value.absent()
          : Value(isFull),
      missedBefore: missedBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(missedBefore),
      odometerReset: odometerReset == null && nullToAbsent
          ? const Value.absent()
          : Value(odometerReset),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRow(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String?>(json['vehicleId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      filledAt: serializer.fromJson<String?>(json['filledAt']),
      odometerM: serializer.fromJson<int?>(json['odometerM']),
      volumeUL: serializer.fromJson<int?>(json['volumeUL']),
      totalPriceCents: serializer.fromJson<int?>(json['totalPriceCents']),
      currencyCode: serializer.fromJson<String?>(json['currencyCode']),
      isFull: serializer.fromJson<int?>(json['isFull']),
      missedBefore: serializer.fromJson<int?>(json['missedBefore']),
      odometerReset: serializer.fromJson<int?>(json['odometerReset']),
      notes: serializer.fromJson<String?>(json['notes']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String?>(vehicleId),
      'createdAt': serializer.toJson<String>(createdAt),
      'filledAt': serializer.toJson<String?>(filledAt),
      'odometerM': serializer.toJson<int?>(odometerM),
      'volumeUL': serializer.toJson<int?>(volumeUL),
      'totalPriceCents': serializer.toJson<int?>(totalPriceCents),
      'currencyCode': serializer.toJson<String?>(currencyCode),
      'isFull': serializer.toJson<int?>(isFull),
      'missedBefore': serializer.toJson<int?>(missedBefore),
      'odometerReset': serializer.toJson<int?>(odometerReset),
      'notes': serializer.toJson<String?>(notes),
      'completedAt': serializer.toJson<String?>(completedAt),
    };
  }

  DraftRow copyWith({
    String? id,
    Value<String?> vehicleId = const Value.absent(),
    String? createdAt,
    Value<String?> filledAt = const Value.absent(),
    Value<int?> odometerM = const Value.absent(),
    Value<int?> volumeUL = const Value.absent(),
    Value<int?> totalPriceCents = const Value.absent(),
    Value<String?> currencyCode = const Value.absent(),
    Value<int?> isFull = const Value.absent(),
    Value<int?> missedBefore = const Value.absent(),
    Value<int?> odometerReset = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> completedAt = const Value.absent(),
  }) => DraftRow(
    id: id ?? this.id,
    vehicleId: vehicleId.present ? vehicleId.value : this.vehicleId,
    createdAt: createdAt ?? this.createdAt,
    filledAt: filledAt.present ? filledAt.value : this.filledAt,
    odometerM: odometerM.present ? odometerM.value : this.odometerM,
    volumeUL: volumeUL.present ? volumeUL.value : this.volumeUL,
    totalPriceCents: totalPriceCents.present
        ? totalPriceCents.value
        : this.totalPriceCents,
    currencyCode: currencyCode.present ? currencyCode.value : this.currencyCode,
    isFull: isFull.present ? isFull.value : this.isFull,
    missedBefore: missedBefore.present ? missedBefore.value : this.missedBefore,
    odometerReset: odometerReset.present
        ? odometerReset.value
        : this.odometerReset,
    notes: notes.present ? notes.value : this.notes,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DraftRow copyWithCompanion(DraftsCompanion data) {
    return DraftRow(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      filledAt: data.filledAt.present ? data.filledAt.value : this.filledAt,
      odometerM: data.odometerM.present ? data.odometerM.value : this.odometerM,
      volumeUL: data.volumeUL.present ? data.volumeUL.value : this.volumeUL,
      totalPriceCents: data.totalPriceCents.present
          ? data.totalPriceCents.value
          : this.totalPriceCents,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      isFull: data.isFull.present ? data.isFull.value : this.isFull,
      missedBefore: data.missedBefore.present
          ? data.missedBefore.value
          : this.missedBefore,
      odometerReset: data.odometerReset.present
          ? data.odometerReset.value
          : this.odometerReset,
      notes: data.notes.present ? data.notes.value : this.notes,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRow(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('filledAt: $filledAt, ')
          ..write('odometerM: $odometerM, ')
          ..write('volumeUL: $volumeUL, ')
          ..write('totalPriceCents: $totalPriceCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('isFull: $isFull, ')
          ..write('missedBefore: $missedBefore, ')
          ..write('odometerReset: $odometerReset, ')
          ..write('notes: $notes, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    createdAt,
    filledAt,
    odometerM,
    volumeUL,
    totalPriceCents,
    currencyCode,
    isFull,
    missedBefore,
    odometerReset,
    notes,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRow &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.createdAt == this.createdAt &&
          other.filledAt == this.filledAt &&
          other.odometerM == this.odometerM &&
          other.volumeUL == this.volumeUL &&
          other.totalPriceCents == this.totalPriceCents &&
          other.currencyCode == this.currencyCode &&
          other.isFull == this.isFull &&
          other.missedBefore == this.missedBefore &&
          other.odometerReset == this.odometerReset &&
          other.notes == this.notes &&
          other.completedAt == this.completedAt);
}

class DraftsCompanion extends UpdateCompanion<DraftRow> {
  final Value<String> id;
  final Value<String?> vehicleId;
  final Value<String> createdAt;
  final Value<String?> filledAt;
  final Value<int?> odometerM;
  final Value<int?> volumeUL;
  final Value<int?> totalPriceCents;
  final Value<String?> currencyCode;
  final Value<int?> isFull;
  final Value<int?> missedBefore;
  final Value<int?> odometerReset;
  final Value<String?> notes;
  final Value<String?> completedAt;
  final Value<int> rowid;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.filledAt = const Value.absent(),
    this.odometerM = const Value.absent(),
    this.volumeUL = const Value.absent(),
    this.totalPriceCents = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.isFull = const Value.absent(),
    this.missedBefore = const Value.absent(),
    this.odometerReset = const Value.absent(),
    this.notes = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String id,
    this.vehicleId = const Value.absent(),
    required String createdAt,
    this.filledAt = const Value.absent(),
    this.odometerM = const Value.absent(),
    this.volumeUL = const Value.absent(),
    this.totalPriceCents = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.isFull = const Value.absent(),
    this.missedBefore = const Value.absent(),
    this.odometerReset = const Value.absent(),
    this.notes = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt);
  static Insertable<DraftRow> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? createdAt,
    Expression<String>? filledAt,
    Expression<int>? odometerM,
    Expression<int>? volumeUL,
    Expression<int>? totalPriceCents,
    Expression<String>? currencyCode,
    Expression<int>? isFull,
    Expression<int>? missedBefore,
    Expression<int>? odometerReset,
    Expression<String>? notes,
    Expression<String>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (createdAt != null) 'created_at': createdAt,
      if (filledAt != null) 'filled_at': filledAt,
      if (odometerM != null) 'odometer_m': odometerM,
      if (volumeUL != null) 'volume_uL': volumeUL,
      if (totalPriceCents != null) 'total_price_cents': totalPriceCents,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (isFull != null) 'is_full': isFull,
      if (missedBefore != null) 'missed_before': missedBefore,
      if (odometerReset != null) 'odometer_reset': odometerReset,
      if (notes != null) 'notes': notes,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? id,
    Value<String?>? vehicleId,
    Value<String>? createdAt,
    Value<String?>? filledAt,
    Value<int?>? odometerM,
    Value<int?>? volumeUL,
    Value<int?>? totalPriceCents,
    Value<String?>? currencyCode,
    Value<int?>? isFull,
    Value<int?>? missedBefore,
    Value<int?>? odometerReset,
    Value<String?>? notes,
    Value<String?>? completedAt,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      createdAt: createdAt ?? this.createdAt,
      filledAt: filledAt ?? this.filledAt,
      odometerM: odometerM ?? this.odometerM,
      volumeUL: volumeUL ?? this.volumeUL,
      totalPriceCents: totalPriceCents ?? this.totalPriceCents,
      currencyCode: currencyCode ?? this.currencyCode,
      isFull: isFull ?? this.isFull,
      missedBefore: missedBefore ?? this.missedBefore,
      odometerReset: odometerReset ?? this.odometerReset,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (filledAt.present) {
      map['filled_at'] = Variable<String>(filledAt.value);
    }
    if (odometerM.present) {
      map['odometer_m'] = Variable<int>(odometerM.value);
    }
    if (volumeUL.present) {
      map['volume_uL'] = Variable<int>(volumeUL.value);
    }
    if (totalPriceCents.present) {
      map['total_price_cents'] = Variable<int>(totalPriceCents.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (isFull.present) {
      map['is_full'] = Variable<int>(isFull.value);
    }
    if (missedBefore.present) {
      map['missed_before'] = Variable<int>(missedBefore.value);
    }
    if (odometerReset.present) {
      map['odometer_reset'] = Variable<int>(odometerReset.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('filledAt: $filledAt, ')
          ..write('odometerM: $odometerM, ')
          ..write('volumeUL: $volumeUL, ')
          ..write('totalPriceCents: $totalPriceCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('isFull: $isFull, ')
          ..write('missedBefore: $missedBefore, ')
          ..write('odometerReset: $odometerReset, ')
          ..write('notes: $notes, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _table_Meta = const VerificationMeta('table_');
  @override
  late final GeneratedColumn<String> table_ = GeneratedColumn<String>(
    'table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK ("table" IN (\'vehicles\',\'fill_ups\',\'maintenance_rules\',\'maintenance_events\',\'settings\'))',
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (op IN (\'insert\',\'update\',\'soft_delete\'))',
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enqueuedAtMeta = const VerificationMeta(
    'enqueuedAt',
  );
  @override
  late final GeneratedColumn<String> enqueuedAt = GeneratedColumn<String>(
    'enqueued_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mutationId,
    table_,
    op,
    rowId,
    payloadJson,
    enqueuedAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('table')) {
      context.handle(
        _table_Meta,
        table_.isAcceptableOrUnknown(data['table']!, _table_Meta),
      );
    } else if (isInserting) {
      context.missing(_table_Meta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('enqueued_at')) {
      context.handle(
        _enqueuedAtMeta,
        enqueuedAt.isAcceptableOrUnknown(data['enqueued_at']!, _enqueuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enqueuedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      table_: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      enqueuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enqueued_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int id;
  final String mutationId;
  final String table_;
  final String op;
  final String rowId;
  final String? payloadJson;
  final String enqueuedAt;
  final int attempts;
  final String? lastError;
  const OutboxRow({
    required this.id,
    required this.mutationId,
    required this.table_,
    required this.op,
    required this.rowId,
    this.payloadJson,
    required this.enqueuedAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mutation_id'] = Variable<String>(mutationId);
    map['table'] = Variable<String>(table_);
    map['op'] = Variable<String>(op);
    map['row_id'] = Variable<String>(rowId);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['enqueued_at'] = Variable<String>(enqueuedAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      mutationId: Value(mutationId),
      table_: Value(table_),
      op: Value(op),
      rowId: Value(rowId),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      enqueuedAt: Value(enqueuedAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      table_: serializer.fromJson<String>(json['table_']),
      op: serializer.fromJson<String>(json['op']),
      rowId: serializer.fromJson<String>(json['rowId']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      enqueuedAt: serializer.fromJson<String>(json['enqueuedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mutationId': serializer.toJson<String>(mutationId),
      'table_': serializer.toJson<String>(table_),
      'op': serializer.toJson<String>(op),
      'rowId': serializer.toJson<String>(rowId),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'enqueuedAt': serializer.toJson<String>(enqueuedAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? mutationId,
    String? table_,
    String? op,
    String? rowId,
    Value<String?> payloadJson = const Value.absent(),
    String? enqueuedAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxRow(
    id: id ?? this.id,
    mutationId: mutationId ?? this.mutationId,
    table_: table_ ?? this.table_,
    op: op ?? this.op,
    rowId: rowId ?? this.rowId,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      table_: data.table_.present ? data.table_.value : this.table_,
      op: data.op.present ? data.op.value : this.op,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      enqueuedAt: data.enqueuedAt.present
          ? data.enqueuedAt.value
          : this.enqueuedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('mutationId: $mutationId, ')
          ..write('table_: $table_, ')
          ..write('op: $op, ')
          ..write('rowId: $rowId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mutationId,
    table_,
    op,
    rowId,
    payloadJson,
    enqueuedAt,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.mutationId == this.mutationId &&
          other.table_ == this.table_ &&
          other.op == this.op &&
          other.rowId == this.rowId &&
          other.payloadJson == this.payloadJson &&
          other.enqueuedAt == this.enqueuedAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> mutationId;
  final Value<String> table_;
  final Value<String> op;
  final Value<String> rowId;
  final Value<String?> payloadJson;
  final Value<String> enqueuedAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.table_ = const Value.absent(),
    this.op = const Value.absent(),
    this.rowId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.enqueuedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String mutationId,
    required String table_,
    required String op,
    required String rowId,
    this.payloadJson = const Value.absent(),
    required String enqueuedAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : mutationId = Value(mutationId),
       table_ = Value(table_),
       op = Value(op),
       rowId = Value(rowId),
       enqueuedAt = Value(enqueuedAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? mutationId,
    Expression<String>? table_,
    Expression<String>? op,
    Expression<String>? rowId,
    Expression<String>? payloadJson,
    Expression<String>? enqueuedAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mutationId != null) 'mutation_id': mutationId,
      if (table_ != null) 'table': table_,
      if (op != null) 'op': op,
      if (rowId != null) 'row_id': rowId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (enqueuedAt != null) 'enqueued_at': enqueuedAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? mutationId,
    Value<String>? table_,
    Value<String>? op,
    Value<String>? rowId,
    Value<String?>? payloadJson,
    Value<String>? enqueuedAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      mutationId: mutationId ?? this.mutationId,
      table_: table_ ?? this.table_,
      op: op ?? this.op,
      rowId: rowId ?? this.rowId,
      payloadJson: payloadJson ?? this.payloadJson,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (table_.present) {
      map['table'] = Variable<String>(table_.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (enqueuedAt.present) {
      map['enqueued_at'] = Variable<String>(enqueuedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('mutationId: $mutationId, ')
          ..write('table_: $table_, ')
          ..write('op: $op, ')
          ..write('rowId: $rowId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $PhotoRefsTable extends PhotoRefs
    with TableInfo<$PhotoRefsTable, PhotoRefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES drafts (id)',
    ),
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<String> capturedAt = GeneratedColumn<String>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (byte_size >= 0)',
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 64,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ttlExpiresAtMeta = const VerificationMeta(
    'ttlExpiresAt',
  );
  @override
  late final GeneratedColumn<String> ttlExpiresAt = GeneratedColumn<String>(
    'ttl_expires_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    draftId,
    capturedAt,
    byteSize,
    sha256,
    ttlExpiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoRefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('ttl_expires_at')) {
      context.handle(
        _ttlExpiresAtMeta,
        ttlExpiresAt.isAcceptableOrUnknown(
          data['ttl_expires_at']!,
          _ttlExpiresAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ttlExpiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoRefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoRefRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_at'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      ttlExpiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ttl_expires_at'],
      )!,
    );
  }

  @override
  $PhotoRefsTable createAlias(String alias) {
    return $PhotoRefsTable(attachedDatabase, alias);
  }
}

class PhotoRefRow extends DataClass implements Insertable<PhotoRefRow> {
  final String id;
  final String draftId;
  final String capturedAt;

  /// After compression.
  final int byteSize;

  /// Hex SHA-256; integrity check on read.
  final String sha256;

  /// `captured_at + 30d`, shortened to `min(now+7d, ttl_expires_at)` when
  /// the linked fill-up completes (photo-pipeline.md).
  final String ttlExpiresAt;
  const PhotoRefRow({
    required this.id,
    required this.draftId,
    required this.capturedAt,
    required this.byteSize,
    required this.sha256,
    required this.ttlExpiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['draft_id'] = Variable<String>(draftId);
    map['captured_at'] = Variable<String>(capturedAt);
    map['byte_size'] = Variable<int>(byteSize);
    map['sha256'] = Variable<String>(sha256);
    map['ttl_expires_at'] = Variable<String>(ttlExpiresAt);
    return map;
  }

  PhotoRefsCompanion toCompanion(bool nullToAbsent) {
    return PhotoRefsCompanion(
      id: Value(id),
      draftId: Value(draftId),
      capturedAt: Value(capturedAt),
      byteSize: Value(byteSize),
      sha256: Value(sha256),
      ttlExpiresAt: Value(ttlExpiresAt),
    );
  }

  factory PhotoRefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoRefRow(
      id: serializer.fromJson<String>(json['id']),
      draftId: serializer.fromJson<String>(json['draftId']),
      capturedAt: serializer.fromJson<String>(json['capturedAt']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      sha256: serializer.fromJson<String>(json['sha256']),
      ttlExpiresAt: serializer.fromJson<String>(json['ttlExpiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'draftId': serializer.toJson<String>(draftId),
      'capturedAt': serializer.toJson<String>(capturedAt),
      'byteSize': serializer.toJson<int>(byteSize),
      'sha256': serializer.toJson<String>(sha256),
      'ttlExpiresAt': serializer.toJson<String>(ttlExpiresAt),
    };
  }

  PhotoRefRow copyWith({
    String? id,
    String? draftId,
    String? capturedAt,
    int? byteSize,
    String? sha256,
    String? ttlExpiresAt,
  }) => PhotoRefRow(
    id: id ?? this.id,
    draftId: draftId ?? this.draftId,
    capturedAt: capturedAt ?? this.capturedAt,
    byteSize: byteSize ?? this.byteSize,
    sha256: sha256 ?? this.sha256,
    ttlExpiresAt: ttlExpiresAt ?? this.ttlExpiresAt,
  );
  PhotoRefRow copyWithCompanion(PhotoRefsCompanion data) {
    return PhotoRefRow(
      id: data.id.present ? data.id.value : this.id,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      ttlExpiresAt: data.ttlExpiresAt.present
          ? data.ttlExpiresAt.value
          : this.ttlExpiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRefRow(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('byteSize: $byteSize, ')
          ..write('sha256: $sha256, ')
          ..write('ttlExpiresAt: $ttlExpiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, draftId, capturedAt, byteSize, sha256, ttlExpiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoRefRow &&
          other.id == this.id &&
          other.draftId == this.draftId &&
          other.capturedAt == this.capturedAt &&
          other.byteSize == this.byteSize &&
          other.sha256 == this.sha256 &&
          other.ttlExpiresAt == this.ttlExpiresAt);
}

class PhotoRefsCompanion extends UpdateCompanion<PhotoRefRow> {
  final Value<String> id;
  final Value<String> draftId;
  final Value<String> capturedAt;
  final Value<int> byteSize;
  final Value<String> sha256;
  final Value<String> ttlExpiresAt;
  final Value<int> rowid;
  const PhotoRefsCompanion({
    this.id = const Value.absent(),
    this.draftId = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.ttlExpiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoRefsCompanion.insert({
    required String id,
    required String draftId,
    required String capturedAt,
    required int byteSize,
    required String sha256,
    required String ttlExpiresAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       draftId = Value(draftId),
       capturedAt = Value(capturedAt),
       byteSize = Value(byteSize),
       sha256 = Value(sha256),
       ttlExpiresAt = Value(ttlExpiresAt);
  static Insertable<PhotoRefRow> custom({
    Expression<String>? id,
    Expression<String>? draftId,
    Expression<String>? capturedAt,
    Expression<int>? byteSize,
    Expression<String>? sha256,
    Expression<String>? ttlExpiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (draftId != null) 'draft_id': draftId,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (byteSize != null) 'byte_size': byteSize,
      if (sha256 != null) 'sha256': sha256,
      if (ttlExpiresAt != null) 'ttl_expires_at': ttlExpiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoRefsCompanion copyWith({
    Value<String>? id,
    Value<String>? draftId,
    Value<String>? capturedAt,
    Value<int>? byteSize,
    Value<String>? sha256,
    Value<String>? ttlExpiresAt,
    Value<int>? rowid,
  }) {
    return PhotoRefsCompanion(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      capturedAt: capturedAt ?? this.capturedAt,
      byteSize: byteSize ?? this.byteSize,
      sha256: sha256 ?? this.sha256,
      ttlExpiresAt: ttlExpiresAt ?? this.ttlExpiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<String>(capturedAt.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (ttlExpiresAt.present) {
      map['ttl_expires_at'] = Variable<String>(ttlExpiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRefsCompanion(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('byteSize: $byteSize, ')
          ..write('sha256: $sha256, ')
          ..write('ttlExpiresAt: $ttlExpiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $FillUpsTable fillUps = $FillUpsTable(this);
  late final $MaintenanceRulesTable maintenanceRules = $MaintenanceRulesTable(
    this,
  );
  late final $MaintenanceEventsTable maintenanceEvents =
      $MaintenanceEventsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $PhotoRefsTable photoRefs = $PhotoRefsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vehicles,
    fillUps,
    maintenanceRules,
    maintenanceEvents,
    appSettings,
    drafts,
    outbox,
    photoRefs,
  ];
}

typedef $$VehiclesTableCreateCompanionBuilder =
    VehiclesCompanion Function({
      required String id,
      Value<String?> userId,
      Value<int?> rowVersion,
      required String updatedAt,
      Value<String?> deletedAt,
      required String mutationId,
      required String name,
      Value<String?> make,
      Value<String?> model,
      Value<int?> year,
      Value<String?> vin,
      required String fuelType,
      Value<int?> tankCapacityUL,
      Value<String?> archivedAt,
      Value<int> rowid,
    });
typedef $$VehiclesTableUpdateCompanionBuilder =
    VehiclesCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<int?> rowVersion,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<String> mutationId,
      Value<String> name,
      Value<String?> make,
      Value<String?> model,
      Value<int?> year,
      Value<String?> vin,
      Value<String> fuelType,
      Value<int?> tankCapacityUL,
      Value<String?> archivedAt,
      Value<int> rowid,
    });

final class $$VehiclesTableReferences
    extends BaseReferences<_$AppDatabase, $VehiclesTable, VehicleRow> {
  $$VehiclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FillUpsTable, List<FillUpRow>> _fillUpsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.fillUps,
    aliasName: $_aliasNameGenerator(db.vehicles.id, db.fillUps.vehicleId),
  );

  $$FillUpsTableProcessedTableManager get fillUpsRefs {
    final manager = $$FillUpsTableTableManager(
      $_db,
      $_db.fillUps,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_fillUpsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MaintenanceRulesTable, List<MaintenanceRuleRow>>
  _maintenanceRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.maintenanceRules,
    aliasName: $_aliasNameGenerator(
      db.vehicles.id,
      db.maintenanceRules.vehicleId,
    ),
  );

  $$MaintenanceRulesTableProcessedTableManager get maintenanceRulesRefs {
    final manager = $$MaintenanceRulesTableTableManager(
      $_db,
      $_db.maintenanceRules,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _maintenanceRulesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MaintenanceEventsTable, List<MaintenanceEventRow>>
  _maintenanceEventsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.maintenanceEvents,
        aliasName: $_aliasNameGenerator(
          db.vehicles.id,
          db.maintenanceEvents.vehicleId,
        ),
      );

  $$MaintenanceEventsTableProcessedTableManager get maintenanceEventsRefs {
    final manager = $$MaintenanceEventsTableTableManager(
      $_db,
      $_db.maintenanceEvents,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _maintenanceEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuelType => $composableBuilder(
    column: $table.fuelType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tankCapacityUL => $composableBuilder(
    column: $table.tankCapacityUL,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> fillUpsRefs(
    Expression<bool> Function($$FillUpsTableFilterComposer f) f,
  ) {
    final $$FillUpsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fillUps,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FillUpsTableFilterComposer(
            $db: $db,
            $table: $db.fillUps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> maintenanceRulesRefs(
    Expression<bool> Function($$MaintenanceRulesTableFilterComposer f) f,
  ) {
    final $$MaintenanceRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceRules,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceRulesTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> maintenanceEventsRefs(
    Expression<bool> Function($$MaintenanceEventsTableFilterComposer f) f,
  ) {
    final $$MaintenanceEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceEvents,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceEventsTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuelType => $composableBuilder(
    column: $table.fuelType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tankCapacityUL => $composableBuilder(
    column: $table.tankCapacityUL,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get vin =>
      $composableBuilder(column: $table.vin, builder: (column) => column);

  GeneratedColumn<String> get fuelType =>
      $composableBuilder(column: $table.fuelType, builder: (column) => column);

  GeneratedColumn<int> get tankCapacityUL => $composableBuilder(
    column: $table.tankCapacityUL,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  Expression<T> fillUpsRefs<T extends Object>(
    Expression<T> Function($$FillUpsTableAnnotationComposer a) f,
  ) {
    final $$FillUpsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fillUps,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FillUpsTableAnnotationComposer(
            $db: $db,
            $table: $db.fillUps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> maintenanceRulesRefs<T extends Object>(
    Expression<T> Function($$MaintenanceRulesTableAnnotationComposer a) f,
  ) {
    final $$MaintenanceRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceRules,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.maintenanceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> maintenanceEventsRefs<T extends Object>(
    Expression<T> Function($$MaintenanceEventsTableAnnotationComposer a) f,
  ) {
    final $$MaintenanceEventsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.maintenanceEvents,
          getReferencedColumn: (t) => t.vehicleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MaintenanceEventsTableAnnotationComposer(
                $db: $db,
                $table: $db.maintenanceEvents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          VehicleRow,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (VehicleRow, $$VehiclesTableReferences),
          VehicleRow,
          PrefetchHooks Function({
            bool fillUpsRefs,
            bool maintenanceRulesRefs,
            bool maintenanceEventsRefs,
          })
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> make = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> vin = const Value.absent(),
                Value<String> fuelType = const Value.absent(),
                Value<int?> tankCapacityUL = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                name: name,
                make: make,
                model: model,
                year: year,
                vin: vin,
                fuelType: fuelType,
                tankCapacityUL: tankCapacityUL,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required String mutationId,
                required String name,
                Value<String?> make = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> vin = const Value.absent(),
                required String fuelType,
                Value<int?> tankCapacityUL = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                name: name,
                make: make,
                model: model,
                year: year,
                vin: vin,
                fuelType: fuelType,
                tankCapacityUL: tankCapacityUL,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$VehiclesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                fillUpsRefs = false,
                maintenanceRulesRefs = false,
                maintenanceEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (fillUpsRefs) db.fillUps,
                    if (maintenanceRulesRefs) db.maintenanceRules,
                    if (maintenanceEventsRefs) db.maintenanceEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (fillUpsRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          FillUpRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._fillUpsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).fillUpsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (maintenanceRulesRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          MaintenanceRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._maintenanceRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).maintenanceRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (maintenanceEventsRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          MaintenanceEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._maintenanceEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).maintenanceEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      VehicleRow,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (VehicleRow, $$VehiclesTableReferences),
      VehicleRow,
      PrefetchHooks Function({
        bool fillUpsRefs,
        bool maintenanceRulesRefs,
        bool maintenanceEventsRefs,
      })
    >;
typedef $$FillUpsTableCreateCompanionBuilder =
    FillUpsCompanion Function({
      required String id,
      Value<String?> userId,
      Value<int?> rowVersion,
      required String updatedAt,
      Value<String?> deletedAt,
      required String mutationId,
      required String vehicleId,
      required String filledAt,
      required int odometerM,
      required int volumeUL,
      required int totalPriceCents,
      required String currencyCode,
      required bool isFull,
      Value<bool> missedBefore,
      Value<bool> odometerReset,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$FillUpsTableUpdateCompanionBuilder =
    FillUpsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<int?> rowVersion,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<String> mutationId,
      Value<String> vehicleId,
      Value<String> filledAt,
      Value<int> odometerM,
      Value<int> volumeUL,
      Value<int> totalPriceCents,
      Value<String> currencyCode,
      Value<bool> isFull,
      Value<bool> missedBefore,
      Value<bool> odometerReset,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$FillUpsTableReferences
    extends BaseReferences<_$AppDatabase, $FillUpsTable, FillUpRow> {
  $$FillUpsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) => db.vehicles
      .createAlias($_aliasNameGenerator(db.fillUps.vehicleId, db.vehicles.id));

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FillUpsTableFilterComposer
    extends Composer<_$AppDatabase, $FillUpsTable> {
  $$FillUpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filledAt => $composableBuilder(
    column: $table.filledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get odometerM => $composableBuilder(
    column: $table.odometerM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volumeUL => $composableBuilder(
    column: $table.volumeUL,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPriceCents => $composableBuilder(
    column: $table.totalPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFull => $composableBuilder(
    column: $table.isFull,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missedBefore => $composableBuilder(
    column: $table.missedBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get odometerReset => $composableBuilder(
    column: $table.odometerReset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FillUpsTableOrderingComposer
    extends Composer<_$AppDatabase, $FillUpsTable> {
  $$FillUpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filledAt => $composableBuilder(
    column: $table.filledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get odometerM => $composableBuilder(
    column: $table.odometerM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volumeUL => $composableBuilder(
    column: $table.volumeUL,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPriceCents => $composableBuilder(
    column: $table.totalPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFull => $composableBuilder(
    column: $table.isFull,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missedBefore => $composableBuilder(
    column: $table.missedBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get odometerReset => $composableBuilder(
    column: $table.odometerReset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FillUpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FillUpsTable> {
  $$FillUpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filledAt =>
      $composableBuilder(column: $table.filledAt, builder: (column) => column);

  GeneratedColumn<int> get odometerM =>
      $composableBuilder(column: $table.odometerM, builder: (column) => column);

  GeneratedColumn<int> get volumeUL =>
      $composableBuilder(column: $table.volumeUL, builder: (column) => column);

  GeneratedColumn<int> get totalPriceCents => $composableBuilder(
    column: $table.totalPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFull =>
      $composableBuilder(column: $table.isFull, builder: (column) => column);

  GeneratedColumn<bool> get missedBefore => $composableBuilder(
    column: $table.missedBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get odometerReset => $composableBuilder(
    column: $table.odometerReset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FillUpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FillUpsTable,
          FillUpRow,
          $$FillUpsTableFilterComposer,
          $$FillUpsTableOrderingComposer,
          $$FillUpsTableAnnotationComposer,
          $$FillUpsTableCreateCompanionBuilder,
          $$FillUpsTableUpdateCompanionBuilder,
          (FillUpRow, $$FillUpsTableReferences),
          FillUpRow,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$FillUpsTableTableManager(_$AppDatabase db, $FillUpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FillUpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FillUpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FillUpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> filledAt = const Value.absent(),
                Value<int> odometerM = const Value.absent(),
                Value<int> volumeUL = const Value.absent(),
                Value<int> totalPriceCents = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<bool> isFull = const Value.absent(),
                Value<bool> missedBefore = const Value.absent(),
                Value<bool> odometerReset = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FillUpsCompanion(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                vehicleId: vehicleId,
                filledAt: filledAt,
                odometerM: odometerM,
                volumeUL: volumeUL,
                totalPriceCents: totalPriceCents,
                currencyCode: currencyCode,
                isFull: isFull,
                missedBefore: missedBefore,
                odometerReset: odometerReset,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required String mutationId,
                required String vehicleId,
                required String filledAt,
                required int odometerM,
                required int volumeUL,
                required int totalPriceCents,
                required String currencyCode,
                required bool isFull,
                Value<bool> missedBefore = const Value.absent(),
                Value<bool> odometerReset = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FillUpsCompanion.insert(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                vehicleId: vehicleId,
                filledAt: filledAt,
                odometerM: odometerM,
                volumeUL: volumeUL,
                totalPriceCents: totalPriceCents,
                currencyCode: currencyCode,
                isFull: isFull,
                missedBefore: missedBefore,
                odometerReset: odometerReset,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FillUpsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (vehicleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.vehicleId,
                                referencedTable: $$FillUpsTableReferences
                                    ._vehicleIdTable(db),
                                referencedColumn: $$FillUpsTableReferences
                                    ._vehicleIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FillUpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FillUpsTable,
      FillUpRow,
      $$FillUpsTableFilterComposer,
      $$FillUpsTableOrderingComposer,
      $$FillUpsTableAnnotationComposer,
      $$FillUpsTableCreateCompanionBuilder,
      $$FillUpsTableUpdateCompanionBuilder,
      (FillUpRow, $$FillUpsTableReferences),
      FillUpRow,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$MaintenanceRulesTableCreateCompanionBuilder =
    MaintenanceRulesCompanion Function({
      required String id,
      Value<String?> userId,
      Value<int?> rowVersion,
      required String updatedAt,
      Value<String?> deletedAt,
      required String mutationId,
      required String vehicleId,
      required String name,
      Value<int?> cadenceKm,
      Value<int?> cadenceDays,
      Value<bool> enabled,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$MaintenanceRulesTableUpdateCompanionBuilder =
    MaintenanceRulesCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<int?> rowVersion,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<String> mutationId,
      Value<String> vehicleId,
      Value<String> name,
      Value<int?> cadenceKm,
      Value<int?> cadenceDays,
      Value<bool> enabled,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$MaintenanceRulesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MaintenanceRulesTable,
          MaintenanceRuleRow
        > {
  $$MaintenanceRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias(
        $_aliasNameGenerator(db.maintenanceRules.vehicleId, db.vehicles.id),
      );

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MaintenanceEventsTable, List<MaintenanceEventRow>>
  _maintenanceEventsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.maintenanceEvents,
        aliasName: $_aliasNameGenerator(
          db.maintenanceRules.id,
          db.maintenanceEvents.ruleId,
        ),
      );

  $$MaintenanceEventsTableProcessedTableManager get maintenanceEventsRefs {
    final manager = $$MaintenanceEventsTableTableManager(
      $_db,
      $_db.maintenanceEvents,
    ).filter((f) => f.ruleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _maintenanceEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MaintenanceRulesTableFilterComposer
    extends Composer<_$AppDatabase, $MaintenanceRulesTable> {
  $$MaintenanceRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cadenceKm => $composableBuilder(
    column: $table.cadenceKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> maintenanceEventsRefs(
    Expression<bool> Function($$MaintenanceEventsTableFilterComposer f) f,
  ) {
    final $$MaintenanceEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceEvents,
      getReferencedColumn: (t) => t.ruleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceEventsTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MaintenanceRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $MaintenanceRulesTable> {
  $$MaintenanceRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cadenceKm => $composableBuilder(
    column: $table.cadenceKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaintenanceRulesTable> {
  $$MaintenanceRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get cadenceKm =>
      $composableBuilder(column: $table.cadenceKm, builder: (column) => column);

  GeneratedColumn<int> get cadenceDays => $composableBuilder(
    column: $table.cadenceDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> maintenanceEventsRefs<T extends Object>(
    Expression<T> Function($$MaintenanceEventsTableAnnotationComposer a) f,
  ) {
    final $$MaintenanceEventsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.maintenanceEvents,
          getReferencedColumn: (t) => t.ruleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MaintenanceEventsTableAnnotationComposer(
                $db: $db,
                $table: $db.maintenanceEvents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MaintenanceRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaintenanceRulesTable,
          MaintenanceRuleRow,
          $$MaintenanceRulesTableFilterComposer,
          $$MaintenanceRulesTableOrderingComposer,
          $$MaintenanceRulesTableAnnotationComposer,
          $$MaintenanceRulesTableCreateCompanionBuilder,
          $$MaintenanceRulesTableUpdateCompanionBuilder,
          (MaintenanceRuleRow, $$MaintenanceRulesTableReferences),
          MaintenanceRuleRow,
          PrefetchHooks Function({bool vehicleId, bool maintenanceEventsRefs})
        > {
  $$MaintenanceRulesTableTableManager(
    _$AppDatabase db,
    $MaintenanceRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaintenanceRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaintenanceRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MaintenanceRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> cadenceKm = const Value.absent(),
                Value<int?> cadenceDays = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceRulesCompanion(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                vehicleId: vehicleId,
                name: name,
                cadenceKm: cadenceKm,
                cadenceDays: cadenceDays,
                enabled: enabled,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required String mutationId,
                required String vehicleId,
                required String name,
                Value<int?> cadenceKm = const Value.absent(),
                Value<int?> cadenceDays = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceRulesCompanion.insert(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                vehicleId: vehicleId,
                name: name,
                cadenceKm: cadenceKm,
                cadenceDays: cadenceDays,
                enabled: enabled,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MaintenanceRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({vehicleId = false, maintenanceEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (maintenanceEventsRefs) db.maintenanceEvents,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (vehicleId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.vehicleId,
                                    referencedTable:
                                        $$MaintenanceRulesTableReferences
                                            ._vehicleIdTable(db),
                                    referencedColumn:
                                        $$MaintenanceRulesTableReferences
                                            ._vehicleIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (maintenanceEventsRefs)
                        await $_getPrefetchedData<
                          MaintenanceRuleRow,
                          $MaintenanceRulesTable,
                          MaintenanceEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$MaintenanceRulesTableReferences
                              ._maintenanceEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MaintenanceRulesTableReferences(
                                db,
                                table,
                                p0,
                              ).maintenanceEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ruleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MaintenanceRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaintenanceRulesTable,
      MaintenanceRuleRow,
      $$MaintenanceRulesTableFilterComposer,
      $$MaintenanceRulesTableOrderingComposer,
      $$MaintenanceRulesTableAnnotationComposer,
      $$MaintenanceRulesTableCreateCompanionBuilder,
      $$MaintenanceRulesTableUpdateCompanionBuilder,
      (MaintenanceRuleRow, $$MaintenanceRulesTableReferences),
      MaintenanceRuleRow,
      PrefetchHooks Function({bool vehicleId, bool maintenanceEventsRefs})
    >;
typedef $$MaintenanceEventsTableCreateCompanionBuilder =
    MaintenanceEventsCompanion Function({
      required String id,
      Value<String?> userId,
      Value<int?> rowVersion,
      required String updatedAt,
      Value<String?> deletedAt,
      required String mutationId,
      required String vehicleId,
      Value<String?> ruleId,
      required String performedAt,
      Value<int?> odometerM,
      Value<int> costCents,
      required String currencyCode,
      Value<String> category,
      Value<String?> shop,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$MaintenanceEventsTableUpdateCompanionBuilder =
    MaintenanceEventsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<int?> rowVersion,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<String> mutationId,
      Value<String> vehicleId,
      Value<String?> ruleId,
      Value<String> performedAt,
      Value<int?> odometerM,
      Value<int> costCents,
      Value<String> currencyCode,
      Value<String> category,
      Value<String?> shop,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$MaintenanceEventsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MaintenanceEventsTable,
          MaintenanceEventRow
        > {
  $$MaintenanceEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias(
        $_aliasNameGenerator(db.maintenanceEvents.vehicleId, db.vehicles.id),
      );

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MaintenanceRulesTable _ruleIdTable(_$AppDatabase db) =>
      db.maintenanceRules.createAlias(
        $_aliasNameGenerator(
          db.maintenanceEvents.ruleId,
          db.maintenanceRules.id,
        ),
      );

  $$MaintenanceRulesTableProcessedTableManager? get ruleId {
    final $_column = $_itemColumn<String>('rule_id');
    if ($_column == null) return null;
    final manager = $$MaintenanceRulesTableTableManager(
      $_db,
      $_db.maintenanceRules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ruleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MaintenanceEventsTableFilterComposer
    extends Composer<_$AppDatabase, $MaintenanceEventsTable> {
  $$MaintenanceEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get performedAt => $composableBuilder(
    column: $table.performedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get odometerM => $composableBuilder(
    column: $table.odometerM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costCents => $composableBuilder(
    column: $table.costCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shop => $composableBuilder(
    column: $table.shop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MaintenanceRulesTableFilterComposer get ruleId {
    final $$MaintenanceRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.maintenanceRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceRulesTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $MaintenanceEventsTable> {
  $$MaintenanceEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get performedAt => $composableBuilder(
    column: $table.performedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get odometerM => $composableBuilder(
    column: $table.odometerM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costCents => $composableBuilder(
    column: $table.costCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shop => $composableBuilder(
    column: $table.shop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MaintenanceRulesTableOrderingComposer get ruleId {
    final $$MaintenanceRulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.maintenanceRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceRulesTableOrderingComposer(
            $db: $db,
            $table: $db.maintenanceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaintenanceEventsTable> {
  $$MaintenanceEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get performedAt => $composableBuilder(
    column: $table.performedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get odometerM =>
      $composableBuilder(column: $table.odometerM, builder: (column) => column);

  GeneratedColumn<int> get costCents =>
      $composableBuilder(column: $table.costCents, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get shop =>
      $composableBuilder(column: $table.shop, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MaintenanceRulesTableAnnotationComposer get ruleId {
    final $$MaintenanceRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.maintenanceRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.maintenanceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaintenanceEventsTable,
          MaintenanceEventRow,
          $$MaintenanceEventsTableFilterComposer,
          $$MaintenanceEventsTableOrderingComposer,
          $$MaintenanceEventsTableAnnotationComposer,
          $$MaintenanceEventsTableCreateCompanionBuilder,
          $$MaintenanceEventsTableUpdateCompanionBuilder,
          (MaintenanceEventRow, $$MaintenanceEventsTableReferences),
          MaintenanceEventRow,
          PrefetchHooks Function({bool vehicleId, bool ruleId})
        > {
  $$MaintenanceEventsTableTableManager(
    _$AppDatabase db,
    $MaintenanceEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaintenanceEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaintenanceEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MaintenanceEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String?> ruleId = const Value.absent(),
                Value<String> performedAt = const Value.absent(),
                Value<int?> odometerM = const Value.absent(),
                Value<int> costCents = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> shop = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceEventsCompanion(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                vehicleId: vehicleId,
                ruleId: ruleId,
                performedAt: performedAt,
                odometerM: odometerM,
                costCents: costCents,
                currencyCode: currencyCode,
                category: category,
                shop: shop,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required String mutationId,
                required String vehicleId,
                Value<String?> ruleId = const Value.absent(),
                required String performedAt,
                Value<int?> odometerM = const Value.absent(),
                Value<int> costCents = const Value.absent(),
                required String currencyCode,
                Value<String> category = const Value.absent(),
                Value<String?> shop = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceEventsCompanion.insert(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                vehicleId: vehicleId,
                ruleId: ruleId,
                performedAt: performedAt,
                odometerM: odometerM,
                costCents: costCents,
                currencyCode: currencyCode,
                category: category,
                shop: shop,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MaintenanceEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false, ruleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (vehicleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.vehicleId,
                                referencedTable:
                                    $$MaintenanceEventsTableReferences
                                        ._vehicleIdTable(db),
                                referencedColumn:
                                    $$MaintenanceEventsTableReferences
                                        ._vehicleIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (ruleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ruleId,
                                referencedTable:
                                    $$MaintenanceEventsTableReferences
                                        ._ruleIdTable(db),
                                referencedColumn:
                                    $$MaintenanceEventsTableReferences
                                        ._ruleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MaintenanceEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaintenanceEventsTable,
      MaintenanceEventRow,
      $$MaintenanceEventsTableFilterComposer,
      $$MaintenanceEventsTableOrderingComposer,
      $$MaintenanceEventsTableAnnotationComposer,
      $$MaintenanceEventsTableCreateCompanionBuilder,
      $$MaintenanceEventsTableUpdateCompanionBuilder,
      (MaintenanceEventRow, $$MaintenanceEventsTableReferences),
      MaintenanceEventRow,
      PrefetchHooks Function({bool vehicleId, bool ruleId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String id,
      Value<String?> userId,
      Value<int?> rowVersion,
      required String updatedAt,
      Value<String?> deletedAt,
      required String mutationId,
      required String preferredDistanceUnit,
      required String preferredVolumeUnit,
      required String currencyCode,
      required String timezone,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<int?> rowVersion,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<String> mutationId,
      Value<String> preferredDistanceUnit,
      Value<String> preferredVolumeUnit,
      Value<String> currencyCode,
      Value<String> timezone,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredDistanceUnit => $composableBuilder(
    column: $table.preferredDistanceUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredVolumeUnit => $composableBuilder(
    column: $table.preferredVolumeUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredDistanceUnit => $composableBuilder(
    column: $table.preferredDistanceUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredVolumeUnit => $composableBuilder(
    column: $table.preferredVolumeUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredDistanceUnit => $composableBuilder(
    column: $table.preferredDistanceUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredVolumeUnit => $composableBuilder(
    column: $table.preferredVolumeUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          SettingsRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> preferredDistanceUnit = const Value.absent(),
                Value<String> preferredVolumeUnit = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                preferredDistanceUnit: preferredDistanceUnit,
                preferredVolumeUnit: preferredVolumeUnit,
                currencyCode: currencyCode,
                timezone: timezone,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<int?> rowVersion = const Value.absent(),
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                required String mutationId,
                required String preferredDistanceUnit,
                required String preferredVolumeUnit,
                required String currencyCode,
                required String timezone,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                userId: userId,
                rowVersion: rowVersion,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                mutationId: mutationId,
                preferredDistanceUnit: preferredDistanceUnit,
                preferredVolumeUnit: preferredVolumeUnit,
                currencyCode: currencyCode,
                timezone: timezone,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      SettingsRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingsRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, SettingsRow>,
      ),
      SettingsRow,
      PrefetchHooks Function()
    >;
typedef $$DraftsTableCreateCompanionBuilder =
    DraftsCompanion Function({
      required String id,
      Value<String?> vehicleId,
      required String createdAt,
      Value<String?> filledAt,
      Value<int?> odometerM,
      Value<int?> volumeUL,
      Value<int?> totalPriceCents,
      Value<String?> currencyCode,
      Value<int?> isFull,
      Value<int?> missedBefore,
      Value<int?> odometerReset,
      Value<String?> notes,
      Value<String?> completedAt,
      Value<int> rowid,
    });
typedef $$DraftsTableUpdateCompanionBuilder =
    DraftsCompanion Function({
      Value<String> id,
      Value<String?> vehicleId,
      Value<String> createdAt,
      Value<String?> filledAt,
      Value<int?> odometerM,
      Value<int?> volumeUL,
      Value<int?> totalPriceCents,
      Value<String?> currencyCode,
      Value<int?> isFull,
      Value<int?> missedBefore,
      Value<int?> odometerReset,
      Value<String?> notes,
      Value<String?> completedAt,
      Value<int> rowid,
    });

final class $$DraftsTableReferences
    extends BaseReferences<_$AppDatabase, $DraftsTable, DraftRow> {
  $$DraftsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PhotoRefsTable, List<PhotoRefRow>>
  _photoRefsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.photoRefs,
    aliasName: $_aliasNameGenerator(db.drafts.id, db.photoRefs.draftId),
  );

  $$PhotoRefsTableProcessedTableManager get photoRefsRefs {
    final manager = $$PhotoRefsTableTableManager(
      $_db,
      $_db.photoRefs,
    ).filter((f) => f.draftId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_photoRefsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filledAt => $composableBuilder(
    column: $table.filledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get odometerM => $composableBuilder(
    column: $table.odometerM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volumeUL => $composableBuilder(
    column: $table.volumeUL,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPriceCents => $composableBuilder(
    column: $table.totalPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isFull => $composableBuilder(
    column: $table.isFull,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get missedBefore => $composableBuilder(
    column: $table.missedBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get odometerReset => $composableBuilder(
    column: $table.odometerReset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> photoRefsRefs(
    Expression<bool> Function($$PhotoRefsTableFilterComposer f) f,
  ) {
    final $$PhotoRefsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.photoRefs,
      getReferencedColumn: (t) => t.draftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoRefsTableFilterComposer(
            $db: $db,
            $table: $db.photoRefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filledAt => $composableBuilder(
    column: $table.filledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get odometerM => $composableBuilder(
    column: $table.odometerM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volumeUL => $composableBuilder(
    column: $table.volumeUL,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPriceCents => $composableBuilder(
    column: $table.totalPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isFull => $composableBuilder(
    column: $table.isFull,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get missedBefore => $composableBuilder(
    column: $table.missedBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get odometerReset => $composableBuilder(
    column: $table.odometerReset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get filledAt =>
      $composableBuilder(column: $table.filledAt, builder: (column) => column);

  GeneratedColumn<int> get odometerM =>
      $composableBuilder(column: $table.odometerM, builder: (column) => column);

  GeneratedColumn<int> get volumeUL =>
      $composableBuilder(column: $table.volumeUL, builder: (column) => column);

  GeneratedColumn<int> get totalPriceCents => $composableBuilder(
    column: $table.totalPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isFull =>
      $composableBuilder(column: $table.isFull, builder: (column) => column);

  GeneratedColumn<int> get missedBefore => $composableBuilder(
    column: $table.missedBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get odometerReset => $composableBuilder(
    column: $table.odometerReset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  Expression<T> photoRefsRefs<T extends Object>(
    Expression<T> Function($$PhotoRefsTableAnnotationComposer a) f,
  ) {
    final $$PhotoRefsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.photoRefs,
      getReferencedColumn: (t) => t.draftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoRefsTableAnnotationComposer(
            $db: $db,
            $table: $db.photoRefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          DraftRow,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (DraftRow, $$DraftsTableReferences),
          DraftRow,
          PrefetchHooks Function({bool photoRefsRefs})
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> vehicleId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> filledAt = const Value.absent(),
                Value<int?> odometerM = const Value.absent(),
                Value<int?> volumeUL = const Value.absent(),
                Value<int?> totalPriceCents = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> isFull = const Value.absent(),
                Value<int?> missedBefore = const Value.absent(),
                Value<int?> odometerReset = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                id: id,
                vehicleId: vehicleId,
                createdAt: createdAt,
                filledAt: filledAt,
                odometerM: odometerM,
                volumeUL: volumeUL,
                totalPriceCents: totalPriceCents,
                currencyCode: currencyCode,
                isFull: isFull,
                missedBefore: missedBefore,
                odometerReset: odometerReset,
                notes: notes,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> vehicleId = const Value.absent(),
                required String createdAt,
                Value<String?> filledAt = const Value.absent(),
                Value<int?> odometerM = const Value.absent(),
                Value<int?> volumeUL = const Value.absent(),
                Value<int?> totalPriceCents = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> isFull = const Value.absent(),
                Value<int?> missedBefore = const Value.absent(),
                Value<int?> odometerReset = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                createdAt: createdAt,
                filledAt: filledAt,
                odometerM: odometerM,
                volumeUL: volumeUL,
                totalPriceCents: totalPriceCents,
                currencyCode: currencyCode,
                isFull: isFull,
                missedBefore: missedBefore,
                odometerReset: odometerReset,
                notes: notes,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$DraftsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({photoRefsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (photoRefsRefs) db.photoRefs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (photoRefsRefs)
                    await $_getPrefetchedData<
                      DraftRow,
                      $DraftsTable,
                      PhotoRefRow
                    >(
                      currentTable: table,
                      referencedTable: $$DraftsTableReferences
                          ._photoRefsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DraftsTableReferences(db, table, p0).photoRefsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.draftId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      DraftRow,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (DraftRow, $$DraftsTableReferences),
      DraftRow,
      PrefetchHooks Function({bool photoRefsRefs})
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      required String mutationId,
      required String table_,
      required String op,
      required String rowId,
      Value<String?> payloadJson,
      required String enqueuedAt,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<String> mutationId,
      Value<String> table_,
      Value<String> op,
      Value<String> rowId,
      Value<String?> payloadJson,
      Value<String> enqueuedAt,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get table_ => $composableBuilder(
    column: $table.table_,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get table_ => $composableBuilder(
    column: $table.table_,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get table_ =>
      $composableBuilder(column: $table.table_, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> table_ = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<String> enqueuedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                mutationId: mutationId,
                table_: table_,
                op: op,
                rowId: rowId,
                payloadJson: payloadJson,
                enqueuedAt: enqueuedAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String mutationId,
                required String table_,
                required String op,
                required String rowId,
                Value<String?> payloadJson = const Value.absent(),
                required String enqueuedAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                mutationId: mutationId,
                table_: table_,
                op: op,
                rowId: rowId,
                payloadJson: payloadJson,
                enqueuedAt: enqueuedAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$PhotoRefsTableCreateCompanionBuilder =
    PhotoRefsCompanion Function({
      required String id,
      required String draftId,
      required String capturedAt,
      required int byteSize,
      required String sha256,
      required String ttlExpiresAt,
      Value<int> rowid,
    });
typedef $$PhotoRefsTableUpdateCompanionBuilder =
    PhotoRefsCompanion Function({
      Value<String> id,
      Value<String> draftId,
      Value<String> capturedAt,
      Value<int> byteSize,
      Value<String> sha256,
      Value<String> ttlExpiresAt,
      Value<int> rowid,
    });

final class $$PhotoRefsTableReferences
    extends BaseReferences<_$AppDatabase, $PhotoRefsTable, PhotoRefRow> {
  $$PhotoRefsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DraftsTable _draftIdTable(_$AppDatabase db) => db.drafts.createAlias(
    $_aliasNameGenerator(db.photoRefs.draftId, db.drafts.id),
  );

  $$DraftsTableProcessedTableManager get draftId {
    final $_column = $_itemColumn<String>('draft_id')!;

    final manager = $$DraftsTableTableManager(
      $_db,
      $_db.drafts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_draftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PhotoRefsTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoRefsTable> {
  $$PhotoRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ttlExpiresAt => $composableBuilder(
    column: $table.ttlExpiresAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DraftsTableFilterComposer get draftId {
    final $$DraftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftsTableFilterComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoRefsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoRefsTable> {
  $$PhotoRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ttlExpiresAt => $composableBuilder(
    column: $table.ttlExpiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DraftsTableOrderingComposer get draftId {
    final $$DraftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftsTableOrderingComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoRefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoRefsTable> {
  $$PhotoRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get ttlExpiresAt => $composableBuilder(
    column: $table.ttlExpiresAt,
    builder: (column) => column,
  );

  $$DraftsTableAnnotationComposer get draftId {
    final $$DraftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.draftId,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftsTableAnnotationComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoRefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotoRefsTable,
          PhotoRefRow,
          $$PhotoRefsTableFilterComposer,
          $$PhotoRefsTableOrderingComposer,
          $$PhotoRefsTableAnnotationComposer,
          $$PhotoRefsTableCreateCompanionBuilder,
          $$PhotoRefsTableUpdateCompanionBuilder,
          (PhotoRefRow, $$PhotoRefsTableReferences),
          PhotoRefRow,
          PrefetchHooks Function({bool draftId})
        > {
  $$PhotoRefsTableTableManager(_$AppDatabase db, $PhotoRefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoRefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoRefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> draftId = const Value.absent(),
                Value<String> capturedAt = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> ttlExpiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoRefsCompanion(
                id: id,
                draftId: draftId,
                capturedAt: capturedAt,
                byteSize: byteSize,
                sha256: sha256,
                ttlExpiresAt: ttlExpiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String draftId,
                required String capturedAt,
                required int byteSize,
                required String sha256,
                required String ttlExpiresAt,
                Value<int> rowid = const Value.absent(),
              }) => PhotoRefsCompanion.insert(
                id: id,
                draftId: draftId,
                capturedAt: capturedAt,
                byteSize: byteSize,
                sha256: sha256,
                ttlExpiresAt: ttlExpiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PhotoRefsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({draftId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (draftId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.draftId,
                                referencedTable: $$PhotoRefsTableReferences
                                    ._draftIdTable(db),
                                referencedColumn: $$PhotoRefsTableReferences
                                    ._draftIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PhotoRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotoRefsTable,
      PhotoRefRow,
      $$PhotoRefsTableFilterComposer,
      $$PhotoRefsTableOrderingComposer,
      $$PhotoRefsTableAnnotationComposer,
      $$PhotoRefsTableCreateCompanionBuilder,
      $$PhotoRefsTableUpdateCompanionBuilder,
      (PhotoRefRow, $$PhotoRefsTableReferences),
      PhotoRefRow,
      PrefetchHooks Function({bool draftId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$FillUpsTableTableManager get fillUps =>
      $$FillUpsTableTableManager(_db, _db.fillUps);
  $$MaintenanceRulesTableTableManager get maintenanceRules =>
      $$MaintenanceRulesTableTableManager(_db, _db.maintenanceRules);
  $$MaintenanceEventsTableTableManager get maintenanceEvents =>
      $$MaintenanceEventsTableTableManager(_db, _db.maintenanceEvents);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$PhotoRefsTableTableManager get photoRefs =>
      $$PhotoRefsTableTableManager(_db, _db.photoRefs);
}
