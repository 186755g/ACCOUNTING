import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hesabati/core/database/database.dart';
import 'package:hesabati/core/services/backup_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;
  late LocalDatabase database;
  late BackupService backups;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'hesabati-backup-test-',
    );
    database = await LocalDatabase.open(
      databasePath: path.join(temporaryDirectory.path, 'hesabati.db'),
      factory: databaseFactoryFfi,
    );
    final cache = Directory(path.join(temporaryDirectory.path, 'cache'));
    final documents = Directory(
      path.join(temporaryDirectory.path, 'documents'),
    );
    await cache.create();
    await documents.create();
    backups = BackupService(
      factory: databaseFactoryFfi,
      temporaryDirectoryProvider: () async => cache,
      documentsDirectoryProvider: () async => documents,
    );
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'creates, validates, and restores a consistent offline snapshot',
    () async {
      final original = Product(
        id: 'backup-original',
        name: 'Original product',
        costPriceMinor: 25,
        sellingPriceMinor: 50,
        stockQuantity: 8,
      );
      await database.products.create(original);
      final backup = await backups.createBackup(database);
      expect((await backups.latestBackup())?.path, backup.path);

      await database.products.create(
        Product(
          id: 'backup-new',
          name: 'New product',
          costPriceMinor: 30,
          sellingPriceMinor: 60,
        ),
      );
      database = await backups.restoreBackup(backup, database);

      expect(await database.products.getById(original.id), isNotNull);
      expect(await database.products.getById('backup-new'), isNull);
    },
  );

  test(
    'rejects corrupt backups without closing or changing live data',
    () async {
      final product = Product(
        id: 'backup-kept',
        name: 'Keep this product',
        costPriceMinor: 10,
        sellingPriceMinor: 20,
      );
      await database.products.create(product);
      final validBackup = await backups.createBackup(database);
      final corrupt = File(path.join(temporaryDirectory.path, 'corrupt.hdb'));
      final bytes = await validBackup.readAsBytes();
      bytes[bytes.length - 1] ^= 0xff;
      await corrupt.writeAsBytes(bytes);

      await expectLater(
        backups.restoreBackup(corrupt, database),
        throwsA(isA<FormatException>()),
      );
      expect(await database.products.getById(product.id), isNotNull);
    },
  );

  test('selects the most recently modified backup', () async {
    final backupDirectory = Directory(
      path.join(temporaryDirectory.path, 'documents', 'HesabatiBackups'),
    );
    await backupDirectory.create();
    final storedOlder = File(path.join(backupDirectory.path, 'older.hdb'));
    final storedNewer = File(path.join(backupDirectory.path, 'newer.hdb'));
    await storedOlder.writeAsBytes([1]);
    await storedNewer.writeAsBytes([2]);
    await storedOlder.setLastModified(DateTime.utc(2026, 1, 1));
    await storedNewer.setLastModified(DateTime.utc(2026, 1, 2));

    expect((await backups.latestBackup())?.path, storedNewer.path);
  });
}
