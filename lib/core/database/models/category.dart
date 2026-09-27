import 'model_utils.dart';

class Category implements DatabaseEntity {
  Category({
    String? id,
    required this.name,
    this.description,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newModelId(),
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
  }

  @override
  final String id;
  final String name;
  final String? description;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name.trim(),
        'description': description,
        'is_archived': isArchived ? 1 : 0,
        'created_at': dateToDatabase(createdAt),
        'updated_at': dateToDatabase(updatedAt),
      };

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: requiredString(map, 'id'),
        name: requiredString(map, 'name'),
        description: nullableString(map, 'description'),
        isArchived: requiredBool(map, 'is_archived'),
        createdAt: dateFromDatabase(map['created_at']),
        updatedAt: dateFromDatabase(map['updated_at']),
      );
}
