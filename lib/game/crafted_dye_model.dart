import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Model for a crafted dye with all relevant fields
class CraftedDyeModel {
  final String? id; // Firestore auto-generated ID
  final String userName; // User's username
  final String userId; // User's Firebase Auth UID
  final String dyeName; // e.g., "Green Dye", "Purple Dye"
  final String colorHex; // e.g., "#FF00FF00"
  final int volume; // Volume in ml
  final String materialQuality; // e.g., "Premium Harvest"
  final double crushingEfficiency; // 0.0 - 2.0
  final double filteringPurity; // 0.0 - 1.0
  final DateTime craftedAt; // When the dye was created
  final DateTime updatedAt; // Last update timestamp

  CraftedDyeModel({
    this.id,
    required this.userName,
    required this.userId,
    required this.dyeName,
    required this.colorHex,
    required this.volume,
    required this.materialQuality,
    required this.crushingEfficiency,
    required this.filteringPurity,
    required this.craftedAt,
    required this.updatedAt,
  });

  /// Convert Flutter Color to hex string
  static String colorToHex(Color color) {
    // ignore: deprecated_member_use
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// Convert hex string to Flutter Color
  static Color hexToColor(String hex) {
    String cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex'; // Add alpha channel
    }
    return Color(int.parse(cleanHex, radix: 16));
  }

  /// Create model from Firestore document
  factory CraftedDyeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CraftedDyeModel(
      id: doc.id,
      userName: data['userName'] ?? 'Unknown',
      userId: data['userId'] ?? '',
      dyeName: data['dyeName'] ?? 'Unknown Dye',
      colorHex: data['colorHex'] ?? '#FF000000',
      volume: data['volume'] ?? 0,
      materialQuality: data['materialQuality'] ?? 'Basic',
      crushingEfficiency: (data['crushingEfficiency'] ?? 1.0).toDouble(),
      filteringPurity: (data['filteringPurity'] ?? 1.0).toDouble(),
      craftedAt: (data['craftedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document format
  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'userId': userId,
      'dyeName': dyeName,
      'colorHex': colorHex,
      'volume': volume,
      'materialQuality': materialQuality,
      'crushingEfficiency': crushingEfficiency,
      'filteringPurity': filteringPurity,
      'craftedAt': Timestamp.fromDate(craftedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convert to cache-friendly JSON (uses ISO8601 strings)
  Map<String, dynamic> toCache() {
    return {
      'id': id,
      'userName': userName,
      'userId': userId,
      'dyeName': dyeName,
      'colorHex': colorHex,
      'volume': volume,
      'materialQuality': materialQuality,
      'crushingEfficiency': crushingEfficiency,
      'filteringPurity': filteringPurity,
      'craftedAt': craftedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create model from cached JSON
  factory CraftedDyeModel.fromCache(Map<String, dynamic> json) {
    return CraftedDyeModel(
      id: json['id'],
      userName: json['userName'] ?? 'Unknown',
      userId: json['userId'] ?? '',
      dyeName: json['dyeName'] ?? 'Unknown Dye',
      colorHex: json['colorHex'] ?? '#FF000000',
      volume: json['volume'] ?? 0,
      materialQuality: json['materialQuality'] ?? 'Basic',
      crushingEfficiency: (json['crushingEfficiency'] ?? 1.0).toDouble(),
      filteringPurity: (json['filteringPurity'] ?? 1.0).toDouble(),
      craftedAt: DateTime.parse(json['craftedAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Get the Flutter Color object
  Color get color => hexToColor(colorHex);

  /// Create a copy with updated fields
  CraftedDyeModel copyWith({
    String? id,
    String? userName,
    String? userId,
    String? dyeName,
    String? colorHex,
    int? volume,
    String? materialQuality,
    double? crushingEfficiency,
    double? filteringPurity,
    DateTime? craftedAt,
    DateTime? updatedAt,
  }) {
    return CraftedDyeModel(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userId: userId ?? this.userId,
      dyeName: dyeName ?? this.dyeName,
      colorHex: colorHex ?? this.colorHex,
      volume: volume ?? this.volume,
      materialQuality: materialQuality ?? this.materialQuality,
      crushingEfficiency: crushingEfficiency ?? this.crushingEfficiency,
      filteringPurity: filteringPurity ?? this.filteringPurity,
      craftedAt: craftedAt ?? this.craftedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}