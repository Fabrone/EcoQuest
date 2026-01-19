import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

class DyeStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get unique device ID
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we already have a stored device ID
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      // Generate a new unique ID based on device info + timestamp
      final deviceInfo = DeviceInfoPlugin();
      String uniqueId;
      
      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          uniqueId = 'android_${androidInfo.id}_${DateTime.now().millisecondsSinceEpoch}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          uniqueId = 'ios_${iosInfo.identifierForVendor}_${DateTime.now().millisecondsSinceEpoch}';
        } else {
          // Fallback for other platforms
          uniqueId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        }
      } catch (e) {
        // If device info fails, use timestamp-based ID
        uniqueId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Store for future use
      await prefs.setString('device_id', uniqueId);
      deviceId = uniqueId;
    }
    
    return deviceId;
  }
  
  // Save a crafted dye to Firestore
  Future<void> saveCraftedDye({
    required String name,
    required Color color,
    required int volume,
    required String materialQuality,
    required double crushingEfficiency,
    required double filteringPurity,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final timestamp = DateTime.now();
      
      // Convert Color to hex string for storage using toARGB32()
      String colorHex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
      
      final dyeData = {
        'deviceId': deviceId,
        'name': name,
        'color': colorHex,
        'volume': volume,
        'materialQuality': materialQuality,
        'crushingEfficiency': crushingEfficiency,
        'filteringPurity': filteringPurity,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };
      
      // Save to Firestore - single collection for all dyes
      final docRef = await _firestore
          .collection('crafted_dyes')
          .add(dyeData);
      
      // Cache locally for offline access
      await _cacheDyeLocally(docRef.id, dyeData);
      
      developer.log('Dye saved successfully: ${docRef.id}', name: 'DyeStorageService');
    } catch (e) {
      developer.log('Error saving dye to Firestore: $e', name: 'DyeStorageService', error: e);
      // If Firestore fails, still cache locally
      await _cacheDyeLocally(
        DateTime.now().millisecondsSinceEpoch.toString(),
        {
          'name': name,
          'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
          'volume': volume,
          'materialQuality': materialQuality,
          'crushingEfficiency': crushingEfficiency,
          'filteringPurity': filteringPurity,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
    }
  }
  
  // Retrieve all crafted dyes for current device
  Future<List<Map<String, dynamic>>> getCraftedDyes() async {
    try {
      final deviceId = await _getDeviceId();
      
      // Try to get from Firestore first
      final snapshot = await _firestore
          .collection('crafted_dyes')
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final dyes = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'colorHex': data['color'],
          'volume': data['volume'],
          'materialQuality': data['materialQuality'] ?? 'Good',
          'crushingEfficiency': data['crushingEfficiency'] ?? 1.0,
          'filteringPurity': data['filteringPurity'] ?? 1.0,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
      
      // Cache for offline access
      await _cacheAllDyes(dyes);
      
      return dyes;
    } catch (e) {
      developer.log('Error fetching dyes from Firestore: $e', name: 'DyeStorageService', error: e);
      // Fallback to cached data
      return await _getCachedDyes();
    }
  }
  
  // Delete a specific dye
  Future<void> deleteCraftedDye(String dyeId) async {
    try {
      await _firestore
          .collection('crafted_dyes')
          .doc(dyeId)
          .delete();
      
      // Remove from cache
      await _removeCachedDye(dyeId);
      
      developer.log('Dye deleted successfully: $dyeId', name: 'DyeStorageService');
    } catch (e) {
      developer.log('Error deleting dye: $e', name: 'DyeStorageService', error: e);
    }
  }
  
  // Update dye volume (if user wants to use some dye)
  Future<void> updateDyeVolume(String dyeId, int newVolume) async {
    try {
      await _firestore
          .collection('crafted_dyes')
          .doc(dyeId)
          .update({
        'volume': newVolume,
        'updatedAt': DateTime.now(),
      });
      
      developer.log('Dye volume updated: $dyeId', name: 'DyeStorageService');
    } catch (e) {
      developer.log('Error updating dye volume: $e', name: 'DyeStorageService', error: e);
    }
  }
  
  // ============ OFFLINE CACHING METHODS ============
  
  Future<void> _cacheDyeLocally(String id, Map<String, dynamic> dyeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing cached dyes
      final cachedDyesJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cachedDyes = json.decode(cachedDyesJson);
      
      // Add new dye with proper serialization
      final cacheEntry = {
        'id': id,
        ...dyeData,
        'createdAt': dyeData['createdAt'] is DateTime
            ? (dyeData['createdAt'] as DateTime).toIso8601String()
            : dyeData['createdAt'],
      };
      
      cachedDyes.add(cacheEntry);
      
      // Save back to SharedPreferences
      await prefs.setString('cached_dyes', json.encode(cachedDyes));
    } catch (e) {
      developer.log('Error caching dye locally: $e', name: 'DyeStorageService', error: e);
    }
  }
  
  Future<void> _cacheAllDyes(List<Map<String, dynamic>> dyes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final serializedDyes = dyes.map((dye) {
        return {
          ...dye,
          'createdAt': dye['createdAt'] is DateTime
              ? (dye['createdAt'] as DateTime).toIso8601String()
              : dye['createdAt'],
        };
      }).toList();
      
      await prefs.setString('cached_dyes', json.encode(serializedDyes));
    } catch (e) {
      developer.log('Error caching all dyes: $e', name: 'DyeStorageService', error: e);
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCachedDyes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDyesJson = prefs.getString('cached_dyes') ?? '[]';
      
      List<dynamic> cachedDyes = json.decode(cachedDyesJson);
      
      return cachedDyes.map((dye) {
        return {
          'id': dye['id'],
          'name': dye['name'],
          'colorHex': dye['color'] ?? dye['colorHex'],
          'volume': dye['volume'],
          'materialQuality': dye['materialQuality'] ?? 'Good',
          'crushingEfficiency': dye['crushingEfficiency'] ?? 1.0,
          'filteringPurity': dye['filteringPurity'] ?? 1.0,
          'createdAt': DateTime.parse(dye['createdAt']),
        };
      }).toList();
    } catch (e) {
      developer.log('Error getting cached dyes: $e', name: 'DyeStorageService', error: e);
      return [];
    }
  }
  
  Future<void> _removeCachedDye(String dyeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDyesJson = prefs.getString('cached_dyes') ?? '[]';
      
      List<dynamic> cachedDyes = json.decode(cachedDyesJson);
      cachedDyes.removeWhere((dye) => dye['id'] == dyeId);
      
      await prefs.setString('cached_dyes', json.encode(cachedDyes));
    } catch (e) {
      developer.log('Error removing cached dye: $e', name: 'DyeStorageService', error: e);
    }
  }
  
  // Clear all cached dyes (useful for testing)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_dyes');
  }
}