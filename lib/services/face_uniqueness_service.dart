import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'real_face_recognition_service.dart';

class FaceUniquenessService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );

  // Generate a unique face signature based on face metrics
  static String _generateFaceSignature(Face face) {
    final metrics = _extractFaceMetrics(face);

    // Create a signature based on key facial features
    // This is a simplified approach - in production, you'd use more sophisticated algorithms
    final signature = '${metrics['headEulerAngleX']?.toStringAsFixed(2)}_'
        '${metrics['headEulerAngleY']?.toStringAsFixed(2)}_'
        '${metrics['headEulerAngleZ']?.toStringAsFixed(2)}_'
        '${metrics['leftEyeOpenProbability']?.toStringAsFixed(2)}_'
        '${metrics['rightEyeOpenProbability']?.toStringAsFixed(2)}_'
        '${metrics['smilingProbability']?.toStringAsFixed(2)}_'
        '${metrics['boundingBox']['width']?.toStringAsFixed(2)}_'
        '${metrics['boundingBox']['height']?.toStringAsFixed(2)}';

    return signature;
  }

  // Extract face metrics from detected face
  static Map<String, dynamic> _extractFaceMetrics(Face face) {
    return {
      'headEulerAngleX': face.headEulerAngleX,
      'headEulerAngleY': face.headEulerAngleY,
      'headEulerAngleZ': face.headEulerAngleZ,
      'leftEyeOpenProbability': face.leftEyeOpenProbability,
      'rightEyeOpenProbability': face.rightEyeOpenProbability,
      'smilingProbability': face.smilingProbability,
      'boundingBox': {
        'left': face.boundingBox.left,
        'top': face.boundingBox.top,
        'width': face.boundingBox.width,
        'height': face.boundingBox.height,
      },
    };
  }

  // Check if a face is already registered with any user
  static Future<bool> isFaceAlreadyRegistered(Face face, [CameraImage? cameraImage]) async {
    try {
      print('🔍 Checking face uniqueness using 128D face recognition system...');
      
      // Use the new 128D face recognition system to find existing users
      final existingUserId = await RealFaceRecognitionService.findUserByRealFace(face, cameraImage);
      
      if (existingUserId != null) {
        print('❌ Face already registered with user: $existingUserId');
        return true;
      }
      
      // Also check the old face registry system as backup
      print('🔄 Also checking old face registry system...');
      final isInOldSystem = await _checkFaceUniquenessOldSystem(face);
      if (isInOldSystem) {
        print('❌ Face found in old face registry system');
        return true;
      }
      
      print('✅ Face is unique, allowing registration');
      return false;
    } catch (e) {
      print('❌ Error checking face uniqueness: $e');
      // Allow registration if check fails - don't block the user
      return false;
    }
  }
  
  // Fallback to old system
  static Future<bool> _checkFaceUniquenessOldSystem(Face face) async {
    try {
      print('🔄 Using old face uniqueness system...');
      final faceMetrics = _extractFaceMetrics(face);

      // Get all registered faces and compare with similarity
      final faceRegistrySnapshot =
          await _firestore.collection('face_registry').get();

      print('Found ${faceRegistrySnapshot.docs.length} registered faces in old system');

      for (final doc in faceRegistrySnapshot.docs) {
        final faceData = doc.data();
        final storedMetrics = faceData['faceMetrics'] as Map<String, dynamic>?;

        if (storedMetrics != null) {
          final similarity = _compareFaceFeatures(faceMetrics, storedMetrics);
          print('Face similarity: $similarity');
          if (similarity > 0.95) {  // Changed from 0.8 to 0.95 (95% similarity)
            // 95% similarity threshold - much more restrictive
            print('Face already registered with high similarity: $similarity');
            return true;
          }
        }
      }

      print('Face is unique in old system, allowing registration');
      return false;
    } catch (e) {
      print('Error in old face uniqueness system: $e');
      return false;
    }
  }

  // Register a face signature for a user
  static Future<void> registerFaceSignature(String userId, Face face) async {
    try {
      final faceSignature = _generateFaceSignature(face);
      final faceMetrics = _extractFaceMetrics(face);

      // Store in face registry
      await _firestore.collection('face_registry').add({
        'userId': userId,
        'faceSignature': faceSignature,
        'faceMetrics': faceMetrics,
        'registeredAt': FieldValue.serverTimestamp(),
        'email': '', // Will be updated when user completes registration
        'phoneNumber': '', // Will be updated when user completes registration
      });

      print('Face signature registered for user: $userId');
    } catch (e) {
      print('Error registering face signature: $e');
      throw Exception('Failed to register face signature');
    }
  }

  // Update face registry with user's email/phone after registration
  static Future<void> updateFaceRegistryWithUserInfo(
      String userId, String email, String phoneNumber) async {
    try {
      // Find the face registry entry for this user
      final faceRegistrySnapshot = await _firestore
          .collection('face_registry')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (faceRegistrySnapshot.docs.isNotEmpty) {
        await faceRegistrySnapshot.docs.first.reference.update({
          'email': email,
          'phoneNumber': phoneNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Face registry updated with user info for: $userId');
      }
    } catch (e) {
      print('Error updating face registry: $e');
    }
  }

  // Check if a face matches any existing registered face (for login)
  static Future<String?> findMatchingFace(Face face) async {
    try {
      final faceMetrics = _extractFaceMetrics(face);
      print('Looking for matching face with metrics: $faceMetrics');

      // Get all registered faces and find the best match
      final faceRegistrySnapshot =
          await _firestore.collection('face_registry').get();

      print(
          'Found ${faceRegistrySnapshot.docs.length} registered faces in database');

      String? bestMatchUserId;
      double bestSimilarity = 0.0;

      for (final doc in faceRegistrySnapshot.docs) {
        final faceData = doc.data();
        final storedMetrics = faceData['faceMetrics'] as Map<String, dynamic>?;

        if (storedMetrics != null) {
          final similarity = _compareFaceFeatures(faceMetrics, storedMetrics);
          print(
              'Comparing with user ${faceData['userId']}: similarity = $similarity');
          if (similarity > bestSimilarity && similarity > 0.98) {
            // 98% similarity threshold for login (high security)
            bestSimilarity = similarity;
            bestMatchUserId = faceData['userId'];
            print(
                'New best match: user $bestMatchUserId with similarity $bestSimilarity');
          }
        }
      }

      print(
          'Final result: bestMatchUserId = $bestMatchUserId, bestSimilarity = $bestSimilarity');
      return bestMatchUserId;
    } catch (e) {
      print('Error finding matching face: $e');
      return null;
    }
  }

  // Get face registry info for a user
  static Future<Map<String, dynamic>?> getFaceRegistryInfo(
      String userId) async {
    try {
      final faceRegistrySnapshot = await _firestore
          .collection('face_registry')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (faceRegistrySnapshot.docs.isNotEmpty) {
        return faceRegistrySnapshot.docs.first.data();
      }

      return null;
    } catch (e) {
      print('Error getting face registry info: $e');
      return null;
    }
  }

  // Remove face signature when user account is deleted
  static Future<void> removeFaceSignature(String userId) async {
    try {
      final faceRegistrySnapshot = await _firestore
          .collection('face_registry')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in faceRegistrySnapshot.docs) {
        await doc.reference.delete();
      }

      print('Face signature removed for user: $userId');
    } catch (e) {
      print('Error removing face signature: $e');
    }
  }

  // Compare face features (similar to the one in face_login_service.dart)
  static double _compareFaceFeatures(
    Map<String, dynamic> detectedMetrics,
    Map<String, dynamic> storedMetrics,
  ) {
    double similarity = 0.0;
    int comparisons = 0;

    // Compare head angles
    if (detectedMetrics['headEulerAngleX'] != null &&
        storedMetrics['headEulerAngleX'] != null) {
      final diff = (detectedMetrics['headEulerAngleX'] -
              storedMetrics['headEulerAngleX'])
          .abs();
      similarity += (1.0 - (diff / 90.0)).clamp(0.0, 1.0);
      comparisons++;
    }

    if (detectedMetrics['headEulerAngleY'] != null &&
        storedMetrics['headEulerAngleY'] != null) {
      final diff = (detectedMetrics['headEulerAngleY'] -
              storedMetrics['headEulerAngleY'])
          .abs();
      similarity += (1.0 - (diff / 90.0)).clamp(0.0, 1.0);
      comparisons++;
    }

    if (detectedMetrics['headEulerAngleZ'] != null &&
        storedMetrics['headEulerAngleZ'] != null) {
      final diff = (detectedMetrics['headEulerAngleZ'] -
              storedMetrics['headEulerAngleZ'])
          .abs();
      similarity += (1.0 - (diff / 90.0)).clamp(0.0, 1.0);
      comparisons++;
    }

    // Compare eye probabilities
    if (detectedMetrics['leftEyeOpenProbability'] != null &&
        storedMetrics['leftEyeOpenProbability'] != null) {
      final diff = (detectedMetrics['leftEyeOpenProbability'] -
              storedMetrics['leftEyeOpenProbability'])
          .abs();
      similarity += (1.0 - diff);
      comparisons++;
    }

    if (detectedMetrics['rightEyeOpenProbability'] != null &&
        storedMetrics['rightEyeOpenProbability'] != null) {
      final diff = (detectedMetrics['rightEyeOpenProbability'] -
              storedMetrics['rightEyeOpenProbability'])
          .abs();
      similarity += (1.0 - diff);
      comparisons++;
    }

    // Compare smiling probability
    if (detectedMetrics['smilingProbability'] != null &&
        storedMetrics['smilingProbability'] != null) {
      final diff = (detectedMetrics['smilingProbability'] -
              storedMetrics['smilingProbability'])
          .abs();
      similarity += (1.0 - diff);
      comparisons++;
    }

    return comparisons > 0 ? similarity / comparisons : 0.0;
  }
}

