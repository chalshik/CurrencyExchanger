import 'package:flutter/foundation.dart';

class CurrencyModel {
  final String? id;  // Firestore document ID (same as code)
  final String? code;  // Currency code (e.g. "USD", "SOM")
  final double quantity;
  final double defaultBuyRate;
  final double defaultSellRate;
  final DateTime updatedAt;
  final String? companyId;  // Reference to parent company

  CurrencyModel({
    this.id,
    this.code,
    this.quantity = 0.0,
    this.defaultBuyRate = 0.0,
    this.defaultSellRate = 0.0,
    DateTime? updatedAt,
    this.companyId,
  }) : updatedAt = updatedAt ?? DateTime.now();

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'quantity': quantity,
      'default_buy_rate': defaultBuyRate,
      'default_sell_rate': defaultSellRate,
      'updated_at': updatedAt.toIso8601String(),
      if (companyId != null) 'company_id': companyId,
    };
  }

  // Create from Firestore data
  factory CurrencyModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CurrencyModel(
      id: id,
      code: data['code'] as String?,
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      defaultBuyRate: (data['default_buy_rate'] as num?)?.toDouble() ?? 0.0,
      defaultSellRate: (data['default_sell_rate'] as num?)?.toDouble() ?? 0.0,
      updatedAt: data['updated_at'] != null 
          ? DateTime.tryParse(data['updated_at']) ?? DateTime.now()
          : DateTime.now(),
      companyId: data['company_id'] as String?,
    );
  }

  // Create a copy with some updated fields
  CurrencyModel copyWith({
    String? id,
    String? code,
    double? quantity,
    double? defaultBuyRate,
    double? defaultSellRate,
    DateTime? updatedAt,
    String? companyId,
  }) {
    return CurrencyModel(
      id: id ?? this.id,
      code: code ?? this.code,
      quantity: quantity ?? this.quantity,
      defaultBuyRate: defaultBuyRate ?? this.defaultBuyRate,
      defaultSellRate: defaultSellRate ?? this.defaultSellRate,
      updatedAt: updatedAt ?? this.updatedAt,
      companyId: companyId ?? this.companyId,
    );
  }

  // Check if this is the base currency (SOM)
  bool get isBaseCurrency => code == 'SOM';

  @override
  String toString() {
    return 'CurrencyModel(code: $code, quantity: $quantity)';
  }
}
