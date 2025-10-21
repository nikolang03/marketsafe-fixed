import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'real_face_recognition_service.dart';

class FaceLoginService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'marketsafe'); // Fix database ID

  // Check if there are any verified users in the database
  static Future<bool> hasVerifiedUsers() async {
    try {
      print('Checking for verified users in database...');

      // First, let's check all users to see what we have
      final allUsersSnapshot = await _firestore.collection('users').get();

      print('Total users in database: ${allUsersSnapshot.docs.length}');

      for (final doc in allUsersSnapshot.docs) {
        final data = doc.data();
        print('User ${doc.id}:');
        print('  - Email: ${data['email']}');
        print('  - Verification Status: ${data['verificationStatus']}');
        print('  - Face Data: ${data['faceData']}');
        print('---');
      }

      final usersSnapshot = await _firestore
          .collection('users')
          .where('faceData.blinkCompleted', isEqualTo: true)
          .where('faceData.moveCloserCompleted', isEqualTo: true)
          .where('faceData.headMovementCompleted', isEqualTo: true)
          .limit(1)
          .get();

      print('Found ${usersSnapshot.docs.length} verified users');
      return usersSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking for verified users: $e');
      return false;
    }
  }

  // Authenticate user using face detection
  // Real face authentication using actual biometric data
  static Future<String?> authenticateUserWithRealBiometrics(Face detectedFace, [CameraImage? cameraImage]) async {
    try {
      print('🔒 Starting REAL biometric face authentication...');
      
      // Use the real face recognition service
      final result = await RealFaceRecognitionService.findUserByRealFace(detectedFace, cameraImage);
      
      // Handle liveness detection failure
      if (result == "LIVENESS_FAILED") {
        print('❌ Real liveness detection failed');
        return "LIVENESS_FAILED";
      }
      
      // Handle successful user match
      if (result != null) {
        // Check if user is verified
        final userDoc = await _firestore.collection('users').doc(result).get();
        final verificationStatus = userDoc.data()?['verificationStatus'] ?? 'pending';
        
        // Allow login for both verified and pending users
        // Only block rejected users
        if (verificationStatus == 'rejected') {
          return 'REJECTED_USER:$result';
        }
        
        // Update last login time
        await _firestore.collection('users').doc(result).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        
        return result;
      }
      
      print('❌ No matching user found with real biometric authentication');
      return null;
      
    } catch (e) {
      print('❌ Real face authentication error: $e');
      throw Exception('Real face authentication failed: $e');
    }
  }

  // Main authentication method - now uses only real biometrics
  static Future<String?> authenticateUser(Face detectedFace, [CameraImage? cameraImage]) async {
    return await authenticateUserWithRealBiometrics(detectedFace, cameraImage);
  }


  // Get user data by ID
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }
}
