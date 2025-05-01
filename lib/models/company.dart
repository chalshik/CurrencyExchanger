import 'package:flutter/foundation.dart';

class CompanyModel {
  final String? id; // Firestore document ID
  final String name;
  final String? ownerId;
  final DateTime createdAt;

  CompanyModel({
    this.id,
    required this.name,
    this.ownerId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from Firestore data
  factory CompanyModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CompanyModel(
      id: id,
      name: data['name'] ?? '',
      ownerId: data['owner_id'],
      createdAt:
          data['created_at'] != null
              ? DateTime.tryParse(data['created_at']) ?? DateTime.now()
              : DateTime.now(),
    );
  }

  // Create a copy with some updated fields
  CompanyModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    DateTime? createdAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'CompanyModel(id: $id, name: $name, ownerId: $ownerId)';
  }
} 