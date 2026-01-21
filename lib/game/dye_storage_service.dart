import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecoquest/game/crafted_dye_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;

// Conditional import: use mobile version by default, web version when dart:html is available
import 'connectivity_mobile.dart'
    if (dart.library.html) 'connectivity_web.dart';

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
  
  /// Get the username from Firestore Users collection or displayName
  Future<String> _getUserName() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // First, try to get displayName (which should be set during registration)
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          developer.log('📛 Using displayName: ${user.displayName}', name: 'DyeStorage');
          return user.displayName!;
        }
        
        // If displayName is not set, fetch from Firestore Users collection
        try {
          // Query Users collection where uid matches
          final querySnapshot = await _firestore
              .collection('Users')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
            final userData = querySnapshot.docs.first.data();
            final username = userData['Username'] as String?;
            
            if (username != null && username.isNotEmpty) {
              developer.log('📛 Fetched username from Firestore: $username', name: 'DyeStorage');
              
              // Cache it for future use
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('cached_user_name', username);
              
              // Also update Firebase Auth displayName for consistency
              await user.updateDisplayName(username);
              
              return username;
            }
          }
        } catch (firestoreError) {
          developer.log('⚠️ Error fetching from Firestore: $firestoreError', name: 'DyeStorage');
        }
        
        // Fallback to email if everything fails
        developer.log('⚠️ Falling back to email: ${user.email}', name: 'DyeStorage');
        return user.email ?? user.uid;
      }
      
      // Try cache if user is null
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('cached_user_name');
      if (cachedName != null && cachedName.isNotEmpty) {
        return cachedName;
      }
      
      return 'Unknown User';
    } catch (e) {
      developer.log('❌ Error getting user name: $e', name: 'DyeStorage');
      return 'Unknown User';
    }
  }
  
  Future<void> _cacheUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_uid', user.uid);
        
        // Get the actual username
        final userName = await _getUserName();
        await prefs.setString('cached_user_name', userName);
        
        developer.log('💾 Cached user info - UID: ${user.uid}, Username: $userName', name: 'DyeStorage');
      }
    } catch (e) {
      developer.log('❌ Cache user error: $e', name: 'DyeStorage');
    }
  }
    
  Future<bool> _hasInternetConnection() async {
    try {
      developer.log('🌐 Checking internet connection...', name: 'DyeStorage');
      developer.log('🖥️ Platform: ${kIsWeb ? "Web" : "Mobile"}', name: 'DyeStorage');
      
      // Use the platform-specific implementation
      final isConnected = await checkInternetConnection(_firestore);
      developer.log('📡 Connection status: $isConnected', name: 'DyeStorage');
      return isConnected;
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
        developer.log('✅ User UID: ${user.uid}', name: 'DyeStorage');
        developer.log('✅ Display Name: ${user.displayName}', name: 'DyeStorage');
        developer.log('✅ Email: ${user.email}', name: 'DyeStorage');
        
        final userName = await _getUserName();
        developer.log('✅ Resolved Username: $userName', name: 'DyeStorage');
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
    
    // Get user info
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated. Please log in.');
    }
    
    await _cacheUserInfo();
    final userName = await _getUserName();
    
    // Log detailed user info for debugging
    final user = _auth.currentUser;
    developer.log('👤 Firebase User Info:', name: 'DyeStorage');
    developer.log('   - UID: ${user?.uid}', name: 'DyeStorage');
    developer.log('   - Display Name: ${user?.displayName}', name: 'DyeStorage');
    developer.log('   - Email: ${user?.email}', name: 'DyeStorage');
    developer.log('   - Using Username: $userName', name: 'DyeStorage');
    
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
    
    // SAVE TO FLAT STRUCTURE: CraftedDyes/{username}_{timestamp}
    try {
      developer.log('📡 Attempting Firestore save...', name: 'DyeStorage');
      
      // Create document ID as username_timestamp for uniqueness
      final timestamp = now.millisecondsSinceEpoch;
      final docId = '${userName}_$timestamp';
      
      developer.log('📄 Document ID: $docId', name: 'DyeStorage');
      developer.log('📍 Path: CraftedDyes/$docId', name: 'DyeStorage');
      
      // Save to flat structure with composite document ID
      await _firestore
          .collection('CraftedDyes')
          .doc(docId)
          .set(dyeModel.toFirestore())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Firestore save timed out after 10 seconds');
            },
          );
      
      developer.log('🎉 FIRESTORE SUCCESS!', name: 'DyeStorage');
      developer.log('📄 Document ID: $docId', name: 'DyeStorage');
      developer.log('📍 Full path: CraftedDyes/$docId', name: 'DyeStorage');
      
      // Update model with document ID
      final savedDye = dyeModel.copyWith(id: docId);
      
      // Cache AFTER successful Firestore save
      await _cacheDyeLocally(savedDye);
      developer.log('✅ Cached locally after Firestore save', name: 'DyeStorage');
      
      return;
      
    } on FirebaseException catch (e) {
      developer.log('❌ Firebase Error Code: ${e.code}', name: 'DyeStorage');
      developer.log('❌ Firebase Message: ${e.message}', name: 'DyeStorage');
      
      if (e.code == 'permission-denied') {
        developer.log('🔒 PERMISSION DENIED - Check Firestore rules', name: 'DyeStorage');
        await _addToOfflineQueue(dyeModel);
        throw Exception(
          'Permission denied. Your dye has been saved locally and will sync when permissions are fixed.'
        );
      } else if (e.code == 'unavailable') {
        developer.log('🌐 Network unavailable - queuing for sync', name: 'DyeStorage');
        await _addToOfflineQueue(dyeModel);
        throw Exception(
          'Network unavailable. Your dye has been saved locally and will sync when you\'re back online.'
        );
      } else {
        developer.log('📤 Queuing for offline sync due to error', name: 'DyeStorage');
        await _addToOfflineQueue(dyeModel);
        throw Exception(
          'Save error: ${e.message}. Your dye has been saved locally and will sync later.'
        );
      }
      
    } on TimeoutException catch (e) {
      developer.log('⏱️ Firestore save timed out: $e', name: 'DyeStorage');
      await _addToOfflineQueue(dyeModel);
      throw Exception(
        'Connection timeout. Your dye has been saved locally and will sync when connection improves.'
      );
      
    } catch (e, stackTrace) {
      developer.log('❌ Unexpected error: $e', name: 'DyeStorage');
      developer.log('❌ Stack: $stackTrace', name: 'DyeStorage');
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
        developer.log('🔍 Searching for documents starting with: $userName', name: 'DyeStorage');
        
        // Query documents where document ID starts with username
        // Using range query: username_0 to username_z (covers all timestamps)
        final snapshot = await _firestore
            .collection('CraftedDyes')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userName}_')
            .where(FieldPath.documentId, isLessThan: '${userName}_\uf8ff')
            .orderBy(FieldPath.documentId, descending: true)
            .get(const GetOptions(source: Source.server));
        
        developer.log('📊 Firestore returned ${snapshot.docs.length} documents', name: 'DyeStorage');
        
        final dyes = <Map<String, dynamic>>[];
        
        for (var doc in snapshot.docs) {
          try {
            // Verify the document actually belongs to this user
            final data = doc.data();
            if (data['userName'] != userName) {
              developer.log('⚠️ Skipping doc ${doc.id} - userName mismatch', name: 'DyeStorage');
              continue;
            }
            
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
        
        // Sort by timestamp (already in doc ID, but sort by craftedAt for accuracy)
        dyes.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
        
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
      
      final userName = await _getUserName();
      
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
          
          // Generate composite document ID: username_timestamp
          final timestamp = dyeModel.craftedAt.millisecondsSinceEpoch;
          final docId = '${userName}_$timestamp';
          
          // Save with composite document ID
          await _firestore
              .collection('CraftedDyes')
              .doc(docId)
              .set(dyeModel.toFirestore());
          
          developer.log('✅ Synced to Firestore: CraftedDyes/$docId', name: 'DyeStorage');
          
          // Update cache with real Firestore ID
          final updatedDye = dyeModel.copyWith(id: docId);
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
      
      // Generate composite ID if not present: username_timestamp
      final userName = await _getUserName();
      final timestamp = dyeModel.craftedAt.millisecondsSinceEpoch;
      final compositeId = '${userName}_$timestamp';
      
      final modelWithId = dyeModel.copyWith(id: compositeId);
      
      queue.add(modelWithId.toCache());
      
      await prefs.setString('offline_queue', json.encode(queue));
      
      // Also cache locally for immediate display
      await _cacheDyeLocally(modelWithId);
      
      developer.log('📥 Added to offline queue: ${modelWithId.dyeName} (ID: $compositeId)', name: 'DyeStorage');
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
        
  Future<void> deleteCraftedDye(String dyeId) async {
    final userId = await _getUserId();
    if (userId == null) throw Exception('Not authenticated');
    
    developer.log('🗑️ Deleting dye: $dyeId', name: 'DyeStorage');
    
    // Remove from cache first
    await _removeCachedDye(dyeId);
    
    // Remove from Firestore if online and not a temp ID
    if (await _hasInternetConnection() && !dyeId.startsWith('temp_')) {
      try {
        // Delete from flat structure: CraftedDyes/{username_timestamp}
        await _firestore
            .collection('CraftedDyes')
            .doc(dyeId)
            .delete();
        
        developer.log('✅ Deleted from Firestore: CraftedDyes/$dyeId', name: 'DyeStorage');
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
          // Delete from flat structure
          await _firestore
              .collection('CraftedDyes')
              .doc(dyeId)
              .delete();
          
          processed.add(dyeId);
          developer.log('✅ Deleted from Firestore: CraftedDyes/$dyeId', name: 'DyeStorage');
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