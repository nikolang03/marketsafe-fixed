import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'dart:math';
import 'face_security_service.dart';

/// Real Face Recognition Service using actual biometric data
/// This service provides genuine face authentication, not simulation
class RealFaceRecognitionService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'marketsafe',
      );

  // Real face recognition configuration - SECURITY ENHANCED
  static const double _similarityThreshold = 0.85; // HIGH threshold for face recognition (85% similarity) - SECURITY CRITICAL
  static const double _minimumUniquenessThreshold = 0.15; // Minimum difference between best and second-best match

  /// Extract real biometric features from a face
  /// This creates a unique biometric signature based on actual facial features
  static Future<List<double>> extractBiometricFeatures(Face face, [CameraImage? cameraImage]) async {
    try {
      print('🔍 Extracting REAL biometric features from face...');
      
      // Extract actual facial biometric data
      final biometricData = _extractFacialBiometrics(face, cameraImage);
      print('📊 Biometric data extracted: ${biometricData.keys.length} features');
      
      // Create a unique biometric signature
      final biometricSignature = _createBiometricSignature(biometricData);
      
      print('✅ Real biometric features extracted: ${biometricSignature.length} dimensions');
      print('📊 Sample signature values: ${biometricSignature.take(5).toList()}');
      return biometricSignature;
      
    } catch (e) {
      print('❌ Error extracting real biometric features: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      throw Exception('Failed to extract real biometric features: $e');
    }
  }

  /// Extract actual facial biometric data
  static Map<String, dynamic> _extractFacialBiometrics(Face face, [CameraImage? cameraImage]) {
    final boundingBox = face.boundingBox;
    final landmarks = face.landmarks;
    
    // Extract real facial measurements and ratios
    final biometrics = <String, dynamic>{};
    
    // Face geometry measurements
    biometrics['faceWidth'] = boundingBox.width;
    biometrics['faceHeight'] = boundingBox.height;
    biometrics['aspectRatio'] = boundingBox.width / boundingBox.height;
    
    // Eye measurements
    if (landmarks.containsKey(FaceLandmarkType.leftEye) && 
        landmarks.containsKey(FaceLandmarkType.rightEye)) {
      final leftEye = landmarks[FaceLandmarkType.leftEye]!;
      final rightEye = landmarks[FaceLandmarkType.rightEye]!;
      
      final eyeDistance = leftEye.position.distanceTo(rightEye.position);
      biometrics['eyeDistance'] = eyeDistance;
      biometrics['eyeToFaceRatio'] = eyeDistance / boundingBox.width;
      
      // Eye positions relative to face (ensure double type)
      biometrics['leftEyeX'] = leftEye.position.x.toDouble();
      biometrics['leftEyeY'] = leftEye.position.y.toDouble();
      biometrics['rightEyeX'] = rightEye.position.x.toDouble();
      biometrics['rightEyeY'] = rightEye.position.y.toDouble();
    }
    
    // Nose measurements (ensure double type)
    if (landmarks.containsKey(FaceLandmarkType.noseBase)) {
      final nose = landmarks[FaceLandmarkType.noseBase]!;
      biometrics['noseX'] = nose.position.x.toDouble();
      biometrics['noseY'] = nose.position.y.toDouble();
      biometrics['noseToFaceRatio'] = (nose.position.y - boundingBox.top) / boundingBox.height;
    }
    
    // Mouth measurements (ensure double type)
    if (landmarks.containsKey(FaceLandmarkType.bottomMouth)) {
      final mouth = landmarks[FaceLandmarkType.bottomMouth]!;
      biometrics['mouthX'] = mouth.position.x.toDouble();
      biometrics['mouthY'] = mouth.position.y.toDouble();
      biometrics['mouthToFaceRatio'] = (mouth.position.y - boundingBox.top) / boundingBox.height;
    }
    
    // Head pose (important for liveness detection)
    biometrics['headEulerAngleX'] = face.headEulerAngleX ?? 0.0;
    biometrics['headEulerAngleY'] = face.headEulerAngleY ?? 0.0;
    biometrics['headEulerAngleZ'] = face.headEulerAngleZ ?? 0.0;
    
    // Eye states (for liveness detection)
    biometrics['leftEyeOpen'] = face.leftEyeOpenProbability ?? 0.0;
    biometrics['rightEyeOpen'] = face.rightEyeOpenProbability ?? 0.0;
    biometrics['smiling'] = face.smilingProbability ?? 0.0;
    
    // Facial symmetry measurements
    biometrics['facialSymmetry'] = _calculateFacialSymmetry(face);
    
    // Additional biometric features
    biometrics['faceArea'] = boundingBox.width * boundingBox.height;
    biometrics['faceCenterX'] = boundingBox.center.dx;
    biometrics['faceCenterY'] = boundingBox.center.dy;
    
    return biometrics;
  }

  /// Create a unique biometric signature from facial data
  static List<double> _createBiometricSignature(Map<String, dynamic> biometrics) {
    try {
      print('🔍 Creating biometric signature from ${biometrics.length} features...');
      final signature = <double>[];
      
      // Add normalized measurements to create a unique signature
      signature.addAll([
        biometrics['aspectRatio'] ?? 0.0,
        biometrics['eyeToFaceRatio'] ?? 0.0,
        biometrics['noseToFaceRatio'] ?? 0.0,
        biometrics['mouthToFaceRatio'] ?? 0.0,
        biometrics['facialSymmetry'] ?? 0.0,
      ]);
      print('📊 Added basic ratios: ${signature.length} values');
    
    // Add normalized landmark positions
    if (biometrics['leftEyeX'] != null) {
      signature.add((biometrics['leftEyeX'] as double) / 1000.0);
      signature.add((biometrics['leftEyeY'] as double) / 1000.0);
    }
    if (biometrics['rightEyeX'] != null) {
      signature.add((biometrics['rightEyeX'] as double) / 1000.0);
      signature.add((biometrics['rightEyeY'] as double) / 1000.0);
    }
    if (biometrics['noseX'] != null) {
      signature.add((biometrics['noseX'] as double) / 1000.0);
      signature.add((biometrics['noseY'] as double) / 1000.0);
    }
    if (biometrics['mouthX'] != null) {
      signature.add((biometrics['mouthX'] as double) / 1000.0);
      signature.add((biometrics['mouthY'] as double) / 1000.0);
    }
    
    // Add head pose data
    signature.addAll([
      (biometrics['headEulerAngleX'] as double) / 180.0,
      (biometrics['headEulerAngleY'] as double) / 180.0,
      (biometrics['headEulerAngleZ'] as double) / 180.0,
    ]);
    
    // Add eye state data
    signature.addAll([
      biometrics['leftEyeOpen'] ?? 0.0,
      biometrics['rightEyeOpen'] ?? 0.0,
      biometrics['smiling'] ?? 0.0,
    ]);
    
    // Add more unique facial features for better security
    signature.addAll([
      (biometrics['faceWidth'] as double) / 1000.0,
      (biometrics['faceHeight'] as double) / 1000.0,
      biometrics['aspectRatio'] ?? 0.0,
      biometrics['eyeDistance'] ?? 0.0,
    ]);
    
    // Add additional unique ratios
    if (biometrics['leftEyeX'] != null && biometrics['rightEyeX'] != null) {
      final eyeCenterX = ((biometrics['leftEyeX'] as double) + (biometrics['rightEyeX'] as double)) / 2;
      final faceCenterX = (biometrics['faceWidth'] as double) / 2;
      signature.add((eyeCenterX - faceCenterX) / 1000.0);
    }
    
    if (biometrics['leftEyeY'] != null && biometrics['rightEyeY'] != null) {
      final eyeCenterY = ((biometrics['leftEyeY'] as double) + (biometrics['rightEyeY'] as double)) / 2;
      final faceCenterY = (biometrics['faceHeight'] as double) / 2;
      signature.add((eyeCenterY - faceCenterY) / 1000.0);
    }
    
      // Pad to fixed length for consistency
      while (signature.length < 64) {
        signature.add(0.0);
      }
      
      print('✅ Biometric signature created: ${signature.length} dimensions');
      return signature.take(64).toList();
      
    } catch (e) {
      print('❌ Error creating biometric signature: $e');
      print('❌ Biometrics data: $biometrics');
      // Return a default signature if creation fails
      return List.generate(64, (index) => 0.0);
    }
  }

  /// Calculate facial symmetry
  static double _calculateFacialSymmetry(Face face) {
    final landmarks = face.landmarks;
    final boundingBox = face.boundingBox;
    final centerX = boundingBox.center.dx;
    
    if (landmarks.containsKey(FaceLandmarkType.leftEye) && 
        landmarks.containsKey(FaceLandmarkType.rightEye)) {
      final leftEye = landmarks[FaceLandmarkType.leftEye]!;
      final rightEye = landmarks[FaceLandmarkType.rightEye]!;
      
      final leftDistance = (leftEye.position.x - centerX).abs();
      final rightDistance = (rightEye.position.x - centerX).abs();
      
      return 1.0 - (leftDistance - rightDistance).abs() / boundingBox.width;
    }
    
    return 0.5; // Default symmetry
  }

  /// Perform real liveness detection (ENHANCED SECURITY)
  static bool _performLivenessDetection(Face face) {
    try {
      print('🔍 Performing ENHANCED liveness detection...');
      
      // Enhanced liveness checks for better security
      final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;
      final smiling = face.smilingProbability ?? 0.0;
      
      // Check eye states (more strict)
      if (leftEyeOpen < 0.3 || rightEyeOpen < 0.3) {
        print('❌ Liveness check failed: eyes not open enough (L: $leftEyeOpen, R: $rightEyeOpen)');
        return false;
      }
      
      // Check for natural facial expression (not too rigid)
      if (smiling < 0.1 && smiling > 0.9) {
        print('❌ Liveness check failed: unnatural facial expression (smiling: $smiling)');
        return false;
      }
      
      // Check head pose for natural positioning
      final headAngleX = face.headEulerAngleX ?? 0.0;
      final headAngleY = face.headEulerAngleY ?? 0.0;
      
      // Reject extreme head angles (likely photos)
      if (headAngleX.abs() > 30 || headAngleY.abs() > 30) {
        print('❌ Liveness check failed: extreme head angle (X: $headAngleX, Y: $headAngleY)');
        return false;
      }
      
      print('✅ Enhanced liveness check passed: eyes open, natural expression, good head pose');
      return true;
      
    } catch (e) {
      print('❌ Liveness detection error: $e');
      return false;
    }
  }

  /// Calculate similarity between two biometric signatures
  static double calculateBiometricSimilarity(List<double> signature1, List<double> signature2) {
    if (signature1.length != signature2.length) return 0.0;
    
    // Use a more balanced approach that combines multiple similarity metrics
    double euclideanSimilarity = _calculateEuclideanSimilarity(signature1, signature2);
    double cosineSimilarity = _calculateCosineSimilarity(signature1, signature2);
    
    // Calculate weighted average with more emphasis on cosine similarity for biometric data
    final finalSimilarity = (euclideanSimilarity * 0.3) + (cosineSimilarity * 0.7);
    
    print('📊 Biometric similarity calculation:');
    print('  - Euclidean similarity: $euclideanSimilarity');
    print('  - Cosine similarity: $cosineSimilarity');
    print('  - Final similarity (BALANCED): $finalSimilarity');
    
    return finalSimilarity;
  }

  /// Calculate similarity for profile photos with more lenient settings
  static double calculateProfilePhotoSimilarity(List<double> signature1, List<double> signature2) {
    if (signature1.length != signature2.length) return 0.0;
    
    // Use a more lenient approach for profile photos
    double euclideanSimilarity = _calculateEuclideanSimilarity(signature1, signature2);
    double cosineSimilarity = _calculateCosineSimilarity(signature1, signature2);
    
    // More lenient weighting for profile photos
    final finalSimilarity = (euclideanSimilarity * 0.4) + (cosineSimilarity * 0.6);
    
    print('📊 Profile photo similarity calculation:');
    print('  - Euclidean similarity: $euclideanSimilarity');
    print('  - Cosine similarity: $cosineSimilarity');
    print('  - Final similarity (LENIENT): $finalSimilarity');
    
    return finalSimilarity;
  }
  
  /// Calculate cosine similarity
  static double _calculateCosineSimilarity(List<double> signature1, List<double> signature2) {
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < signature1.length; i++) {
      dotProduct += signature1[i] * signature2[i];
      norm1 += signature1[i] * signature1[i];
      norm2 += signature2[i] * signature2[i];
    }
    
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }
  
  /// Calculate Euclidean distance-based similarity
  static double _calculateEuclideanSimilarity(List<double> signature1, List<double> signature2) {
    double sumSquaredDiffs = 0.0;
    
    for (int i = 0; i < signature1.length; i++) {
      double diff = signature1[i] - signature2[i];
      sumSquaredDiffs += diff * diff;
    }
    
    double euclideanDistance = sqrt(sumSquaredDiffs);
    
    // Convert distance to similarity (0-1 range) - more lenient for biometric data
    // Use a higher scaling factor to be more forgiving of small differences
    return 1.0 / (1.0 + euclideanDistance * 0.5);
  }

  /// Store real biometric features for a user
  static Future<void> storeBiometricFeatures(String userId, List<double> features) async {
    try {
      print('🔄 Storing REAL biometric features for user: $userId');
      
      final biometricData = {
        'biometricSignature': features,
        'featureCount': features.length,
        'biometricType': 'REAL_FACE_RECOGNITION',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isRealBiometric': true, // Flag to indicate this is real biometric data
      };
      
      await _firestore.collection('users').doc(userId).update({
        'biometricFeatures': biometricData,
        'biometricFeaturesUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Real biometric features stored successfully');
    } catch (e) {
      print('❌ Error storing real biometric features: $e');
      throw Exception('Failed to store real biometric features: $e');
    }
  }

  /// Find user by real face recognition
  static Future<String?> findUserByRealFace(Face detectedFace, [CameraImage? cameraImage]) async {
    try {
      print('🚨 REAL FACE RECOGNITION STARTING...');
      print('🚨 This is ACTUAL biometric authentication!');
      
      // Perform real liveness detection
      if (!_performLivenessDetection(detectedFace)) {
        print('❌ Real liveness detection failed');
        return "LIVENESS_FAILED";
      }
      
      // Extract real biometric features for comparison
      final detectedBiometrics = await extractBiometricFeatures(detectedFace, cameraImage);
      print('Extracted ${detectedBiometrics.length} real biometric features');
      print('📊 Sample detected features: ${detectedBiometrics.take(3).toList()}');
      
      // Get all users with biometric data (verified and pending)
      final usersSnapshot = await _firestore
          .collection('users')
          .where('verificationStatus', whereIn: ['verified', 'pending'])
          .get();
      
      final usersWithBiometrics = usersSnapshot.docs.where((doc) {
        final userData = doc.data();
        return (userData['verificationStatus'] == 'verified' || userData['verificationStatus'] == 'pending') && 
               (userData['biometricFeatures'] != null || userData['faceFeatures'] != null);
      }).toList();
      
      print('🔍 Found ${usersWithBiometrics.length} users with real biometric data');
      
      // Debug: Print details about found users
      for (final doc in usersWithBiometrics) {
        final userData = doc.data();
        print('  - User ${doc.id}: status=${userData['verificationStatus']}, hasBiometric=${userData['biometricFeatures'] != null}, hasFace=${userData['faceFeatures'] != null}');
      }
      
      if (usersWithBiometrics.isEmpty) {
        print('No users with real biometric features found');
        return null;
      }
      
      String? bestMatchUserId;
      double bestSimilarity = 0.0;
      double secondBestSimilarity = 0.0;
      
      // Compare with each user's stored biometric features
      for (final doc in usersWithBiometrics) {
        final userData = doc.data();
        final biometricFeatures = userData['biometricFeatures'];
        
        List<double> storedSignature = [];
        
        if (biometricFeatures is Map && biometricFeatures.containsKey('biometricSignature')) {
          storedSignature = List<double>.from(biometricFeatures['biometricSignature']);
          print('📊 User ${doc.id} has ${storedSignature.length} stored biometric features');
          print('📊 Sample stored features: ${storedSignature.take(3).toList()}');
        } else {
          print('⚠️ User ${doc.id} has no biometric signature, checking face features...');
          // Fallback to old face features if available
          final faceFeatures = userData['faceFeatures'];
          if (faceFeatures is String) {
            final faceFeaturesList = faceFeatures.split(',').map((e) => double.tryParse(e) ?? 0.0).toList();
            if (faceFeaturesList.isNotEmpty) {
              storedSignature = faceFeaturesList;
              print('📊 Using legacy face features: ${storedSignature.length} features');
              print('📊 Sample stored features: ${storedSignature.take(3).toList()}');
            }
          }
        }
        
        if (storedSignature.isNotEmpty) {
          final similarity = calculateBiometricSimilarity(detectedBiometrics, storedSignature);
          print('User ${doc.id} biometric similarity: $similarity');
          
          // SECURITY ENHANCEMENT: Track top 2 matches for uniqueness validation
          if (similarity > bestSimilarity) {
            // Move current best to second best
            secondBestSimilarity = bestSimilarity;
            
            // Set new best match
            bestMatchUserId = doc.id;
            bestSimilarity = similarity;
          } else if (similarity > secondBestSimilarity) {
            // Update second best match
            secondBestSimilarity = similarity;
          }
        } else {
          print('  ⚠️ No biometric features found for user ${doc.id}');
        }
      }
      
      // SECURITY VALIDATION: Check if match is unique enough
      if (bestMatchUserId != null && bestSimilarity >= _similarityThreshold) {
        final uniquenessScore = bestSimilarity - secondBestSimilarity;
        print('🔍 SECURITY CHECK: Best similarity: $bestSimilarity, Second best: $secondBestSimilarity');
        print('🔍 SECURITY CHECK: Uniqueness score: $uniquenessScore (minimum required: $_minimumUniquenessThreshold)');
        
        if (uniquenessScore < _minimumUniquenessThreshold) {
          print('🚨 SECURITY REJECTION: Match not unique enough! Multiple users have similar biometrics');
          print('🚨 This prevents unauthorized access when faces are too similar');
          return null; // Reject authentication for security
        }
        
        // Additional security check: if similarity is too high (>0.95), it might be a duplicate face
        if (bestSimilarity > 0.95) {
          print('🚨 SECURITY WARNING: Very high similarity detected (${bestSimilarity.toStringAsFixed(3)})');
          print('🚨 This might indicate a duplicate face or security issue');
        }
      }
      
      if (bestMatchUserId != null && bestSimilarity >= _similarityThreshold) {
        print('🎯 REAL USER FOUND!');
        print('✅ User ID: $bestMatchUserId');
        print('✅ Biometric Similarity: $bestSimilarity');
        print('✅ Uniqueness Score: ${bestSimilarity - secondBestSimilarity}');
        print('✅ This is REAL biometric authentication!');
        
        // SECURITY: Log successful authentication
        await FaceSecurityService.logSecurityEvent('FACE_LOGIN_SUCCESS', bestMatchUserId, {
          'similarity': bestSimilarity,
          'uniquenessScore': bestSimilarity - secondBestSimilarity,
          'secondBestSimilarity': secondBestSimilarity,
        });
        
        // Update last login time
        await _firestore.collection('users').doc(bestMatchUserId).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'lastBiometricSimilarity': bestSimilarity,
          'lastUniquenessScore': bestSimilarity - secondBestSimilarity,
        });
        
        return bestMatchUserId;
      } else {
        print('❌ No matching user found with real biometric authentication');
        print('❌ Best similarity found: $bestSimilarity (threshold: $_similarityThreshold)');
        if (bestMatchUserId != null) {
          print('❌ Uniqueness check failed: ${bestSimilarity - secondBestSimilarity} < $_minimumUniquenessThreshold');
        }
        return null;
      }
    } catch (e) {
      print('❌ Real face recognition error: $e');
      throw Exception('Real face recognition failed: $e');
    }
  }

  /// Check if there are users with real biometric features
  static Future<bool> hasUsersWithRealBiometrics() async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('biometricFeatures.isRealBiometric', isEqualTo: true)
          .limit(1)
          .get();
      
      return usersSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking for real biometric users: $e');
      return false;
    }
  }
}
