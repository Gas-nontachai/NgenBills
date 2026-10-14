import 'debt_direction.dart';

export 'debt_direction.dart';

class Debt {
  const Debt({
    required this.id,
    required this.name,
    required this.initialAmountMinor,
    this.note,
    this.iconKey = 'wallet',
    this.colorKey = 'green',
    this.direction = DebtDirection.payable,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, name, iconKey, colorKey;
  final int initialAmountMinor;
  final DebtDirection direction;
  final String? note;
  final DateTime createdAt, updatedAt;
  factory Debt.fromMap(Map<String, Object?> row) => Debt(
    direction: DebtDirection.values.byName(row['direction'] as String),
    id: row['id'] as String,
    name: row['name'] as String,
    initialAmountMinor: row['initial_amount_minor'] as int,
    note: row['note'] as String?,
    iconKey: row['icon_key'] as String? ?? 'wallet',
    colorKey: row['color_key'] as String? ?? 'green',
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
