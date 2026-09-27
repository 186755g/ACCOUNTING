import 'model_utils.dart';

class User implements DatabaseEntity {
  User({
    String? id,
    required this.name,
    this.email,
    this.role = 'owner',
    this.isActive = true,
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
  final String? email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name.trim(),
        'email': email,
        'role': role,
        'is_active': isActive ? 1 : 0,
        'created_at': dateToDatabase(createdAt),
        'updated_at': dateToDatabase(updatedAt),
      };

  factory User.fromMap(Map<String, Object?> map) => User(
        id: requiredString(map, 'id'),
        name: requiredString(map, 'name'),
        email: nullableString(map, 'email'),
        role: requiredString(map, 'role'),
        isActive: requiredBool(map, 'is_active'),
        createdAt: dateFromDatabase(map['created_at']),
        updatedAt: dateFromDatabase(map['updated_at']),
      );
}
