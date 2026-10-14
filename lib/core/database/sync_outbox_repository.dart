import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'models/model_utils.dart';

class SyncOutboxRepository {
  SyncOutboxRepository(this._database);

  final Database _database;

  Future<void> recordCategoryChange(
    Transaction transaction, {
    required String installationId,
    required String categoryId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    if (!const {'create', 'update', 'delete'}.contains(operation)) {
      throw ArgumentError.value(operation, 'operation');
    }
    await transaction.insert(
      'sync_outbox',
      {
        'operation_id': newModelId(),
        'installation_id': installationId,
        'entity_type': 'category',
        'entity_id': categoryId,
        'operation': operation,
        'payload_json': jsonEncode(payload),
        'created_at': dateToDatabase(DateTime.now()),
        'status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, Object?>>> getAll() => _database.query(
    'sync_outbox',
    orderBy: 'sequence ASC',
  );
}
