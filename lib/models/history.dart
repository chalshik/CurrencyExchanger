import 'package:flutter/foundation.dart';

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
      currencyCode: map['currency_code'] ?? '',
      operationType: map['operation_type'] ?? '',
      rate: map['rate'] is double
          ? map['rate']
          : double.tryParse(map['rate'].toString()) ?? 0.0,
      quantity: map['quantity'] is double
          ? map['quantity']
          : double.tryParse(map['quantity'].toString()) ?? 0.0,
      total: map['total'] is double
          ? map['total']
          : double.tryParse(map['total'].toString()) ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'HistoryModel(id: $id, currencyCode: $currencyCode, operationType: $operationType, rate: $rate, quantity: $quantity, total: $total, createdAt: $createdAt)';
  }
}
