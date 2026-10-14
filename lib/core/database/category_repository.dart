import 'package:sqflite/sqflite.dart';

import 'models/category.dart';
import 'models/model_utils.dart';
import 'sqlite_entity_repository.dart';
import 'sync_outbox_repository.dart';
import '../services/installation_identity_store.dart';

class CategoryRepository {
  CategoryRepository(
    Database database, {
    required InstallationIdentityStore installationIdentity,
    required SyncOutboxRepository outbox,
  }) : _database = database,
       _installationIdentity = installationIdentity,
       _outbox = outbox,
       _repository = SqliteEntityRepository<Category>(
         database,
         table: 'categories',
         fromMap: Category.fromMap,
         searchableColumns: const ['name', 'description'],
         filterableColumns: const {'id', 'is_archived'},
         dateColumn: 'created_at',
       );

  final Database _database;
  final InstallationIdentityStore _installationIdentity;
  final SyncOutboxRepository _outbox;
  final SqliteEntityRepository<Category> _repository;

  Future<Category?> getById(String id) => _repository.getById(id);

  Future<List<Category>> getAll({
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'id',
    bool descending = false,
  }) => _repository.getAll(
    filters: filters,
    fromDate: fromDate,
    toDate: toDate,
    limit: limit,
    offset: offset,
    orderBy: orderBy,
    descending: descending,
  );

  Future<List<Category>> search(
    String query, {
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'id',
    bool descending = false,
  }) => _repository.search(
    query,
    filters: filters,
    fromDate: fromDate,
    toDate: toDate,
    limit: limit,
    offset: offset,
    orderBy: orderBy,
    descending: descending,
  );

  Future<void> create(Category category) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    await _database.transaction((transaction) async {
      await transaction.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (installationId != null) {
        await _outbox.recordCategoryChange(
          transaction,
          installationId: installationId,
          categoryId: category.id,
          operation: 'create',
          payload: category.toMap(),
        );
      }
    });
  }

  Future<void> update(Category category) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    await _database.transaction((transaction) async {
      final changed = await transaction.update(
        'categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (changed == 0) {
        throw StateError(
          'Cannot update missing categories record "${category.id}".',
        );
      }
      if (installationId != null) {
        await _outbox.recordCategoryChange(
          transaction,
          installationId: installationId,
          categoryId: category.id,
          operation: 'update',
          payload: category.toMap(),
        );
      }
    });
  }

  Future<bool> delete(String id) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    return _database.transaction((transaction) async {
      final rows = await transaction.query(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return false;

      final deleted = await transaction.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (deleted == 0) return false;
      if (installationId != null) {
        await _outbox.recordCategoryChange(
          transaction,
          installationId: installationId,
          categoryId: id,
          operation: 'delete',
          payload: rows.single,
        );
      }
      return true;
    });
  }
}
