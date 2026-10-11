import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';
import '../database/models/app_settings.dart';
import '../database/models/model_utils.dart';

class BackupService {
  BackupService({
    this.factory,
    Future<Directory> Function()? temporaryDirectoryProvider,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const _magic = [72, 69, 83, 65, 66, 65, 84, 73];
  static const _formatVersion = 1;
  static const _maximumHeaderLength = 4096;
  static const _maximumDatabaseBytes = 1 << 30;
  static const _maximumBackupBytes =
      _maximumDatabaseBytes + _maximumHeaderLength + (1 << 20) + 12;

  final DatabaseFactory? factory;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<File> createBackup(LocalDatabase database) async {
    final temporaryDirectory = await _temporaryDirectoryProvider();
    final documentsDirectory = await _documentsDirectoryProvider();
    final backupDirectory = Directory(
      path.join(documentsDirectory.path, 'HesabatiBackups'),
    );
    await backupDirectory.create(recursive: true);

    final token = newModelId();
    final snapshot = File(
      path.join(temporaryDirectory.path, 'hesabati-snapshot-$token.db'),
    );
    final timestamp = DateTime.now().toUtc();
    final backup = File(
      path.join(
        backupDirectory.path,
        'hesabati-${timestamp.millisecondsSinceEpoch}-$token.hdb',
      ),
    );
    try {
      await database.createSnapshot(snapshot.path);
      final snapshotSize = await snapshot.length();
      if (snapshotSize > _maximumDatabaseBytes) {
        throw StateError('The database exceeds the 1 GiB backup limit.');
      }
      final digest = await sha256.bind(snapshot.openRead()).first;
      final metadata = utf8.encode(
        jsonEncode({
          'formatVersion': _formatVersion,
          'schemaVersion': LocalDatabase.databaseVersion,
          'createdAt': timestamp.toIso8601String(),
          'size': snapshotSize,
          'sha256': digest.toString(),
        }),
      );
      if (metadata.length > _maximumHeaderLength) {
        throw StateError('Backup metadata exceeds the supported size.');
      }
      final sink = backup.openWrite();
      sink
        ..add(_magic)
        ..add(_int32(metadata.length))
        ..add(metadata);
      await sink.addStream(snapshot.openRead().transform(gzip.encoder));
      await sink.close();
      return backup;
    } catch (_) {
      if (await backup.exists()) await backup.delete();
      rethrow;
    } finally {
      if (await snapshot.exists()) await snapshot.delete();
    }
  }

  Future<File?> latestBackup() async {
    final documentsDirectory = await _documentsDirectoryProvider();
    final backupDirectory = Directory(
      path.join(documentsDirectory.path, 'HesabatiBackups'),
    );
    if (!await backupDirectory.exists()) return null;
    final files = await backupDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.hdb'))
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    final backups = await Future.wait(
      files.map(
        (file) async => (file: file, modified: (await file.stat()).modified),
      ),
    );
    backups.sort((left, right) => right.modified.compareTo(left.modified));
    return backups.first.file;
  }

  Future<LocalDatabase> restoreBackup(
    File backupFile,
    LocalDatabase currentDatabase,
  ) async {
    final temporaryDirectory = await _temporaryDirectoryProvider();
    final staged = File(
      path.join(temporaryDirectory.path, 'hesabati-restore-${newModelId()}.db'),
    );
    try {
      final metadata = await _readMetadata(backupFile);
      if (metadata['formatVersion'] != _formatVersion) {
        throw const FormatException('Unsupported backup format version.');
      }
      if (metadata['schemaVersion'] != LocalDatabase.databaseVersion) {
        throw const FormatException(
          'This backup was made by an incompatible application version.',
        );
      }
      final expectedSize = metadata['size'];
      if (expectedSize is! int ||
          expectedSize < 1 ||
          expectedSize > _maximumDatabaseBytes) {
        throw const FormatException('Invalid backup size metadata.');
      }
      if (metadata['sha256'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(metadata['sha256'] as String)) {
        throw const FormatException('Invalid backup integrity metadata.');
      }
      final payloadOffset = await _payloadOffset(backupFile);
      final output = staged.openWrite();
      var actualSize = 0;
      try {
        await for (final chunk
            in backupFile.openRead(payloadOffset).transform(gzip.decoder)) {
          actualSize += chunk.length;
          if (actualSize > expectedSize) {
            throw const FormatException(
              'Backup expands beyond its declared size.',
            );
          }
          output.add(chunk);
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (actualSize != expectedSize) {
        throw const FormatException('Backup size does not match its metadata.');
      }
      final actualDigest = await sha256.bind(staged.openRead()).first;
      if (actualDigest.toString() != metadata['sha256']) {
        throw const FormatException('Backup integrity validation failed.');
      }
      await _validateDatabase(staged);
      return await currentDatabase.replaceWithSnapshot(staged.path);
    } on DatabaseReplacementException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Could not restore the selected backup.');
    } finally {
      if (await staged.exists()) await staged.delete();
    }
  }

  Future<Map<String, Object?>> _readMetadata(File backup) async {
    final file = await backup.open();
    try {
      final length = await file.length();
      if (length > _maximumBackupBytes) {
        throw const FormatException('Backup file exceeds the supported size.');
      }
      if (length < 12) throw const FormatException('Backup file is too short.');
      final magic = await file.read(8);
      for (var index = 0; index < _magic.length; index++) {
        if (magic[index] != _magic[index]) {
          throw const FormatException('Unrecognized backup file.');
        }
      }
      final headerLength = _readInt32(await file.read(4));
      if (headerLength < 2 ||
          headerLength > _maximumHeaderLength ||
          length < 12 + headerLength) {
        throw const FormatException('Invalid backup metadata length.');
      }
      final decoded = jsonDecode(utf8.decode(await file.read(headerLength)));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup metadata.');
      }
      final createdAt = decoded['createdAt'];
      if (createdAt is! String || DateTime.tryParse(createdAt) == null) {
        throw const FormatException('Invalid backup creation date.');
      }
      return decoded;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Could not read backup metadata.');
    } finally {
      await file.close();
    }
  }

  Future<int> _payloadOffset(File backup) async {
    final file = await backup.open();
    try {
      await file.setPosition(8);
      final headerLength = _readInt32(await file.read(4));
      return 12 + headerLength;
    } finally {
      await file.close();
    }
  }

  Future<void> _validateDatabase(File staged) async {
    final database = await (factory ?? databaseFactory).openDatabase(
      staged.path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      final integrity = await database.rawQuery('PRAGMA integrity_check');
      if (integrity.length != 1 || integrity.single.values.first != 'ok') {
        throw const FormatException('SQLite integrity check failed.');
      }
      final version = await database.rawQuery('PRAGMA user_version');
      if (version.single.values.first != LocalDatabase.databaseVersion) {
        throw const FormatException('Backup database version is incompatible.');
      }
      final foreignKeyErrors = await database.rawQuery(
        'PRAGMA foreign_key_check',
      );
      if (foreignKeyErrors.isNotEmpty) {
        throw const FormatException('Backup contains invalid references.');
      }
      final tableRows = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = tableRows.map((row) => row['name'] as String).toSet();
      const requiredTables = {
        'app_settings',
        'categories',
        'products',
        'sales',
        'sale_items',
        'purchases',
        'purchase_items',
        'customers',
        'suppliers',
        'debts',
        'payments',
        'expenses',
        'users',
        'inventory_history',
        'product_returns',
        'notification_deliveries',
      };
      if (!tables.containsAll(requiredTables)) {
        throw const FormatException(
          'Backup is missing required database tables.',
        );
      }
      const requiredColumns = {
        'categories': {'id', 'name', 'is_archived', 'created_at', 'updated_at'},
        'app_settings': {
          'id',
          'business_name',
          'owner_name',
          'phone',
          'currency_code',
          'locale_code',
          'business_type',
          'theme_mode',
          'allow_negative_stock',
          'notify_low_stock',
          'notify_out_of_stock',
          'notify_unpaid_debts',
          'notify_overdue_payments',
          'notify_daily_sales',
          'updated_at',
        },
        'products': {
          'id',
          'name',
          'cost_price_minor',
          'selling_price_minor',
          'stock_quantity',
          'minimum_stock',
          'created_at',
          'updated_at',
        },
        'sales': {'id', 'date_at', 'total_minor', 'status'},
        'sale_items': {
          'id',
          'sale_id',
          'product_id',
          'quantity',
          'cost_price_minor',
          'selling_price_minor',
        },
        'purchases': {'id', 'supplier_id', 'date_at', 'total_minor'},
        'purchase_items': {
          'id',
          'purchase_id',
          'product_id',
          'quantity',
          'cost_price_minor',
        },
        'debts': {
          'id',
          'customer_id',
          'supplier_id',
          'direction',
          'amount_minor',
        },
        'payments': {'id', 'debt_id', 'amount_minor', 'method', 'date_at'},
        'expenses': {'id', 'amount_minor', 'date_at'},
        'users': {
          'id',
          'name',
          'email',
          'role',
          'is_active',
          'created_at',
          'updated_at',
        },
        'inventory_history': {'id', 'product_id', 'quantity', 'date_at'},
        'product_returns': {
          'id',
          'sale_id',
          'sale_item_id',
          'product_id',
          'quantity',
          'refund_minor',
          'returned_cost_minor',
        },
        'notification_deliveries': {'alert_key', 'fingerprint', 'delivered_at'},
      };
      for (final entry in requiredColumns.entries) {
        final columns = await database.rawQuery(
          'PRAGMA table_info(${entry.key})',
        );
        final names = columns.map((column) => column['name'] as String).toSet();
        if (!names.containsAll(entry.value)) {
          throw FormatException(
            'Backup table ${entry.key} is missing required columns.',
          );
        }
      }
      final settings = await database.rawQuery(
        "SELECT * FROM app_settings WHERE id = '1'",
      );
      if (settings.length != 1) {
        throw const FormatException('Backup has no valid business settings.');
      }
      AppSettings.fromMap(settings.single);
    } finally {
      await database.close();
    }
  }

  List<int> _int32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  int _readInt32(List<int> bytes) {
    if (bytes.length != 4) {
      throw const FormatException('Truncated backup header.');
    }
    return ByteData.sublistView(Uint8List.fromList(bytes))
        .getUint32(0, Endian.little);
  }
}
