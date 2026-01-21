// Web-specific connectivity check
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

Future<bool> checkInternetConnection(FirebaseFirestore firestore) async {
  try {
    // Check browser's online status
    final isOnline = html.window.navigator.onLine ?? true;
    developer.log('🌐 Web platform - Navigator.onLine: $isOnline', name: 'DyeStorage');
    
    // Additional check: try to access Firestore directly
    if (isOnline) {
      try {
        // Quick Firestore ping to verify actual connectivity
        await firestore
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