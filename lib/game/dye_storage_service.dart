// ============================================================================
// REPLACE THESE METHODS IN dye_storage_service.dart
// ============================================================================

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
    
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
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
          uniqueId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        }
      } catch (e) {
        uniqueId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      await prefs.setString('device_id', uniqueId);
      deviceId = uniqueId;
    }
    
    return deviceId;
  }
  
  // NEW: Check if we have internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  // UPDATED: Save with better error handling and offline queue
  Future<void> saveCraftedDye({
    required String name,
    required Color color,
    required int volume,
    required String materialQuality,
    required double crushingEfficiency,
    required double filteringPurity,
  }) async {
    final deviceId = await _getDeviceId();
    final timestamp = DateTime.now();
    
    String colorHex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
    
    final dyeData = {
      'deviceId': deviceId,
      'name': name,
      'color': colorHex,
      'volume': volume,
      'materialQuality': materialQuality,
      'crushingEfficiency': crushingEfficiency,
      'filteringPurity': filteringPurity,
      'createdAt': timestamp.toIso8601String(),
      'updatedAt': timestamp.toIso8601String(),
    };
    
    // Always cache locally first
    final tempId = 'temp_${timestamp.millisecondsSinceEpoch}';
    await _cacheDyeLocally(tempId, dyeData);
    
    // Try to save to Firestore
    final hasInternet = await _hasInternetConnection();
    
    if (hasInternet) {
      try {
        final docRef = await _firestore
            .collection('crafted_dyes')
            .add({
          ...dyeData,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });
        
        // Update local cache with real Firestore ID
        await _updateCachedDyeId(tempId, docRef.id);
        
        developer.log('Dye saved to Firestore: ${docRef.id}', name: 'DyeStorageService');
      } catch (e) {
        developer.log('Error saving to Firestore, queued for sync: $e', 
            name: 'DyeStorageService', error: e);
        // Add to offline queue
        await _addToOfflineQueue(tempId, dyeData);
      }
    } else {
      developer.log('No internet, dye queued for sync', name: 'DyeStorageService');
      // Add to offline queue
      await _addToOfflineQueue(tempId, dyeData);
    }
  }
  
  // UPDATED: Retrieve with offline support
  Future<List<Map<String, dynamic>>> getCraftedDyes() async {
    final deviceId = await _getDeviceId();
    final hasInternet = await _hasInternetConnection();
    
    if (hasInternet) {
      try {
        // Sync offline queue first
        await _syncOfflineQueue();
        
        // Get from Firestore
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
        
        // Update cache
        await _cacheAllDyes(dyes);
        
        developer.log('Loaded ${dyes.length} dyes from Firestore', name: 'DyeStorageService');
        return dyes;
      } catch (e) {
        developer.log('Error fetching from Firestore, using cache: $e', 
            name: 'DyeStorageService', error: e);
        return await _getCachedDyes();
      }
    } else {
      developer.log('No internet, using cached dyes', name: 'DyeStorageService');
      return await _getCachedDyes();
    }
  }
  
  // NEW: Sync offline queue when connection is restored
  Future<void> _syncOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_queue') ?? '[]';
      List<dynamic> queue = json.decode(queueJson);
      
      if (queue.isEmpty) return;
      
      developer.log('Syncing ${queue.length} offline dyes', name: 'DyeStorageService');
      
      List<String> syncedIds = [];
      
      for (var item in queue) {
        try {
          final tempId = item['tempId'];
          final dyeData = item['data'];
          
          // Convert string dates back to Timestamp for Firestore
          final createdAt = DateTime.parse(dyeData['createdAt']);
          final updatedAt = DateTime.parse(dyeData['updatedAt']);
          
          final docRef = await _firestore.collection('crafted_dyes').add({
            ...dyeData,
            'createdAt': createdAt,
            'updatedAt': updatedAt,
          });
          
          // Update local cache with real ID
          await _updateCachedDyeId(tempId, docRef.id);
          syncedIds.add(tempId);
          
          developer.log('Synced offline dye: $tempId -> ${docRef.id}', 
              name: 'DyeStorageService');
        } catch (e) {
          developer.log('Failed to sync item: $e', name: 'DyeStorageService', error: e);
        }
      }
      
      // Remove synced items from queue
      if (syncedIds.isNotEmpty) {
        queue.removeWhere((item) => syncedIds.contains(item['tempId']));
        await prefs.setString('offline_queue', json.encode(queue));
        developer.log('Removed ${syncedIds.length} synced items from queue', 
            name: 'DyeStorageService');
      }
    } catch (e) {
      developer.log('Error syncing offline queue: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
  // NEW: Add to offline queue
  Future<void> _addToOfflineQueue(String tempId, Map<String, dynamic> dyeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_queue') ?? '[]';
      List<dynamic> queue = json.decode(queueJson);
      
      queue.add({
        'tempId': tempId,
        'data': dyeData,
        'queuedAt': DateTime.now().toIso8601String(),
      });
      
      await prefs.setString('offline_queue', json.encode(queue));
      developer.log('Added to offline queue: $tempId', name: 'DyeStorageService');
    } catch (e) {
      developer.log('Error adding to offline queue: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
  // NEW: Update cached dye ID after Firestore sync
  Future<void> _updateCachedDyeId(String tempId, String realId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDyesJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cachedDyes = json.decode(cachedDyesJson);
      
      // Find and update the temp ID
      for (var dye in cachedDyes) {
        if (dye['id'] == tempId) {
          dye['id'] = realId;
          break;
        }
      }
      
      await prefs.setString('cached_dyes', json.encode(cachedDyes));
      developer.log('Updated cached ID: $tempId -> $realId', name: 'DyeStorageService');
    } catch (e) {
      developer.log('Error updating cached ID: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
  // UPDATED: Delete with offline support
  Future<void> deleteCraftedDye(String dyeId) async {
    try {
      final hasInternet = await _hasInternetConnection();
      
      // Remove from cache immediately
      await _removeCachedDye(dyeId);
      
      if (hasInternet) {
        // Only try Firestore if online and not a temp ID
        if (!dyeId.startsWith('temp_')) {
          await _firestore.collection('crafted_dyes').doc(dyeId).delete();
          developer.log('Dye deleted from Firestore: $dyeId', name: 'DyeStorageService');
        }
      } else {
        // Queue deletion for when online
        await _queueDeletion(dyeId);
      }
    } catch (e) {
      developer.log('Error deleting dye: $e', name: 'DyeStorageService', error: e);
    }
  }
  
  // NEW: Queue deletion for offline sync
  Future<void> _queueDeletion(String dyeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletionsJson = prefs.getString('pending_deletions') ?? '[]';
      List<dynamic> deletions = json.decode(deletionsJson);
      
      if (!deletions.contains(dyeId)) {
        deletions.add(dyeId);
        await prefs.setString('pending_deletions', json.encode(deletions));
      }
    } catch (e) {
      developer.log('Error queuing deletion: $e', name: 'DyeStorageService', error: e);
    }
  }
  
  // ============ OFFLINE CACHING METHODS ============
  
  Future<void> _cacheDyeLocally(String id, Map<String, dynamic> dyeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDyesJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cachedDyes = json.decode(cachedDyesJson);
      
      final cacheEntry = {
        'id': id,
        ...dyeData,
      };
      
      cachedDyes.add(cacheEntry);
      await prefs.setString('cached_dyes', json.encode(cachedDyes));
      developer.log('Cached dye locally: $id', name: 'DyeStorageService');
    } catch (e) {
      developer.log('Error caching dye locally: $e', 
          name: 'DyeStorageService', error: e);
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
      developer.log('Cached ${dyes.length} dyes locally', name: 'DyeStorageService');
    } catch (e) {
      developer.log('Error caching all dyes: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCachedDyes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDyesJson = prefs.getString('cached_dyes') ?? '[]';
      
      List<dynamic> cachedDyes = json.decode(cachedDyesJson);
      
      final dyes = cachedDyes.map((dye) {
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
      
      developer.log('Retrieved ${dyes.length} cached dyes', name: 'DyeStorageService');
      return dyes;
    } catch (e) {
      developer.log('Error getting cached dyes: $e', 
          name: 'DyeStorageService', error: e);
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
      developer.log('Removed cached dye: $dyeId', name: 'DyeStorageService');
    } catch (e) {
      developer.log('Error removing cached dye: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
  // NEW: Get offline queue size (for UI display)
  Future<int> getOfflineQueueSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_queue') ?? '[]';
      List<dynamic> queue = json.decode(queueJson);
      return queue.length;
    } catch (e) {
      return 0;
    }
  }
  
  // Clear all cached dyes (useful for testing)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_dyes');
    await prefs.remove('offline_queue');
    await prefs.remove('pending_deletions');
    developer.log('Cleared all cache', name: 'DyeStorageService');
  }
}