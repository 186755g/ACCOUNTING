import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hesabati/core/database/database.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory testDirectory;
  late InstallationIdentityStore installationIdentity;
  late LocalDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'hesabati-sync-foundation-',
    );
    installationIdentity = InstallationIdentityStore(
      directoryProvider: () async => testDirectory,
    );
    database = await LocalDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
      installationIdentity: installationIdentity,
    );
  });

  tearDown(() async {
    await database.close();
    await testDirectory.delete(recursive: true);
  });

  test('installation identity persists outside the local database', () async {
    final identity = await installationIdentity.getOrCreate();
    final secondStore = InstallationIdentityStore(
      directoryProvider: () async => testDirectory,
    );

    expect(await secondStore.getOrCreate(), identity);
    expect(
      await File(
        path.join(testDirectory.path, InstallationIdentityStore.fileName),
      ).readAsString(),
      identity,
    );
    expect(database.databasePath, inMemoryDatabasePath);
  });

  test('category changes and outbox records commit together', () async {
    final identity = await installationIdentity.getOrCreate();
    final category = Category(name: 'Drinks');
    await database.categories.create(category);

    final product = Product(
      name: 'Tea',
      categoryId: category.id,
      costPriceMinor: 100,
      sellingPriceMinor: 200,
    );
    await database.products.create(product);

    final updated = Category(
      id: category.id,
      name: 'Hot drinks',
      createdAt: category.createdAt,
      updatedAt: DateTime.utc(2026, 10, 14),
    );
    await database.categories.update(updated);

    expect(await database.categories.delete(category.id), isTrue);
    expect((await database.products.getById(product.id))!.categoryId, isNull);

    final changes = await database.syncOutbox.getAll();
    expect(changes.map((change) => change['operation']).toList(), [
      'create',
      'create',
      'update',
      'delete',
    ]);
    expect(changes.map((change) => change['entity_type']).toList(), [
      'category',
      'product',
      'category',
      'category',
    ]);
    expect(changes.where((change) => change['entity_type'] == 'category'), hasLength(3));
    expect(changes.where((change) => change['entity_type'] == 'product'), hasLength(1));
    expect(
      changes.where((change) => change['entity_id'] == category.id),
      hasLength(3),
    );
    expect(
      changes.where((change) => change['entity_id'] == product.id),
      hasLength(1),
    );
    expect(changes.map((change) => change['installation_id']).toSet(), {
      identity,
    });
    expect(
      changes.map((change) => change['operation_id']).toSet(),
      hasLength(changes.length),
    );

    final categoryDeleteEvent = changes.singleWhere(
      (change) =>
          change['entity_type'] == 'category' &&
          change['operation'] == 'delete',
    );
    expect(
      jsonDecode(categoryDeleteEvent['payload_json']! as String)['name'],
      'Hot drinks',
    );
    expect(
      changes.singleWhere((change) => change['entity_type'] == 'product')['entity_id'],
      product.id,
    );
  });

  test('outbox insertion failure rolls back a category write', () async {
    final category = Category(name: 'Existing category');
    await database.categories.create(category);
    final product = Product(
      name: 'Assigned product',
      categoryId: category.id,
      costPriceMinor: 100,
      sellingPriceMinor: 200,
    );
    await database.products.create(product);
    final initialOutbox = await database.syncOutbox.getAll();

    await database.transaction(
      (transaction) => transaction.execute('''
        CREATE TRIGGER reject_outbox_insert
        BEFORE INSERT ON sync_outbox
        BEGIN
          SELECT RAISE(ABORT, 'outbox unavailable');
        END
      '''),
    );
    final rejectedCategory = Category(name: 'Rejected category');
    await expectLater(
      database.categories.create(rejectedCategory),
      throwsA(anything),
    );
    await expectLater(
      database.categories.update(
        Category(
          id: category.id,
          name: 'Rejected update',
          createdAt: category.createdAt,
        ),
      ),
      throwsA(anything),
    );
    await expectLater(
      database.categories.delete(category.id),
      throwsA(anything),
    );

    expect(
      (await database.categories.getById(category.id))!.name,
      category.name,
    );
    expect(await database.categories.getById(rejectedCategory.id), isNull);
    expect(
      (await database.products.getById(product.id))!.categoryId,
      category.id,
    );
    expect(await database.syncOutbox.getAll(), initialOutbox);
  });

  test('operation id is unique in the local outbox', () async {
    await database.categories.create(Category(name: 'Unique operation'));
    final existing = (await database.syncOutbox.getAll()).single;

    await expectLater(
      database.transaction(
        (transaction) => transaction.insert('sync_outbox', {
          'operation_id': existing['operation_id'],
          'installation_id': existing['installation_id'],
          'entity_type': existing['entity_type'],
          'entity_id': existing['entity_id'],
          'operation': existing['operation'],
          'payload_json': existing['payload_json'],
          'created_at': existing['created_at'],
        }),
      ),
      throwsA(anything),
    );
  });

  test('version 7 upgrade preserves business rows and creates outbox', () async {
    final databasePath = path.join(testDirectory.path, 'legacy.db');
    var legacyDatabase = await LocalDatabase.open(
      databasePath: databasePath,
      factory: databaseFactoryFfi,
      installationIdentity: installationIdentity,
    );
    final category = Category(name: 'Existing category');
    final product = Product(
      id: 'existing-product',
      name: 'Existing product',
      categoryId: category.id,
      costPriceMinor: 100,
      sellingPriceMinor: 200,
    );
    await legacyDatabase.categories.create(category);
    await legacyDatabase.products.create(product);
    await legacyDatabase.transaction((transaction) async {
      await transaction.execute('DROP TABLE sync_outbox');
      await transaction.execute('PRAGMA user_version = 7');
    });
    await legacyDatabase.close();

    legacyDatabase = await LocalDatabase.open(
      databasePath: databasePath,
      factory: databaseFactoryFfi,
      installationIdentity: installationIdentity,
    );
    try {
      expect(await legacyDatabase.categories.getById(category.id), isNotNull);
      expect(
        (await legacyDatabase.products.getById(product.id))!.categoryId,
        category.id,
      );
      final tables = await legacyDatabase.transaction(
        (transaction) => transaction.rawQuery(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name = 'sync_outbox'",
        ),
      );
      expect(tables, hasLength(1));
      expect(await legacyDatabase.syncOutbox.getAll(), isEmpty);
    } finally {
      await legacyDatabase.close();
    }
  });
}
