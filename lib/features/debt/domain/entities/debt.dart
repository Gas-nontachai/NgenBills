class Debt {
  const Debt({
    required this.id,
    required this.name,
    required this.initialAmountMinor,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, name;
  final int initialAmountMinor;
  final String? note;
  final DateTime createdAt, updatedAt;
  factory Debt.fromMap(Map<String, Object?> row) => Debt(
    id: row['id'] as String,
    name: row['name'] as String,
    initialAmountMinor: row['initial_amount_minor'] as int,
    note: row['note'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
