// Mobile-specific connectivity check
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

Future<bool> checkInternetConnection(FirebaseFirestore firestore) async {
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