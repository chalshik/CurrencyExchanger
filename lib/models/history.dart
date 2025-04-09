class HistoryModel {
  final String? id; // Firestore document ID
  final String currencyCode;
  final String operationType;
  final double rate;
  final double quantity;
  final double total;
  final DateTime createdAt;
  final String username;

  HistoryModel({
    this.id,
    required this.currencyCode,
    required this.operationType,
    required this.rate,
    required this.quantity,
    required this.total,
    DateTime? createdAt,
    required this.username,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Firestore-friendly map
  Map<String, dynamic> toMap() {
    return {
      'currency_code': currencyCode,
      'operation_type': operationType,
      'rate': rate,
      'quantity': quantity,
      'total': total,
      'created_at': createdAt.toIso8601String(),
      'username': username,
    };
  }

  // Convert from Firestore data + doc ID
  factory HistoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return HistoryModel(
      id: id,
      currencyCode: data['currency_code'] ?? '',
      operationType: data['operation_type'] ?? '',
      rate: (data['rate'] as num?)?.toDouble() ?? 0.0,
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      createdAt:
          data['created_at'] != null
              ? DateTime.tryParse(data['created_at']) ?? DateTime.now()
              : DateTime.now(),
      username: data['username'] ?? '',
    );
  }

  @override
  String toString() {
    return 'HistoryModel(id: $id, currencyCode: $currencyCode, operationType: $operationType, rate: $rate, quantity: $quantity, total: $total, createdAt: $createdAt, username: $username)';
  }
}

extension HistoryModelCopy on HistoryModel {
  HistoryModel copyWith({
    String? id,
    String? currencyCode,
    String? operationType,
    double? rate,
    double? quantity,
    double? total,
    DateTime? createdAt,
    String? username,
  }) {
    return HistoryModel(
      id: id ?? this.id,
      currencyCode: currencyCode ?? this.currencyCode,
      operationType: operationType ?? this.operationType,
      rate: rate ?? this.rate,
      quantity: quantity ?? this.quantity,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
    );
  }
}
