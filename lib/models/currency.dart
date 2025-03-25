class CurrencyModel {
  final int? id;
  final String code;
  final double quantity;
  final DateTime updatedAt;

  CurrencyModel({
    this.id,
    required this.code,
    required this.quantity,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'quantity': quantity,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CurrencyModel.fromMap(Map<String, dynamic> map) {
    return CurrencyModel(
      id: map['id'],
      code: map['code'],
      quantity: map['quantity'],
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
