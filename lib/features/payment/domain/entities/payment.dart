class Payment {
  const Payment({
    required this.id,
    required this.debtId,
    required this.amountMinor,
    required this.date,
    this.note,
    this.isEdited = false,
    required this.createdAt,
  });
  final String id, debtId;
  final int amountMinor;
  final DateTime date, createdAt;
  final String? note;
  final bool isEdited;
  factory Payment.fromMap(Map<String, Object?> row) => Payment(
    id: row['id'] as String,
    debtId: row['debt_id'] as String,
    amountMinor: row['amount_minor'] as int,
    date: DateTime.parse(row['payment_date'] as String),
    note: row['note'] as String?,
    isEdited: row['is_edited'] == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
