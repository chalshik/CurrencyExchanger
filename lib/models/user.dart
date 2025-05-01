import 'package:flutter/foundation.dart';

class UserModel {
  final String? id;  // Firestore document ID
  final String? uid; // Firebase Auth UID
  final String username;
  final String password;
  final String role;  // "superadmin", "admin", or "user"
  final DateTime createdAt;
  final String? companyId;  // Reference to parent company
  final String? companyName;

  UserModel({
    this.id,
    this.uid,
    required this.username,
    required this.password,
    this.role = 'user',
    DateTime? createdAt,
    this.companyId,
    this.companyName,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert a UserModel to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      if (uid != null) 'uid': uid,
      if (companyId != null) 'company_id': companyId,
      if (companyName != null) 'company_name': companyName,
    };
  }

  // Create UserModel from Firestore doc
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      uid: data['uid'] as String?,
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      role: data['role'] ?? 'user',
      createdAt: data['created_at'] != null 
          ? DateTime.tryParse(data['created_at']) ?? DateTime.now()
          : DateTime.now(),
      companyId: data['company_id'] as String?,
      companyName: data['company_name'] as String?,
    );
  }

  // Create a copy with some updated fields
  UserModel copyWith({
    String? id,
    String? uid,
    String? username,
    String? password,
    String? role,
    DateTime? createdAt,
    String? companyId,
    String? companyName,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
    );
  }

  // Check if user is a superadmin
  bool get isSuperAdmin => role == 'superadmin';
  
  // Check if user is a company admin
  bool get isCompanyAdmin => role == 'admin';
  
  // Check if user belongs to a company
  bool get hasCompany => companyId != null;
}
