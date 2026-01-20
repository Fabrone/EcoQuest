import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

class DyeStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // UPDATED: Get current user UID with logging
  Future<String?> _getUserId() async {
    try {
      final user = _auth.currentUser;
      developer.log('🔍 Getting user ID...', name: 'DyeStorageService');
      
      if (user != null) {
        developer.log('✅ User authenticated: ${user.uid}', name: 'DyeStorageService');
        return user.uid;
      }
      
      // If no user is logged in, try to get cached UID
      final prefs = await SharedPreferences.getInstance();
      final cachedUid = prefs.getString('cached_user_uid');
      developer.log('⚠️ No authenticated user, cached UID: $cachedUid', name: 'DyeStorageService');
      return cachedUid;
    } catch (e) {
      developer.log('❌ Error getting user ID: $e', name: 'DyeStorageService', error: e);
      return null;
    }
  }
  
  // UPDATED: Get user's display name with logging
  Future<String> _getUserName() async {
    try {
      final user = _auth.currentUser;
      developer.log('🔍 Getting user name...', name: 'DyeStorageService');
      
      if (user != null) {
        String userName = user.displayName ?? user.email ?? user.uid;
        developer.log('✅ User name: $userName', name: 'DyeStorageService');
        return userName;
      }
      
      // Fallback to cached name
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('cached_user_name') ?? 'Unknown User';
      developer.log('⚠️ Using cached user name: $cachedName', name: 'DyeStorageService');
      return cachedName;
    } catch (e) {
      developer.log('❌ Error getting user name: $e', name: 'DyeStorageService', error: e);
      return 'Unknown User';
    }
  }
  
  // Cache user info for offline use
  Future<void> _cacheUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_uid', user.uid);
        await prefs.setString(
          'cached_user_name',
          user.displayName ?? user.email ?? user.uid,
        );
        developer.log('✅ Cached user info', name: 'DyeStorageService');
      }
    } catch (e) {
      developer.log('❌ Error caching user info: $e', name: 'DyeStorageService', error: e);
    }
  }
  
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 3));
      bool hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      developer.log('🌐 Internet connection: $hasConnection', name: 'DyeStorageService');
      return hasConnection;
    } catch (e) {
      developer.log('⚠️ No internet connection: $e', name: 'DyeStorageService');
      return false;
    }
  }
  
  // UPDATED: Save with comprehensive logging
  Future<void> saveCraftedDye({
    required String name,
    required Color color,
    required int volume,
    required String materialQuality,
    required double crushingEfficiency,
    required double filteringPurity,
  }) async {
    developer.log('🚀 Starting save process for dye: $name', name: 'DyeStorageService');
    
    final userId = await _getUserId();
    
    if (userId == null) {
      developer.log('❌ No user ID - user not authenticated', name: 'DyeStorageService');
      throw Exception('User not authenticated. Please login first.');
    }
    
    developer.log('✅ User ID obtained: $userId', name: 'DyeStorageService');
    
    await _cacheUserInfo();
    
    final userName = await _getUserName();
    developer.log('👤 User name: $userName', name: 'DyeStorageService');
    
    final timestamp = DateTime.now();
    
    // Convert color to hex
    String colorHex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
    developer.log('🎨 Color hex: $colorHex', name: 'DyeStorageService');
    
    final dyeData = {
      'userId': userId,
      'userName': userName,
      'dyeName': name,
      'color': colorHex,
      'volume': volume,
      'materialQuality': materialQuality,
      'crushingEfficiency': crushingEfficiency,
      'filteringPurity': filteringPurity,
      'createdAt': timestamp.toIso8601String(),
      'updatedAt': timestamp.toIso8601String(),
    };
    
    developer.log('📦 Dye data prepared: ${json.encode(dyeData)}', name: 'DyeStorageService');
    
    // Always cache locally first
    final tempId = 'temp_${timestamp.millisecondsSinceEpoch}';
    await _cacheDyeLocally(tempId, dyeData);
    
    // Try to save to Firestore
    final hasInternet = await _hasInternetConnection();
    
    if (hasInternet) {
      try {
        developer.log('📡 Attempting to save to Firestore...', name: 'DyeStorageService');
        developer.log('📍 Collection: CraftedDyes, Document: $userName', name: 'DyeStorageService');
        
        // Use user's name as document name in "CraftedDyes" collection
        final docRef = await _firestore
            .collection('CraftedDyes')
            .doc(userName)
            .collection('dyes')
            .add({
          ...dyeData,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });
        
        developer.log('✅ Dye saved to Firestore with ID: ${docRef.id}', name: 'DyeStorageService');
        
        // Update local cache with real Firestore ID
        await _updateCachedDyeId(tempId, docRef.id);
        
        developer.log('🎉 Save process completed successfully!', name: 'DyeStorageService');
      } catch (e, stackTrace) {
        developer.log('❌ Firestore save failed: $e', name: 'DyeStorageService', error: e, stackTrace: stackTrace);
        developer.log('📥 Queuing for offline sync', name: 'DyeStorageService');
        
        // Add to offline queue
        await _addToOfflineQueue(tempId, dyeData);
      }
    } else {
      developer.log('📥 No internet - queuing for offline sync', name: 'DyeStorageService');
      await _addToOfflineQueue(tempId, dyeData);
    }
  }
  
  // UPDATED: Retrieve with comprehensive logging and null safety
  Future<List<Map<String, dynamic>>> getCraftedDyes() async {
    developer.log('🔍 Starting to fetch crafted dyes', name: 'DyeStorageService');
    
    final userId = await _getUserId();
    
    if (userId == null) {
      developer.log('⚠️ No user ID - returning cached dyes', name: 'DyeStorageService');
      return await _getCachedDyes();
    }
    
    developer.log('✅ User ID: $userId', name: 'DyeStorageService');
    
    final userName = await _getUserName();
    developer.log('👤 User name: $userName', name: 'DyeStorageService');
    
    final hasInternet = await _hasInternetConnection();
    
    if (hasInternet) {
      try {
        developer.log('🔄 Syncing offline queue first...', name: 'DyeStorageService');
        await _syncOfflineQueue();
        
        developer.log('📡 Fetching from Firestore: CraftedDyes/$userName/dyes', name: 'DyeStorageService');
        
        // Get from Firestore using user's document
        final snapshot = await _firestore
            .collection('CraftedDyes')
            .doc(userName)
            .collection('dyes')
            .orderBy('createdAt', descending: true)
            .get();
        
        developer.log('📊 Fetched ${snapshot.docs.length} documents from Firestore', name: 'DyeStorageService');
        
        final dyes = <Map<String, dynamic>>[];
        
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            developer.log('📄 Processing document ${doc.id}: ${json.encode(data)}', name: 'DyeStorageService');
            
            // FIXED: Add null safety checks
            final colorHex = data['color'] as String?;
            if (colorHex == null || colorHex.isEmpty) {
              developer.log('⚠️ Skipping document ${doc.id}: missing color', name: 'DyeStorageService');
              continue;
            }
            
            // FIXED: Safely parse color
            String cleanHex = colorHex.replaceFirst('#', '');
            if (cleanHex.length < 6) {
              developer.log('⚠️ Invalid color hex in document ${doc.id}: $colorHex', name: 'DyeStorageService');
              continue;
            }
            
            // Ensure we have 8 characters (ARGB) by padding with FF if needed
            if (cleanHex.length == 6) {
              cleanHex = 'FF$cleanHex'; // Add alpha channel
            }
            
            final dyeMap = {
              'id': doc.id,
              'name': data['dyeName'] ?? data['name'] ?? 'Unknown Dye',
              'colorHex': colorHex,
              'volume': data['volume'] ?? 0,
              'materialQuality': data['materialQuality'] ?? 'Good',
              'crushingEfficiency': (data['crushingEfficiency'] ?? 1.0).toDouble(),
              'filteringPurity': (data['filteringPurity'] ?? 1.0).toDouble(),
              'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            };
            
            dyes.add(dyeMap);
            developer.log('✅ Successfully processed document ${doc.id}', name: 'DyeStorageService');
          } catch (e, stackTrace) {
            developer.log('❌ Error processing document ${doc.id}: $e', 
                name: 'DyeStorageService', error: e, stackTrace: stackTrace);
          }
        }
        
        // Update cache
        await _cacheAllDyes(dyes);
        
        developer.log('🎉 Loaded ${dyes.length} dyes from Firestore', name: 'DyeStorageService');
        return dyes;
      } catch (e, stackTrace) {
        developer.log('❌ Error fetching from Firestore: $e', 
            name: 'DyeStorageService', error: e, stackTrace: stackTrace);
        developer.log('📂 Falling back to cached dyes', name: 'DyeStorageService');
        return await _getCachedDyes();
      }
    } else {
      developer.log('📂 No internet - using cached dyes', name: 'DyeStorageService');
      return await _getCachedDyes();
    }
  }
  
  // UPDATED: Sync with logging
  Future<void> _syncOfflineQueue() async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        developer.log('⚠️ Cannot sync: No user ID', name: 'DyeStorageService');
        return;
      }
      
      final userName = await _getUserName();
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_queue') ?? '[]';
      List<dynamic> queue = json.decode(queueJson);
      
      if (queue.isEmpty) {
        developer.log('✅ Offline queue is empty', name: 'DyeStorageService');
        return;
      }
      
      developer.log('🔄 Syncing ${queue.length} offline dyes', name: 'DyeStorageService');
      
      List<String> syncedIds = [];
      
      for (var item in queue) {
        try {
          final tempId = item['tempId'];
          final dyeData = item['data'];
          
          developer.log('⬆️ Syncing dye: $tempId', name: 'DyeStorageService');
          
          final createdAt = DateTime.parse(dyeData['createdAt']);
          final updatedAt = DateTime.parse(dyeData['updatedAt']);
          
          final docRef = await _firestore
              .collection('CraftedDyes')
              .doc(userName)
              .collection('dyes')
              .add({
            ...dyeData,
            'userId': userId,
            'userName': userName,
            'createdAt': createdAt,
            'updatedAt': updatedAt,
          });
          
          await _updateCachedDyeId(tempId, docRef.id);
          syncedIds.add(tempId);
          
          developer.log('✅ Synced: $tempId -> ${docRef.id}', name: 'DyeStorageService');
        } catch (e) {
          developer.log('❌ Failed to sync item: $e', name: 'DyeStorageService', error: e);
        }
      }
      
      if (syncedIds.isNotEmpty) {
        queue.removeWhere((item) => syncedIds.contains(item['tempId']));
        await prefs.setString('offline_queue', json.encode(queue));
        developer.log('🎉 Synced ${syncedIds.length} items', name: 'DyeStorageService');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error syncing offline queue: $e', 
          name: 'DyeStorageService', error: e, stackTrace: stackTrace);
    }
  }

  // Rest of the methods remain the same...
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
      developer.log('📥 Added to offline queue: $tempId', name: 'DyeStorageService');
    } catch (e) {
      developer.log('❌ Error adding to offline queue: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
  Future<void> _updateCachedDyeId(String tempId, String realId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDyesJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cachedDyes = json.decode(cachedDyesJson);
      
      for (var dye in cachedDyes) {
        if (dye['id'] == tempId) {
          dye['id'] = realId;
          developer.log('🔄 Updated cache ID: $tempId -> $realId', name: 'DyeStorageService');
          break;
        }
      }
      
      await prefs.setString('cached_dyes', json.encode(cachedDyes));
    } catch (e) {
      developer.log('❌ Error updating cached ID: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
  Future<void> deleteCraftedDye(String dyeId) async {
    try {
      developer.log('🗑️ Deleting dye: $dyeId', name: 'DyeStorageService');
      
      final userId = await _getUserId();
      if (userId == null) {
        throw Exception('User not authenticated. Cannot delete dye.');
      }
      
      final userName = await _getUserName();
      final hasInternet = await _hasInternetConnection();
      
      await _removeCachedDye(dyeId);
      
      if (hasInternet) {
        if (!dyeId.startsWith('temp_')) {
          await _firestore
              .collection('CraftedDyes')
              .doc(userName)
              .collection('dyes')
              .doc(dyeId)
              .delete();
          developer.log('✅ Deleted from Firestore: $dyeId', name: 'DyeStorageService');
        }
      } else {
        await _queueDeletion(dyeId);
      }
    } catch (e) {
      developer.log('❌ Error deleting dye: $e', name: 'DyeStorageService', error: e);
      rethrow;
    }
  }

  Future<bool> isUserAuthenticated() async {
    final userId = await _getUserId();
    bool isAuth = userId != null;
    developer.log('🔐 User authenticated: $isAuth', name: 'DyeStorageService');
    return isAuth;
  }
  
  Future<String?> getCurrentUserName() async {
    return await _getUserName();
  }

  Future<void> _queueDeletion(String dyeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletionsJson = prefs.getString('pending_deletions') ?? '[]';
      List<dynamic> deletions = json.decode(deletionsJson);
      
      if (!deletions.contains(dyeId)) {
        deletions.add(dyeId);
        await prefs.setString('pending_deletions', json.encode(deletions));
        developer.log('📥 Queued deletion: $dyeId', name: 'DyeStorageService');
      }
    } catch (e) {
      developer.log('❌ Error queuing deletion: $e', name: 'DyeStorageService', error: e);
    }
  }
  
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
      developer.log('💾 Cached dye locally: $id', name: 'DyeStorageService');
    } catch (e) {
      developer.log('❌ Error caching dye locally: $e', 
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
      developer.log('💾 Cached ${dyes.length} dyes locally', name: 'DyeStorageService');
    } catch (e) {
      developer.log('❌ Error caching all dyes: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCachedDyes() async {
    try {
      developer.log('📂 Retrieving cached dyes', name: 'DyeStorageService');
      
      final prefs = await SharedPreferences.getInstance();
      final cachedDyesJson = prefs.getString('cached_dyes') ?? '[]';
      
      List<dynamic> cachedDyes = json.decode(cachedDyesJson);
      
      final dyes = <Map<String, dynamic>>[];
      
      for (var dye in cachedDyes) {
        try {
          // FIXED: Add null safety
          final colorHex = dye['color'] ?? dye['colorHex'];
          if (colorHex == null || colorHex.isEmpty) {
            developer.log('⚠️ Skipping cached dye: missing color', name: 'DyeStorageService');
            continue;
          }
          
          final dyeMap = {
            'id': dye['id'] ?? 'unknown',
            'name': dye['dyeName'] ?? dye['name'] ?? 'Unknown Dye',
            'colorHex': colorHex,
            'volume': dye['volume'] ?? 0,
            'materialQuality': dye['materialQuality'] ?? 'Good',
            'crushingEfficiency': (dye['crushingEfficiency'] ?? 1.0).toDouble(),
            'filteringPurity': (dye['filteringPurity'] ?? 1.0).toDouble(),
            'createdAt': DateTime.parse(dye['createdAt'] ?? DateTime.now().toIso8601String()),
          };
          
          dyes.add(dyeMap);
        } catch (e) {
          developer.log('⚠️ Error parsing cached dye: $e', name: 'DyeStorageService', error: e);
        }
      }
      
      developer.log('📂 Retrieved ${dyes.length} cached dyes', name: 'DyeStorageService');
      return dyes;
    } catch (e) {
      developer.log('❌ Error getting cached dyes: $e', 
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
      developer.log('🗑️ Removed cached dye: $dyeId', name: 'DyeStorageService');
    } catch (e) {
      developer.log('❌ Error removing cached dye: $e', 
          name: 'DyeStorageService', error: e);
    }
  }
  
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
  
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_dyes');
    await prefs.remove('offline_queue');
    await prefs.remove('pending_deletions');
    developer.log('🧹 Cleared all cache', name: 'DyeStorageService');
  }
}