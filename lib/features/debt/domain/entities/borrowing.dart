class Borrowing {
  const Borrowing({
    required this.id,
    required this.debtId,
    required this.amountMinor,
    required this.date,
    this.note,
    required this.createdAt,
  });
  final String id, debtId;
  final int amountMinor;
  final DateTime date, createdAt;
  final String? note;
  factory Borrowing.fromMap(Map<String, Object?> row) => Borrowing(
    id: row['id'] as String,
    debtId: row['debt_id'] as String,
    amountMinor: row['amount_minor'] as int,
    date: DateTime.parse(row['borrowing_date'] as String),
    note: row['note'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
