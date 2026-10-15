import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hesabati/core/sync/outbox_dispatcher.dart';

class FakeTransport implements SyncTransport {
  FakeTransport({this.result = true, this.calls = 0});

  final bool result;
  final int calls;

  @override
  Future<bool> send(SyncOutboxEvent event) async => result;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> _openDb() async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1,
        onCreate: (database, version) async {
      await database.execute('''
        CREATE TABLE sync_outbox (
          sequence INTEGER PRIMARY KEY AUTOINCREMENT,
          operation_id TEXT NOT NULL UNIQUE,
          installation_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation TEXT NOT NULL CHECK (
            operation IN ('create', 'update', 'delete')
          ),
          payload_json TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending'
            CHECK (status IN ('pending', 'acknowledged'))
        )
      ''');
    });
    return db;
  }

  test('successfully sends pending events and acknowledges them', () async {
    final db = await _openDb();
    final transport = FakeTransport(result: true);
    final dispatcher = OutboxDispatcher(db, transport);

    await db.insert('sync_outbox', {
      'operation_id': 'op-success',
      'installation_id': 'install-1',
      'entity_type': 'product',
      'entity_id': 'p-1',
      'operation': 'create',
      'payload_json': '{"name":"Widget"}',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
    });

    final sent = await dispatcher.dispatchPending();
    final row = await db.query(
      'sync_outbox',
      where: 'operation_id = ?',
      whereArgs: ['op-success'],
      limit: 1,
    );

    expect(sent, 1);
    expect(row.single['status'], 'acknowledged');
    await db.close();
  });

  test('keeps pending events when transport fails', () async {
    final db = await _openDb();
    final transport = FakeTransport(result: false);
    final dispatcher = OutboxDispatcher(db, transport);

    await db.insert('sync_outbox', {
      'operation_id': 'op-fail',
      'installation_id': 'install-1',
      'entity_type': 'category',
      'entity_id': 'c-1',
      'operation': 'update',
      'payload_json': '{"name":"Updated"}',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
    });

    final sent = await dispatcher.dispatchPending();
    final row = await db.query(
      'sync_outbox',
      where: 'operation_id = ?',
      whereArgs: ['op-fail'],
      limit: 1,
    );

    expect(sent, 0);
    expect(row.single['status'], 'pending');
    await db.close();
  });

  test('does not acknowledge events when no delivery confirmation exists', () async {
    final db = await _openDb();
    final transport = FakeTransport(result: false);
    final dispatcher = OutboxDispatcher(db, transport);

    await db.insert('sync_outbox', {
      'operation_id': 'op-no-confirmation',
      'installation_id': 'install-1',
      'entity_type': 'sale',
      'entity_id': 's-1',
      'operation': 'create',
      'payload_json': '{"total":100}',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
    });

    await dispatcher.dispatchPending();
    final row = await db.query(
      'sync_outbox',
      where: 'operation_id = ?',
      whereArgs: ['op-no-confirmation'],
      limit: 1,
    );

    expect(row.single['status'], 'pending');
    await db.close();
  });
}
