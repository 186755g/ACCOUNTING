import 'model_utils.dart';

class Expense implements DatabaseEntity {
  Expense({
    String? id,
    this.userId,
    required this.category,
    required this.description,
    required this.amountMinor,
    required DateTime date,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newModelId(),
        date = date.toUtc(),
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    if (category.trim().isEmpty) throw ArgumentError.value(category, 'category');
    if (description.trim().isEmpty) {
      throw ArgumentError.value(description, 'description');
    }
    if (amountMinor <= 0) throw ArgumentError.value(amountMinor, 'amountMinor');
  }

  @override
  final String id;
  final String? userId;
  final String category;
  final String description;
  final int amountMinor;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'category': category.trim(),
        'description': description.trim(),
        'amount_minor': amountMinor,
        'date_at': dateToDatabase(date),
        'notes': notes,
        'created_at': dateToDatabase(createdAt),
        'updated_at': dateToDatabase(updatedAt),
      };

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: requiredString(map, 'id'),
        userId: nullableString(map, 'user_id'),
        category: requiredString(map, 'category'),
        description: requiredString(map, 'description'),
        amountMinor: requiredInt(map, 'amount_minor'),
        date: dateFromDatabase(map['date_at']),
        notes: nullableString(map, 'notes'),
        createdAt: dateFromDatabase(map['created_at']),
        updatedAt: dateFromDatabase(map['updated_at']),
      );
}
