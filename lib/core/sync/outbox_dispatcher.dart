import 'dart:convert';

import 'package:sqflite/sqflite.dart';

abstract class SyncTransport {
  Future<bool> send(SyncOutboxEvent event);
}

class SyncOutboxEvent {
  const SyncOutboxEvent({
    required this.operationId,
    required this.installationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.status,
  });

  factory SyncOutboxEvent.fromMap(Map<String, Object?> map) {
    final payloadJson = (map['payload_json'] as String?) ?? '{}';

    return SyncOutboxEvent(
      operationId: (map['operation_id'])?.toString() ?? '',
      installationId: (map['installation_id'])?.toString() ?? '',
      entityType: (map['entity_type'])?.toString() ?? '',
      entityId: (map['entity_id'])?.toString() ?? '',
      operation: (map['operation'])?.toString() ?? '',
      payload: _decodePayload(payloadJson),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] is num)
            ? (map['created_at'] as num).toInt()
            : DateTime.now().millisecondsSinceEpoch,
      ),
      status: (map['status'])?.toString() ?? 'pending',
    );
  }

  static Map<String, Object?> _decodePayload(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String, Object?>{};
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on Object {
      // Keep the raw payload if it is not valid JSON.
    }

    return <String, Object?>{'raw': trimmed};
  }

  final String operationId;
  final String installationId;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final String status;

  Map<String, Object?> toMap() => {
        'operation_id': operationId,
        'installation_id': installationId,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'payload_json': jsonEncode(payload.isEmpty ? <String, Object?>{} : payload),
        'created_at': createdAt.millisecondsSinceEpoch,
        'status': status,
      };
}

class OutboxDispatcher {
  OutboxDispatcher(this._database, this._transport);

  final Database _database;
  final SyncTransport _transport;
  Future<int>? _activeDispatch;

  Future<int> dispatchPending() {
    final active = _activeDispatch;
    if (active != null) {
      return active.then((_) => 0);
    }

    final dispatch = _dispatchPendingOnce();
    _activeDispatch = dispatch;
    return dispatch.whenComplete(() {
      if (identical(_activeDispatch, dispatch)) {
        _activeDispatch = null;
      }
    });
  }

  Future<int> _dispatchPendingOnce() async {
    final rows = await _database.query(
      'sync_outbox',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'sequence ASC',
    );

    var dispatched = 0;

    for (final row in rows) {
      final event = SyncOutboxEvent.fromMap(row);

      bool wasSent;
      try {
        wasSent = await _transport.send(event);
      } on Object {
        // Keep a failed event pending so it can be retried later.
        continue;
      }

      if (!wasSent) {
        continue;
      }

      final updated = await _database.update(
        'sync_outbox',
        {'status': 'acknowledged'},
        where: 'operation_id = ?',
        whereArgs: [event.operationId],
      );

      if (updated > 0) {
        dispatched += 1;
      }
    }

    return dispatched;
  }
}
