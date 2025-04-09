import 'package:flutter/foundation.dart';

class CurrencyModel {
  final int? id;
  final String? code;
  final double quantity;
  final DateTime updatedAt;
  final double defaultBuyRate;
  final double defaultSellRate;

  CurrencyModel({
    this.id,
    required this.code,
    this.quantity = 0.0,
    DateTime? updatedAt,
    this.defaultBuyRate = 0.0,
    this.defaultSellRate = 0.0,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'quantity': quantity,
      'updated_at': updatedAt.toIso8601String(),
      'default_buy_rate': defaultBuyRate,
      'default_sell_rate': defaultSellRate,
    };
  }

  factory CurrencyModel.fromMap(Map<String, dynamic> map) {
    return CurrencyModel(
      id: map['id'],
      code: map['code'],
      quantity:
          map['quantity'] is double
              ? map['quantity']
              : double.tryParse(map['quantity'].toString()) ?? 0.0,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.parse(map['updated_at'])
              : DateTime.now(),
      defaultBuyRate:
          map['default_buy_rate'] is double
              ? map['default_buy_rate']
              : double.tryParse(map['default_buy_rate'].toString()) ?? 0.0,
      defaultSellRate:
          map['default_sell_rate'] is double
              ? map['default_sell_rate']
              : double.tryParse(map['default_sell_rate'].toString()) ?? 0.0,
    );
  }

  // Create CurrencyModel from Firestore doc
  factory CurrencyModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CurrencyModel(
      id: int.tryParse(id),
      code: data['code'],
      quantity:
          data['quantity'] is double
              ? data['quantity']
              : double.tryParse(data['quantity'].toString()) ?? 0.0,
      updatedAt:
          data['updated_at'] != null
              ? DateTime.parse(data['updated_at'])
              : DateTime.now(),
      defaultBuyRate:
          data['default_buy_rate'] is double
              ? data['default_buy_rate']
              : double.tryParse(data['default_buy_rate'].toString()) ?? 0.0,
      defaultSellRate:
          data['default_sell_rate'] is double
              ? data['default_sell_rate']
              : double.tryParse(data['default_sell_rate'].toString()) ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'CurrencyModel(id: $id, code: $code, quantity: $quantity, updatedAt: $updatedAt, defaultBuyRate: $defaultBuyRate, defaultSellRate: $defaultSellRate)';
  }
}
