import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'models/model_utils.dart';

class SyncOutboxRepository {
  SyncOutboxRepository(this._database);

  // This repository is intentionally local-only: the outbox records pending
  // journal state only and does not imply remote delivery or server ack.
  final Database _database;
  static const Set<String> _validOperations = {'create', 'update', 'delete'};

  String _validateEvent({
    required String installationId,
    required String entityId,
    required String entityType,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    if (installationId.trim().isEmpty) {
      throw ArgumentError.value(
        installationId,
        'installationId',
        'Installation ID must be non-empty before a local event can be logged.',
      );
    }
    if (entityId.trim().isEmpty) {
      throw ArgumentError.value(
        entityId,
        'entityId',
        'Entity ID must be non-empty before a $entityType event can be logged.',
      );
    }
    if (!_validOperations.contains(operation)) {
      throw ArgumentError.value(operation, 'operation');
    }
    if (payload.isEmpty) {
      throw ArgumentError.value(
        payload,
        'payload',
        '$entityType event payload cannot be empty.',
      );
    }

    final payloadJson = jsonEncode(payload);
    if (payloadJson.trim().isEmpty) {
      throw ArgumentError.value(
        payload,
        'payload',
        '$entityType event payload must produce a non-empty JSON document.',
      );
    }

    return payloadJson;
  }

  String _validateCategoryEvent({
    required String installationId,
    required String categoryId,
    required String operation,
    required Map<String, Object?> payload,
  }) => _validateEvent(
    installationId: installationId,
    entityId: categoryId,
    entityType: 'category',
    operation: operation,
    payload: payload,
  );

  Future<void> recordCategoryChange(
    Transaction transaction, {
    required String installationId,
    required String categoryId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final payloadJson = _validateCategoryEvent(
      installationId: installationId,
      categoryId: categoryId,
      operation: operation,
      payload: payload,
    );

    final event = {
      'operation_id': newModelId(),
      'installation_id': installationId,
      'entity_type': 'category',
      'entity_id': categoryId,
      'operation': operation,
      'payload_json': payloadJson,
      'created_at': dateToDatabase(DateTime.now()),
      'status': 'pending',
    };

    await transaction.insert(
      'sync_outbox',
      event,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> recordProductChange(
    Transaction transaction, {
    required String installationId,
    required String productId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final payloadJson = _validateEvent(
      installationId: installationId,
      entityId: productId,
      entityType: 'product',
      operation: operation,
      payload: payload,
    );

    final event = {
      'operation_id': newModelId(),
      'installation_id': installationId,
      'entity_type': 'product',
      'entity_id': productId,
      'operation': operation,
      'payload_json': payloadJson,
      'created_at': dateToDatabase(DateTime.now()),
      'status': 'pending',
    };

    await transaction.insert(
      'sync_outbox',
      event,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> recordPurchaseChange(
    Transaction transaction, {
      required String installationId,
      required String purchaseId,
      required String operation,
      required Map<String, Object?> payload,
    }) async {
    final payloadJson = _validateEvent(
      installationId: installationId,
      entityId: purchaseId,
      entityType: 'purchase',
      operation: operation,
      payload: payload,
    );

    final event = {
      'operation_id': newModelId(),
      'installation_id': installationId,
      'entity_type': 'purchase',
      'entity_id': purchaseId,
      'operation': operation,
      'payload_json': payloadJson,
      'created_at': dateToDatabase(DateTime.now()),
      'status': 'pending',
    };

    await transaction.insert(
      'sync_outbox',
      event,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> recordSaleChange(
    Transaction transaction, {
      required String installationId,
      required String saleId,
      required String operation,
      required Map<String, Object?> payload,
    }) async {
    final payloadJson = _validateEvent(
      installationId: installationId,
      entityId: saleId,
      entityType: 'sale',
      operation: operation,
      payload: payload,
    );

    final event = {
      'operation_id': newModelId(),
      'installation_id': installationId,
      'entity_type': 'sale',
      'entity_id': saleId,
      'operation': operation,
      'payload_json': payloadJson,
      'created_at': dateToDatabase(DateTime.now()),
      'status': 'pending',
    };

    await transaction.insert(
      'sync_outbox',
      event,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> recordPaymentChange(
    Transaction transaction, {
      required String installationId,
      required String paymentId,
      required String operation,
      required Map<String, Object?> payload,
    }) async {
    final payloadJson = _validateEvent(
      installationId: installationId,
      entityId: paymentId,
      entityType: 'payment',
      operation: operation,
      payload: payload,
    );

    final event = {
      'operation_id': newModelId(),
      'installation_id': installationId,
      'entity_type': 'payment',
      'entity_id': paymentId,
      'operation': operation,
      'payload_json': payloadJson,
      'created_at': dateToDatabase(DateTime.now()),
      'status': 'pending',
    };

    await transaction.insert(
      'sync_outbox',
      event,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> recordDebtChange(
    Transaction transaction, {
      required String installationId,
      required String debtId,
      required String operation,
      required Map<String, Object?> payload,
    }) async {
    final payloadJson = _validateEvent(
      installationId: installationId,
      entityId: debtId,
      entityType: 'debt',
      operation: operation,
      payload: payload,
    );

    final event = {
      'operation_id': newModelId(),
      'installation_id': installationId,
      'entity_type': 'debt',
      'entity_id': debtId,
      'operation': operation,
      'payload_json': payloadJson,
      'created_at': dateToDatabase(DateTime.now()),
      'status': 'pending',
    };

    await transaction.insert(
      'sync_outbox',
      event,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, Object?>>> getAll() => _database.query(
    'sync_outbox',
    orderBy: 'sequence ASC',
  );
}
