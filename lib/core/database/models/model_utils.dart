import 'dart:math';

abstract interface class DatabaseEntity {
  String get id;
  Map<String, Object?> toMap();
}

final Random _random = Random.secure();

String newModelId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  final value = hex.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

class MovementIdentityConflictException implements Exception {
  MovementIdentityConflictException({
    required this.kind,
    required this.sourceType,
    required this.sourceId,
    this.existingSummary,
    this.requestSummary,
  });

  final String kind;
  final String sourceType;
  final String sourceId;
  final String? existingSummary;
  final String? requestSummary;

  @override
  String toString() {
    final existing = existingSummary == null ? 'existing payload differs' : existingSummary;
    final requested = requestSummary == null ? 'requested payload differs' : requestSummary;
    return 'Movement identity conflict for $kind: source_type=$sourceType, '
        'source_id=$sourceId. Existing: $existing. Requested: $requested.';
  }
}

String normalizeMovementIdentity(String? sourceType, String? sourceId) {
  final normalizedType = (sourceType ?? '').trim();
  final normalizedId = (sourceId ?? '').trim();
  if (normalizedType.isEmpty || normalizedId.isEmpty) {
    return '';
  }
  return '$normalizedType:$normalizedId';
}

bool movementPayloadsMatch(Map<String, Object?> left, Map<String, Object?> right) {
  final normalizedLeft = Map<String, Object?>.from(left)
    ..remove('id')
    ..remove('created_at')
    ..remove('updated_at');
  final normalizedRight = Map<String, Object?>.from(right)
    ..remove('id')
    ..remove('created_at')
    ..remove('updated_at');
  if (normalizedLeft.length != normalizedRight.length) {
    return false;
  }
  for (final entry in normalizedLeft.entries) {
    if (!normalizedRight.containsKey(entry.key) || normalizedRight[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int dateToDatabase(DateTime value) => value.toUtc().millisecondsSinceEpoch;

DateTime dateFromDatabase(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  throw FormatException('Expected a SQLite UTC timestamp, got $value.');
}

DateTime? nullableDateFromDatabase(Object? value) =>
    value == null ? null : dateFromDatabase(value);

String requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string, got $value.');
}

int requiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) return value;
  throw FormatException('Expected "$key" to be an integer, got $value.');
}

double requiredDouble(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is num) return value.toDouble();
  throw FormatException('Expected "$key" to be numeric, got $value.');
}

bool requiredBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int && (value == 0 || value == 1)) return value == 1;
  throw FormatException('Expected "$key" to be a SQLite boolean, got $value.');
}

String? nullableString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected "$key" to be a string or null, got $value.');
}

double? nullableDouble(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Expected "$key" to be numeric or null, got $value.');
}
