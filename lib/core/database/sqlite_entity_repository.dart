import 'package:sqflite/sqflite.dart';

import 'models/model_utils.dart';

class SqliteEntityRepository<T extends DatabaseEntity> {
  SqliteEntityRepository(
    this._database, {
    required this.table,
    required this.fromMap,
    required this.searchableColumns,
    required this.filterableColumns,
    this.dateColumn,
  }) {
    _validateIdentifier(table);
    final columns = {...searchableColumns, ...filterableColumns};
    final selectedDateColumn = dateColumn;
    if (selectedDateColumn != null) columns.add(selectedDateColumn);
    for (final column in columns) {
      _validateIdentifier(column);
    }
  }

  final Database _database;
  final String table;
  final T Function(Map<String, Object?> map) fromMap;
  final List<String> searchableColumns;
  final Set<String> filterableColumns;
  final String? dateColumn;

  Future<void> create(T entity, {Transaction? transaction}) async {
    await (transaction ?? _database).insert(
      table,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<T?> getById(String id) async {
    final rows = await _database.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : fromMap(rows.single);
  }

  Future<List<T>> getAll({
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'id',
    bool descending = false,
  }) async {
    final rows = await _queryRows(
      filters: filters,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      descending: descending,
    );
    return rows.map(fromMap).toList(growable: false);
  }

  Future<List<T>> search(
    String query, {
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'id',
    bool descending = false,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return getAll(
        filters: filters,
        fromDate: fromDate,
        toDate: toDate,
        limit: limit,
        offset: offset,
        orderBy: orderBy,
        descending: descending,
      );
    }

    final escapedQuery = normalizedQuery
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final searchClause = searchableColumns
        .map((column) => 'LOWER($column) LIKE LOWER(?) ESCAPE \'\\\'')
        .join(' OR ');
    final rows = await _queryRows(
      filters: filters,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      descending: descending,
      searchClause: '($searchClause)',
      searchArgs: List.filled(searchableColumns.length, '%$escapedQuery%'),
    );
    return rows.map(fromMap).toList(growable: false);
  }

  Future<void> update(T entity, {Transaction? transaction}) async {
    final changed = await (transaction ?? _database).update(
      table,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    if (changed == 0) {
      throw StateError('Cannot update missing $table record "${entity.id}".');
    }
  }

  Future<bool> delete(String id, {Transaction? transaction}) async {
    final deleted = await (transaction ?? _database).delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
    return deleted != 0;
  }

  Future<List<Map<String, Object?>>> _queryRows({
    required Map<String, Object?> filters,
    required DateTime? fromDate,
    required DateTime? toDate,
    required int? limit,
    required int offset,
    required String orderBy,
    required bool descending,
    String? searchClause,
    List<Object?> searchArgs = const [],
  }) async {
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    if (fromDate != null && toDate != null && !fromDate.isBefore(toDate)) {
      throw ArgumentError('fromDate must be earlier than exclusive toDate.');
    }
    if (!filterableColumns.contains(orderBy) &&
        !searchableColumns.contains(orderBy) &&
        orderBy != dateColumn) {
      throw ArgumentError.value(orderBy, 'orderBy', 'Unsupported sort column.');
    }

    final clauses = <String>[];
    final arguments = <Object?>[];
    for (final entry in filters.entries) {
      if (!filterableColumns.contains(entry.key)) {
        throw ArgumentError.value(entry.key, 'filters', 'Unsupported filter.');
      }
      final filterValue = entry.value;
      if (filterValue == null) {
        clauses.add('${entry.key} IS NULL');
      } else {
        clauses.add('${entry.key} = ?');
        arguments.add(_databaseValue(filterValue));
      }
    }
    if (fromDate != null || toDate != null) {
      if (dateColumn == null) {
        throw ArgumentError('Date filtering is not supported for $table.');
      }
      if (fromDate != null) {
        clauses.add('$dateColumn >= ?');
        arguments.add(dateToDatabase(fromDate));
      }
      if (toDate != null) {
        clauses.add('$dateColumn < ?');
        arguments.add(dateToDatabase(toDate));
      }
    }
    if (searchClause != null) {
      clauses.add(searchClause);
      arguments.addAll(searchArgs);
    }
    return _database.query(
      table,
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      limit: limit,
      offset: offset,
      orderBy: '$orderBy ${descending ? 'DESC' : 'ASC'}',
    );
  }

  Object _databaseValue(Object value) {
    if (value is DateTime) return dateToDatabase(value);
    if (value is bool) return value ? 1 : 0;
    if (value is Enum) return value.name;
    return value;
  }

  static void _validateIdentifier(String value) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value)) {
      throw ArgumentError.value(value, 'identifier');
    }
  }
}
