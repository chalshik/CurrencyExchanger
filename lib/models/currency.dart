import 'package:flutter/foundation.dart';

class CurrencyModel {
  final int? id;
  final String? code;
  final double quantity;
  final DateTime updatedAt;

  CurrencyModel({
    this.id,
    required this.code,
    this.quantity = 0.0,
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
      quantity: map['quantity'] is double
          ? map['quantity']
          : double.tryParse(map['quantity'].toString()) ?? 0.0,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'CurrencyModel(id: $id, code: $code, quantity: $quantity, updatedAt: $updatedAt)';
  }
}
