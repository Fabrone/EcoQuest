import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecoquest/game/crafted_dye_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

class DyeStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> _getUserId() async {
    try {
      final user = _auth.currentUser;
      if (user != null) return user.uid;
      
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_user_uid');
    } catch (e) {
      developer.log('❌ Error getting user ID: $e', name: 'DyeStorage');
      return null;
    }
  }
  
  Future<String> _getUserName() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return user.displayName ?? user.email ?? user.uid;
      }
      
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_user_name') ?? 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }
  
  Future<void> _cacheUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_uid', user.uid);
        await prefs.setString('cached_user_name', 
            user.displayName ?? user.email ?? user.uid);
      }
    } catch (e) {
      developer.log('❌ Cache user error: $e', name: 'DyeStorage');
    }
  }
    
  Future<bool> _hasInternetConnection() async {
    try {
      // WEB PLATFORM: Check using browser's navigator.onLine
      if (kIsWeb) {
        try {
          // Check browser's online status
          final isOnline = html.window.navigator.onLine ?? true;
          developer.log('🌐 Web platform - Navigator.onLine: $isOnline', name: 'DyeStorage');
          
          // Additional check: try to access Firestore directly
          if (isOnline) {
            try {
              // Quick Firestore ping to verify actual connectivity
              await _firestore
                  .collection('CraftedDyes')
                  .limit(1)
                  .get(const GetOptions(source: Source.server))
                  .timeout(const Duration(seconds: 5));
              
              developer.log('✅ Web: Firestore accessible', name: 'DyeStorage');
              return true;
            } catch (e) {
              developer.log('⚠️ Web: Firestore not accessible: $e', name: 'DyeStorage');
              return false;
            }
          }
          
          return isOnline;
        } catch (e) {
          developer.log('⚠️ Web check failed: $e - Assuming online', name: 'DyeStorage');
          // If check fails, assume online for web
          return true;
        }
      }
      
      // MOBILE PLATFORM: Use InternetAddress lookup
      else {
        try {
          final result = await InternetAddress.lookup('google.com')
              .timeout(const Duration(seconds: 5));
          final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
          developer.log('📱 Mobile platform - Connected: $isConnected', name: 'DyeStorage');
          return isConnected;
        } on SocketException catch (_) {
          developer.log('📱 Mobile: No internet (SocketException)', name: 'DyeStorage');
          return false;
        } catch (e) {
          developer.log('⚠️ Mobile check failed: $e - Assuming online', name: 'DyeStorage');
          return true;
        }
      }
    } catch (e) {
      developer.log('❌ Connection check error: $e - Defaulting to online', name: 'DyeStorage');
      // Default to true (online) if check fails to prevent blocking saves
      return true;
    }
  }

  Future<void> verifyFirebaseSetup() async {
    developer.log('🔍 VERIFYING FIREBASE', name: 'DyeStorage');
    try {
      developer.log('📱 App: ${_firestore.app.name}', name: 'DyeStorage');
      developer.log('📱 Project: ${_firestore.app.options.projectId}', name: 'DyeStorage');
      
      final user = _auth.currentUser;
      if (user != null) {
        developer.log('✅ User: ${user.uid}', name: 'DyeStorage');
      } else {
        developer.log('❌ No user signed in', name: 'DyeStorage');
      }
      
      final test = await _firestore.collection('CraftedDyes').limit(1)
          .get(const GetOptions(source: Source.server));
      developer.log('✅ Firestore OK (${test.docs.length} docs)', name: 'DyeStorage');
    } catch (e) {
      developer.log('❌ Verification failed: $e', name: 'DyeStorage');
    }
  }

  Future<void> saveCraftedDye({
    required String name,
    required Color color,
    required int volume,
    required String materialQuality,
    required double crushingEfficiency,
    required double filteringPurity,
  }) async {
    developer.log('🚀 SAVING DYE: $name', name: 'DyeStorage');
    developer.log('⏰ Starting save at: ${DateTime.now()}', name: 'DyeStorage');
    developer.log('🖥️ Platform: ${kIsWeb ? "Web" : "Mobile"}', name: 'DyeStorage');
    
    // Get user info
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated. Please log in.');
    }
    
    await _cacheUserInfo();
    final userName = await _getUserName();
    
    developer.log('👤 User: $userName (ID: $userId)', name: 'DyeStorage');
    
    // Create the dye model
    final now = DateTime.now();
    final dyeModel = CraftedDyeModel(
      userName: userName,
      userId: userId,
      dyeName: name,
      colorHex: CraftedDyeModel.colorToHex(color),
      volume: volume,
      materialQuality: materialQuality,
      crushingEfficiency: crushingEfficiency,
      filteringPurity: filteringPurity,
      craftedAt: now,
      updatedAt: now,
    );
    
    developer.log('🎨 Color: ${dyeModel.colorHex}', name: 'DyeStorage');
    
    // ATTEMPT FIRESTORE SAVE DIRECTLY (let Firestore SDK handle connectivity)
    try {
      developer.log('📡 Attempting Firestore save...', name: 'DyeStorage');
      developer.log('📁 Path: CraftedDyes/{auto-generated-id}', name: 'DyeStorage');
      
      // Save to Firestore with timeout
      final docRef = await _firestore
          .collection('CraftedDyes')
          .add(dyeModel.toFirestore())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Firestore save timed out after 10 seconds');
            },
          );
      
      developer.log('🎉 FIRESTORE SUCCESS!', name: 'DyeStorage');
      developer.log('📄 Document ID: ${docRef.id}', name: 'DyeStorage');
      developer.log('📍 Full path: ${docRef.path}', name: 'DyeStorage');
      
      // Update model with Firestore ID
      final savedDye = dyeModel.copyWith(id: docRef.id);
      
      // Cache AFTER successful Firestore save
      await _cacheDyeLocally(savedDye);
      developer.log('✅ Cached locally after Firestore save', name: 'DyeStorage');
      
      // Success - return without throwing
      return;
      
    } on FirebaseException catch (e) {
      developer.log('❌ Firebase Error Code: ${e.code}', name: 'DyeStorage');
      developer.log('❌ Firebase Message: ${e.message}', name: 'DyeStorage');
      
      if (e.code == 'permission-denied') {
        developer.log('🔒 PERMISSION DENIED - Check Firestore rules', name: 'DyeStorage');
        
        // Queue for retry but don't throw - cache locally
        await _addToOfflineQueue(dyeModel);
        
        throw Exception(
          'Permission denied. Your dye has been saved locally and will sync when permissions are fixed.'
        );
      } else if (e.code == 'unavailable') {
        // Network error - queue for sync
        developer.log('🌐 Network unavailable - queuing for sync', name: 'DyeStorage');
        await _addToOfflineQueue(dyeModel);
        
        throw Exception(
          'Network unavailable. Your dye has been saved locally and will sync when you\'re back online.'
        );
      } else {
        // Other Firebase errors
        developer.log('📤 Queuing for offline sync due to error', name: 'DyeStorage');
        await _addToOfflineQueue(dyeModel);
        
        throw Exception(
          'Save error: ${e.message}. Your dye has been saved locally and will sync later.'
        );
      }
      
    } on TimeoutException catch (e) {
      developer.log('⏱️ Firestore save timed out: $e', name: 'DyeStorage');
      
      // Timeout - likely network issue, queue for sync
      await _addToOfflineQueue(dyeModel);
      
      throw Exception(
        'Connection timeout. Your dye has been saved locally and will sync when connection improves.'
      );
      
    } catch (e, stackTrace) {
      developer.log('❌ Unexpected error: $e', name: 'DyeStorage');
      developer.log('❌ Stack: $stackTrace', name: 'DyeStorage');
      
      // Unknown error - queue for sync
      await _addToOfflineQueue(dyeModel);
      
      throw Exception(
        'Unexpected error: ${e.toString()}. Your dye has been saved locally and will sync later.'
      );
    }
  }

  Future<void> retryFailedSaves() async {
    developer.log('🔄 Attempting to retry failed saves...', name: 'DyeStorage');
    
    if (!await _hasInternetConnection()) {
      developer.log('🔴 Still offline - skipping retry', name: 'DyeStorage');
      return;
    }
    
    try {
      await _syncOfflineQueue();
      await _processPendingDeletions();
      developer.log('✅ Retry completed successfully', name: 'DyeStorage');
    } catch (e) {
      developer.log('❌ Retry failed: $e', name: 'DyeStorage');
    }
  }
      
  Future<List<Map<String, dynamic>>> getCraftedDyes() async {
    developer.log('📖 Fetching dyes', name: 'DyeStorage');
    
    final userId = await _getUserId();
    if (userId == null) {
      developer.log('⚠️ No user ID - returning cached', name: 'DyeStorage');
      return await _getCachedDyes();
    }
    
    final userName = await _getUserName();
    final hasInternet = await _hasInternetConnection();
    
    developer.log('👤 User: $userName', name: 'DyeStorage');
    developer.log('🌐 Internet: $hasInternet', name: 'DyeStorage');
    
    if (hasInternet) {
      try {
        // Try to sync offline queue first
        await _syncOfflineQueue();
        
        developer.log('📡 Querying Firestore...', name: 'DyeStorage');
        developer.log('🔍 Filter: userName == $userName', name: 'DyeStorage');
        
        // Query Firestore for this user's dyes
        final snapshot = await _firestore
            .collection('CraftedDyes')
            .where('userName', isEqualTo: userName)
            .orderBy('craftedAt', descending: true)
            .get(const GetOptions(source: Source.server));
        
        developer.log('📊 Firestore returned ${snapshot.docs.length} documents', name: 'DyeStorage');
        
        final dyes = <Map<String, dynamic>>[];
        
        for (var doc in snapshot.docs) {
          try {
            final dyeModel = CraftedDyeModel.fromFirestore(doc);
            
            dyes.add({
              'id': dyeModel.id,
              'name': dyeModel.dyeName,
              'colorHex': dyeModel.colorHex,
              'volume': dyeModel.volume,
              'materialQuality': dyeModel.materialQuality,
              'crushingEfficiency': dyeModel.crushingEfficiency,
              'filteringPurity': dyeModel.filteringPurity,
              'createdAt': dyeModel.craftedAt,
            });
            
            developer.log('✅ Added: ${dyeModel.dyeName}', name: 'DyeStorage');
          } catch (e) {
            developer.log('⚠️ Skip doc ${doc.id}: $e', name: 'DyeStorage');
          }
        }
        
        // Update cache with Firestore data
        await _cacheAllDyes(dyes);
        developer.log('✅ Successfully loaded ${dyes.length} dyes from Firestore', name: 'DyeStorage');
        
        return dyes;
        
      } catch (e, stackTrace) {
        developer.log('❌ Firestore fetch failed: $e', name: 'DyeStorage');
        developer.log('❌ Stack: $stackTrace', name: 'DyeStorage');
        developer.log('📦 Falling back to cache', name: 'DyeStorage');
        return await _getCachedDyes();
      }
    } else {
      developer.log('🔴 Offline - using cache', name: 'DyeStorage');
      return await _getCachedDyes();
    }
  }
      
  Future<void> _syncOfflineQueue() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_queue') ?? '[]';
      List<dynamic> queue = json.decode(queueJson);
      
      if (queue.isEmpty) return;
      
      developer.log('🔄 Syncing ${queue.length} items', name: 'DyeStorage');
      
      List<int> syncedIndices = [];
      
      for (int i = 0; i < queue.length; i++) {
        try {
          final item = queue[i];
          final dyeModel = CraftedDyeModel.fromCache(item);
          
          developer.log('📤 Syncing: ${dyeModel.dyeName}', name: 'DyeStorage');
          
          // Save to Firestore
          final docRef = await _firestore
              .collection('CraftedDyes')
              .add(dyeModel.toFirestore());
          
          developer.log('✅ Synced to Firestore: ${docRef.id}', name: 'DyeStorage');
          
          // Update cache with real Firestore ID
          final updatedDye = dyeModel.copyWith(id: docRef.id);
          await _updateCachedDyeWithFirestoreId(dyeModel.id, updatedDye);
          
          syncedIndices.add(i);
          
        } catch (e, stackTrace) {
          developer.log('❌ Sync item failed: $e', name: 'DyeStorage');
          developer.log('Stack: $stackTrace', name: 'DyeStorage');
        }
      }
      
      // Remove synced items from queue
      if (syncedIndices.isNotEmpty) {
        for (int i = syncedIndices.length - 1; i >= 0; i--) {
          queue.removeAt(syncedIndices[i]);
        }
        await prefs.setString('offline_queue', json.encode(queue));
        developer.log('✅ Removed ${syncedIndices.length} synced items from queue', name: 'DyeStorage');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Queue sync error: $e', name: 'DyeStorage');
      developer.log('Stack: $stackTrace', name: 'DyeStorage');
    }
  }

  Future<void> _addToOfflineQueue(CraftedDyeModel dyeModel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_queue') ?? '[]';
      List<dynamic> queue = json.decode(queueJson);
      
      // Generate temporary ID if not present
      final tempId = dyeModel.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final modelWithId = dyeModel.copyWith(id: tempId);
      
      queue.add(modelWithId.toCache());
      
      await prefs.setString('offline_queue', json.encode(queue));
      
      // Also cache locally for immediate display
      await _cacheDyeLocally(modelWithId);
      
      developer.log('📥 Added to offline queue: ${modelWithId.dyeName}', name: 'DyeStorage');
    } catch (e) {
      developer.log('❌ Queue error: $e', name: 'DyeStorage');
    }
  }

  Future<void> _updateCachedDyeWithFirestoreId(String? oldId, CraftedDyeModel updatedDye) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cached = json.decode(cachedJson);
      
      // Find and update the dye
      bool found = false;
      for (int i = 0; i < cached.length; i++) {
        if (cached[i]['id'] == oldId) {
          cached[i] = updatedDye.toCache();
          found = true;
          break;
        }
      }
      
      // If not found, add it
      if (!found) {
        cached.add(updatedDye.toCache());
      }
      
      await prefs.setString('cached_dyes', json.encode(cached));
      developer.log('🔄 Updated cache with Firestore ID: ${updatedDye.id}', name: 'DyeStorage');
    } catch (e) {
      developer.log('❌ Update cache error: $e', name: 'DyeStorage');
    }
  }

  /*Future<void> _updateCachedDyeId(String tempId, String realId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cached = json.decode(cachedJson);
      
      for (var dye in cached) {
        if (dye['id'] == tempId) {
          dye['id'] = realId;
          break;
        }
      }
      
      await prefs.setString('cached_dyes', json.encode(cached));
    } catch (e) {
      developer.log('❌ Update ID error: $e', name: 'DyeStorage');
    }
  }*/
      
  Future<void> deleteCraftedDye(String dyeId) async {
    final userId = await _getUserId();
    if (userId == null) throw Exception('Not authenticated');
    
    developer.log('🗑️ Deleting dye: $dyeId', name: 'DyeStorage');
    
    // Remove from cache first
    await _removeCachedDye(dyeId);
    
    // Remove from Firestore if online and not a temp ID
    if (await _hasInternetConnection() && !dyeId.startsWith('temp_')) {
      try {
        await _firestore
            .collection('CraftedDyes')
            .doc(dyeId)
            .delete();
        
        developer.log('✅ Deleted from Firestore: $dyeId', name: 'DyeStorage');
      } catch (e) {
        developer.log('❌ Firestore delete failed: $e', name: 'DyeStorage');
        // Queue for deletion when online
        await _queueDeletionForSync(dyeId);
      }
    } else if (!dyeId.startsWith('temp_')) {
      // Offline - queue for deletion
      await _queueDeletionForSync(dyeId);
    }
  }

  /// NEW: Queue deletion for when device goes online
  Future<void> _queueDeletionForSync(String dyeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletionsJson = prefs.getString('pending_deletions') ?? '[]';
      List<dynamic> deletions = json.decode(deletionsJson);
      
      if (!deletions.contains(dyeId)) {
        deletions.add(dyeId);
        await prefs.setString('pending_deletions', json.encode(deletions));
        developer.log('📝 Queued deletion: $dyeId', name: 'DyeStorage');
      }
    } catch (e) {
      developer.log('❌ Queue deletion error: $e', name: 'DyeStorage');
    }
  }

  /// NEW: Process pending deletions when online
  // ignore: unused_element
  Future<void> _processPendingDeletions() async {
    try {
      if (!await _hasInternetConnection()) return;
      
      final prefs = await SharedPreferences.getInstance();
      final deletionsJson = prefs.getString('pending_deletions') ?? '[]';
      List<dynamic> deletions = json.decode(deletionsJson);
      
      if (deletions.isEmpty) return;
      
      developer.log('🗑️ Processing ${deletions.length} pending deletions', name: 'DyeStorage');
      
      List<String> processed = [];
      
      for (String dyeId in deletions) {
        try {
          await _firestore
              .collection('CraftedDyes')
              .doc(dyeId)
              .delete();
          
          processed.add(dyeId);
          developer.log('✅ Deleted from Firestore: $dyeId', name: 'DyeStorage');
        } catch (e) {
          developer.log('❌ Delete failed: $dyeId - $e', name: 'DyeStorage');
        }
      }
      
      if (processed.isNotEmpty) {
        deletions.removeWhere((id) => processed.contains(id));
        await prefs.setString('pending_deletions', json.encode(deletions));
      }
    } catch (e) {
      developer.log('❌ Process deletions error: $e', name: 'DyeStorage');
    }
  }

  Future<bool> isUserAuthenticated() async {
    return await _getUserId() != null;
  }
  
  Future<String?> getCurrentUserName() async {
    return await _getUserName();
  }

  Future<void> _cacheDyeLocally(CraftedDyeModel dyeModel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cached = json.decode(cachedJson);
      
      // Check if dye already exists
      cached.removeWhere((item) => item['id'] == dyeModel.id);
      
      // Add the dye
      cached.add(dyeModel.toCache());
      
      await prefs.setString('cached_dyes', json.encode(cached));
      developer.log('💾 Cached dye: ${dyeModel.dyeName}', name: 'DyeStorage');
    } catch (e) {
      developer.log('❌ Cache error: $e', name: 'DyeStorage');
    }
  }
  
  Future<void> _cacheAllDyes(List<Map<String, dynamic>> dyes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = dyes.map((dye) => {
        ...dye,
        'createdAt': dye['createdAt'] is DateTime
            ? (dye['createdAt'] as DateTime).toIso8601String()
            : dye['createdAt'],
      }).toList();
      
      await prefs.setString('cached_dyes', json.encode(serialized));
    } catch (e) {
      developer.log('❌ Cache all error: $e', name: 'DyeStorage');
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCachedDyes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cached = json.decode(cachedJson);
      
      final dyes = <Map<String, dynamic>>[];
      
      for (var dye in cached) {
        try {
          final colorHex = dye['color'] ?? dye['colorHex'];
          if (colorHex == null || colorHex.isEmpty) continue;
          
          dyes.add({
            'id': dye['id'] ?? 'unknown',
            'name': dye['dyeName'] ?? dye['name'] ?? 'Unknown',
            'colorHex': colorHex,
            'volume': dye['volume'] ?? 0,
            'materialQuality': dye['materialQuality'] ?? 'Good',
            'crushingEfficiency': (dye['crushingEfficiency'] ?? 1.0).toDouble(),
            'filteringPurity': (dye['filteringPurity'] ?? 1.0).toDouble(),
            'createdAt': DateTime.parse(
              dye['createdAt'] ?? DateTime.now().toIso8601String()
            ),
          });
        } catch (e) {
          developer.log('⚠️ Skip cached dye: $e', name: 'DyeStorage');
        }
      }
      
      return dyes;
    } catch (e) {
      return [];
    }
  }
  
  Future<void> _removeCachedDye(String dyeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_dyes') ?? '[]';
      List<dynamic> cached = json.decode(cachedJson);
      cached.removeWhere((dye) => dye['id'] == dyeId);
      await prefs.setString('cached_dyes', json.encode(cached));
    } catch (e) {
      developer.log('❌ Remove cache error: $e', name: 'DyeStorage');
    }
  }
  
  Future<int> getOfflineQueueSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_queue') ?? '[]';
      return (json.decode(queueJson) as List).length;
    } catch (e) {
      return 0;
    }
  }
  
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_dyes');
    await prefs.remove('offline_queue');
    await prefs.remove('pending_deletions');
  }
}