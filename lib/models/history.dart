import 'package:flutter/foundation.dart';

class HistoryModel {
  final String? id;  // Firestore document ID
  final String currencyCode;
  final String operationType;  // "Purchase", "Sale", or "Deposit"
  final double rate;
  final double quantity;
  final double total;
  final DateTime createdAt;
  final String username;
  final String? companyId;  // Reference to parent company

  HistoryModel({
    this.id,
    required this.currencyCode,
    required this.operationType,
    required this.rate,
    required this.quantity,
    required this.total,
    DateTime? createdAt,
    required this.username,
    this.companyId,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'currency_code': currencyCode,
      'operation_type': operationType,
      'rate': rate,
      'quantity': quantity,
      'total': total,
      'created_at': createdAt.toIso8601String(),
      'username': username,
      if (companyId != null) 'company_id': companyId,
    };
  }

  // Create from Firestore data
  factory HistoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return HistoryModel(
      id: id,
      currencyCode: data['currency_code'] ?? '',
      operationType: data['operation_type'] ?? '',
      rate: (data['rate'] as num?)?.toDouble() ?? 0.0,
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: data['created_at'] != null 
          ? DateTime.tryParse(data['created_at']) ?? DateTime.now()
          : DateTime.now(),
      username: data['username'] ?? '',
      companyId: data['company_id'] as String?,
    );
  }

  // Create a copy with some updated fields
  HistoryModel copyWith({
    String? id,
    String? currencyCode,
    String? operationType,
    double? rate,
    double? quantity,
    double? total,
    DateTime? createdAt,
    String? username,
    String? companyId,
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
      companyId: companyId ?? this.companyId,
    );
  }

  @override
  String toString() {
    return 'HistoryModel(currencyCode: $currencyCode, operationType: $operationType, quantity: $quantity, total: $total)';
  }
}
