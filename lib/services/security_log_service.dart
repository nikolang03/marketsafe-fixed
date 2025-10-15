import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class SecurityLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );

  // Log login attempts
  static Future<void> logLoginAttempt({
    required String userId,
    required double similarity,
    required bool success,
    required String deviceInfo,
    String? errorMessage,
  }) async {
    try {
      await _firestore.collection('security_logs').add({
        'userId': userId,
        'similarity': similarity,
        'success': success,
        'deviceInfo': deviceInfo,
        'errorMessage': errorMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'face_login_attempt',
      });
      
      // Flag suspicious attempts
      if (!success && similarity > 0.5) {
        await _flagSuspiciousActivity(userId, similarity);
      }
    } catch (e) {
      print('❌ Error logging security event: $e');
    }
  }

  // Flag suspicious activity
  static Future<void> _flagSuspiciousActivity(String userId, double similarity) async {
    try {
      await _firestore.collection('security_alerts').add({
        'userId': userId,
        'similarity': similarity,
        'alertType': 'suspicious_login_attempt',
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'high',
      });
    } catch (e) {
      print('❌ Error flagging suspicious activity: $e');
    }
  }
}