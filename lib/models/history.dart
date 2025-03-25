class HistoryModel {
  final int? id;
  final String currencyCode;
  final String operationType;
  final double rate;
  final double quantity;
  final double total;
  final DateTime createdAt;

  HistoryModel({
    this.id,
    required this.currencyCode,
    required this.operationType,
    required this.rate,
    required this.quantity,
    required this.total,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currency_code': currencyCode,
      'operation_type': operationType,
      'rate': rate,
      'quantity': quantity,
      'total': total,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HistoryModel.fromMap(Map<String, dynamic> map) {
    return HistoryModel(
      id: map['id'],
      currencyCode: map['currency_code'],
      operationType: map['operation_type'],
      rate: map['rate'],
      quantity: map['quantity'],
      total: map['total'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
