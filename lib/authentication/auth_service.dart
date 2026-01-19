import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Check SharedPreferences for persistent login
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      return isLoggedIn;
    }
    return false;
  }

  // Set login state
  Future<void> setLoginState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  // Get current user role
  Future<String> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'Client';

    try {
      final querySnapshot = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        return userData['role'] as String? ?? 'Client';
      }
    } catch (e) {
      debugPrint('Error getting user role: $e');
    }
    return 'Client';
  }

  // Get current username
  Future<String> getUsername() async {
    final user = _auth.currentUser;
    if (user == null) return '';

    try {
      final querySnapshot = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id; // Document ID is the username
      }
    } catch (e) {
      debugPrint('Error getting username: $e');
    }
    return '';
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final querySnapshot = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        data['username'] = querySnapshot.docs.first.id;
        return data;
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    await setLoginState(false);
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;
}