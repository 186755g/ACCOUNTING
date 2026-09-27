import 'model_utils.dart';

class Supplier implements DatabaseEntity {
  Supplier({
    String? id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
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
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name.trim(),
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'created_at': dateToDatabase(createdAt),
        'updated_at': dateToDatabase(updatedAt),
      };

  factory Supplier.fromMap(Map<String, Object?> map) => Supplier(
        id: requiredString(map, 'id'),
        name: requiredString(map, 'name'),
        phone: nullableString(map, 'phone'),
        email: nullableString(map, 'email'),
        address: nullableString(map, 'address'),
        notes: nullableString(map, 'notes'),
        createdAt: dateFromDatabase(map['created_at']),
        updatedAt: dateFromDatabase(map['updated_at']),
      );
}
