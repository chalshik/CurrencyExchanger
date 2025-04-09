import 'package:flutter/foundation.dart';

class UserModel {
  final String? id; // Firestore document ID
  final String? uid; // Firebase Auth UID
  final String username;
  final String password;
  final String role;
  final DateTime createdAt;

  UserModel({
    this.id,
    this.uid,
    required this.username,
    required this.password,
    this.role = 'user',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert a UserModel to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      if (uid != null) 'uid': uid,
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
      createdAt:
          data['created_at'] != null
              ? DateTime.tryParse(data['created_at']) ?? DateTime.now()
              : DateTime.now(),
    );
  }

  // Optional: update fields
  UserModel copyWith({
    String? id,
    String? uid,
    String? username,
    String? password,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
