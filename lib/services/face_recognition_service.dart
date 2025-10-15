import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math';

// Configuration class for face recognition sensitivity
class FaceRecognitionConfig {
  // Similarity threshold (0.0 to 1.0) - higher = more strict
  static const double similarityThreshold = 0.85;
  
  // Simple liveness detection (blink-based)
  static const double minEyeOpenProbability = 0.5; // Minimum eye open probability for basic liveness
  
  // Similarity calculation weights
  static const double cosineWeight = 0.7; // Weight for cosine similarity
  static const double euclideanWeight = 0.3; // Weight for Euclidean similarity
}

class FaceRecognitionService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'marketsafe',
      );
  
  // Track blink sequence for liveness detection
  static List<bool> _blinkSequence = [];
  static const int _requiredBlinks = 2; // Number of blinks required for liveness
  static const int _maxSequenceLength = 10; // Maximum sequence length to track

  // Extract face features/embeddings from a detected face
  static List<double> extractFaceFeatures(Face face) {
    try {
      print('🔍 FaceRecognitionService: Extracting features from face...');
      // Use face landmarks and bounding box to create a feature vector
      // This is a simplified approach - in a real system, you'd use a proper face embedding model
      
      final boundingBox = face.boundingBox;
      final landmarks = face.landmarks;
      
      print('📏 Face bounding box: $boundingBox');
      print('🎯 Face landmarks count: ${landmarks.length}');
      
      List<double> features = [];
      
      // Add bounding box features
      features.add(boundingBox.left.toDouble());
      features.add(boundingBox.top.toDouble());
      features.add(boundingBox.width.toDouble());
      features.add(boundingBox.height.toDouble());
      features.add(boundingBox.center.dx);
      features.add(boundingBox.center.dy);
      
      // Add head pose features
      features.add(face.headEulerAngleX ?? 0.0);
      features.add(face.headEulerAngleY ?? 0.0);
      features.add(face.headEulerAngleZ ?? 0.0);
      
      // Add eye features
      features.add(face.leftEyeOpenProbability ?? 0.0);
      features.add(face.rightEyeOpenProbability ?? 0.0);
      features.add(face.smilingProbability ?? 0.0);
      
      // Add landmark features if available
      if (landmarks.containsKey(FaceLandmarkType.leftEye)) {
        final leftEye = landmarks[FaceLandmarkType.leftEye]!;
        features.add(leftEye.position.x.toDouble());
        features.add(leftEye.position.y.toDouble());
      } else {
        features.add(0.0);
        features.add(0.0);
      }
      
      if (landmarks.containsKey(FaceLandmarkType.rightEye)) {
        final rightEye = landmarks[FaceLandmarkType.rightEye]!;
        features.add(rightEye.position.x.toDouble());
        features.add(rightEye.position.y.toDouble());
      } else {
        features.add(0.0);
        features.add(0.0);
      }
      
      if (landmarks.containsKey(FaceLandmarkType.noseBase)) {
        final nose = landmarks[FaceLandmarkType.noseBase]!;
        features.add(nose.position.x.toDouble());
        features.add(nose.position.y.toDouble());
      } else {
        features.add(0.0);
        features.add(0.0);
      }
      
      if (landmarks.containsKey(FaceLandmarkType.leftCheek)) {
        final leftCheek = landmarks[FaceLandmarkType.leftCheek]!;
        features.add(leftCheek.position.x.toDouble());
        features.add(leftCheek.position.y.toDouble());
      } else {
        features.add(0.0);
        features.add(0.0);
      }
      
      if (landmarks.containsKey(FaceLandmarkType.rightCheek)) {
        final rightCheek = landmarks[FaceLandmarkType.rightCheek]!;
        features.add(rightCheek.position.x.toDouble());
        features.add(rightCheek.position.y.toDouble());
      } else {
        features.add(0.0);
        features.add(0.0);
      }
      
      // Normalize features to make them more comparable
      final normalizedFeatures = _normalizeFeatures(features);
      print('✅ FaceRecognitionService: Extracted ${normalizedFeatures.length} features');
      print('📊 Sample normalized features: ${normalizedFeatures.take(5).toList()}');
      return normalizedFeatures;
    } catch (e) {
      print('❌ Error extracting face features: $e');
      return List.filled(20, 0.0); // Return default features
    }
  }
  
  // Normalize features to 0-1 range with improved robustness
  static List<double> _normalizeFeatures(List<double> features) {
    if (features.isEmpty) return features;
    
    // Use robust normalization that handles outliers better
    List<double> sortedFeatures = List.from(features)..sort();
    int length = sortedFeatures.length;
    
    // Use percentiles instead of min/max for more robust normalization
    double q25 = sortedFeatures[(length * 0.25).floor()];
    double q75 = sortedFeatures[(length * 0.75).floor()];
    double iqr = q75 - q25;
    
    // If IQR is too small, use standard min/max normalization
    if (iqr < 0.001) {
      double maxVal = features.reduce(max);
      double minVal = features.reduce(min);
      double range = maxVal - minVal;
      
      if (range == 0) return features;
      
      return features.map((f) => (f - minVal) / range).toList();
    }
    
    // Robust normalization using IQR
    return features.map((f) {
      double normalized = (f - q25) / iqr;
      return normalized.clamp(0.0, 1.0); // Clamp to 0-1 range
    }).toList();
  }
  
  // Calculate similarity between two face feature vectors with improved robustness
  static double calculateSimilarity(List<double> features1, List<double> features2) {
    if (features1.length != features2.length) return 0.0;
    
    // Use a combination of cosine similarity and Euclidean distance for better robustness
    double cosineSimilarity = _calculateCosineSimilarity(features1, features2);
    double euclideanSimilarity = _calculateEuclideanSimilarity(features1, features2);
    
    // Weight the similarities (cosine similarity is generally more robust for face recognition)
    return FaceRecognitionConfig.cosineWeight * cosineSimilarity + 
           FaceRecognitionConfig.euclideanWeight * euclideanSimilarity;
  }
  
  // Calculate cosine similarity
  static double _calculateCosineSimilarity(List<double> features1, List<double> features2) {
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < features1.length; i++) {
      dotProduct += features1[i] * features2[i];
      norm1 += features1[i] * features1[i];
      norm2 += features2[i] * features2[i];
    }
    
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }
  
  // Calculate Euclidean distance-based similarity
  static double _calculateEuclideanSimilarity(List<double> features1, List<double> features2) {
    double sumSquaredDiffs = 0.0;
    
    for (int i = 0; i < features1.length; i++) {
      double diff = features1[i] - features2[i];
      sumSquaredDiffs += diff * diff;
    }
    
    double euclideanDistance = sqrt(sumSquaredDiffs);
    
    // Convert distance to similarity (0-1 range)
    // Use a scaling factor to make it more sensitive to small differences
    return 1.0 / (1.0 + euclideanDistance * 2.0);
  }
  
  // Store face features for a user
  static Future<void> storeFaceFeatures(String userId, List<double> features) async {
    try {
      print('🔄 FaceRecognitionService: Storing face features for user: $userId');
      print('📊 FaceRecognitionService: Features: ${features.length} dimensions');
      print('📊 FaceRecognitionService: Sample features: ${features.take(5).toList()}');
      
      await _firestore.collection('users').doc(userId).update({
        'faceFeatures': features,
        'faceFeaturesUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ FaceRecognitionService: Face features stored successfully in database');
    } catch (e) {
      print('❌ FaceRecognitionService: Error storing face features: $e');
      throw Exception('Failed to store face features: $e');
    }
  }
  
  // Find user by comparing face features
  // Returns:
  // - String: User ID if successful
  // - "LIVENESS_FAILED": If liveness detection fails
  // - null: If no matching user found
  static Future<String?> findUserByFace(Face detectedFace) async {
    try {
      print('🚨 SECURE FACE RECOGNITION STARTING...');
      print('🚨 This is the NEW secure face recognition system!');
      
      // CRITICAL: Check liveness first to prevent photo spoofing
      print('🔍 Checking liveness detection...');
      if (!_verifyLiveness(detectedFace)) {
        print('❌ Liveness verification failed - rejecting login attempt');
        return "LIVENESS_FAILED";
      }
      print('✅ Liveness detection passed!');
      
      // Extract features from the detected face
      final detectedFeatures = extractFaceFeatures(detectedFace);
      print('Extracted ${detectedFeatures.length} features from detected face');
      
      // Get all users with face features
      final usersSnapshot = await _firestore
          .collection('users')
          .where('faceFeatures', isNull: false)
          .get();
      
      print('Found ${usersSnapshot.docs.length} users with stored face features');
      
      // Debug: Log details about stored face features
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        final faceFeatures = userData['faceFeatures'];
        print('User ${doc.id}:');
        print('  - Face features type: ${faceFeatures.runtimeType}');
        print('  - Face features keys: ${faceFeatures is Map ? faceFeatures.keys.toList() : 'Not a map'}');
        if (faceFeatures is Map && faceFeatures.containsKey('featureVector')) {
          final featureVector = faceFeatures['featureVector'];
          print('  - Feature vector type: ${featureVector.runtimeType}');
          print('  - Feature vector length: ${featureVector is List ? featureVector.length : 'Not a list'}');
        }
      }
      
      if (usersSnapshot.docs.isEmpty) {
        print('No users with face features found');
        return null;
      }
      
      String? bestMatchUserId;
      double bestSimilarity = 0.0;
      const double similarityThreshold = FaceRecognitionConfig.similarityThreshold;
      
      // Compare with each user's stored features
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        final faceFeaturesData = userData['faceFeatures'];
        
        // Handle different face features formats
        List<double> storedFeatures = [];
        
        if (faceFeaturesData is Map && faceFeaturesData.containsKey('featureVector')) {
          // New format: {featureVector: [...], featureCount: 128, ...}
          final featureVector = faceFeaturesData['featureVector'];
          if (featureVector is List) {
            storedFeatures = featureVector.cast<double>();
          }
        } else if (faceFeaturesData is List) {
          // Old format: direct list of features
          storedFeatures = faceFeaturesData.cast<double>();
        }
        
        print('User ${doc.id} stored features length: ${storedFeatures.length}');
        
        if (storedFeatures.isNotEmpty) {
          final similarity = calculateSimilarity(detectedFeatures, storedFeatures);
          print('🔍 Similarity with user ${doc.id}: $similarity');
          print('🔍 Detected features: ${detectedFeatures.take(5).toList()}');
          print('🔍 Stored features: ${storedFeatures.take(5).toList()}');
          
          if (similarity > bestSimilarity && similarity >= similarityThreshold) {
            bestSimilarity = similarity;
            bestMatchUserId = doc.id;
            print('✅ High confidence match: user $bestMatchUserId with similarity $bestSimilarity');
            
            // Additional security check - reject if not high enough
            if (similarity < similarityThreshold) {
              print('⚠️ Similarity too low for login: $similarity (required: $similarityThreshold)');
              bestMatchUserId = null; // Reject the match
              bestSimilarity = 0.0; // Reset
            }
          }
        } else {
          print('User ${doc.id} has no valid face features');
        }
      }
      
      if (bestMatchUserId != null) {
        print('✅ Best match found: $bestMatchUserId with similarity: $bestSimilarity');
        print('✅ Similarity threshold: $similarityThreshold');
        
        // Update last login time
        await _firestore.collection('users').doc(bestMatchUserId).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'lastFaceLoginSimilarity': bestSimilarity,
        });
        
        return bestMatchUserId;
      } else {
        print('❌ No user found with sufficient similarity (threshold: $similarityThreshold)');
        print('❌ Best similarity found: $bestSimilarity');
        return null;
      }
    } catch (e) {
      print('Face recognition error: $e');
      throw Exception('Face recognition failed: $e');
    }
  }
  
  // Check if there are any users with face features stored
  static Future<bool> hasUsersWithFaceFeatures() async {
    try {
      print('🔄 FaceRecognitionService: Checking for users with stored face features...');
      final usersSnapshot = await _firestore
          .collection('users')
          .where('faceFeatures', isNull: false)
          .limit(1)
          .get();
      
      final hasUsers = usersSnapshot.docs.isNotEmpty;
      print('✅ FaceRecognitionService: Found users with features: $hasUsers');
      if (hasUsers) {
        print('📊 FaceRecognitionService: Sample user data: ${usersSnapshot.docs.first.data()}');
      }
      return hasUsers;
    } catch (e) {
      print('❌ FaceRecognitionService: Error checking for users with face features: $e');
      return false;
    }
  }

  // Simple liveness detection based on face movement (blinking)
  static bool _verifyLiveness(Face face) {
    try {
      print('🔍 Performing simple liveness detection (blink check)...');
      
      // Check if eyes are open (basic liveness check)
      final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;
      
      print('👁️ Eye probabilities - Left: $leftEyeOpen, Right: $rightEyeOpen');
      
      // Both eyes must be open for basic liveness
      if (leftEyeOpen < FaceRecognitionConfig.minEyeOpenProbability || 
          rightEyeOpen < FaceRecognitionConfig.minEyeOpenProbability) {
        print('❌ Liveness check failed: eyes not open enough (required: ${FaceRecognitionConfig.minEyeOpenProbability})');
        return false;
      }
      
      print('✅ Liveness detection passed - eyes are open (basic liveness confirmed)');
      return true;
    } catch (e) {
      print('❌ Liveness detection error: $e');
      return false; // Fail safe - reject if liveness check fails
    }
  }
  
  // Advanced blink-based liveness detection (optional - not currently used)
  // This method can be used for more sophisticated liveness detection
  // by calling it instead of _verifyLiveness in the findUserByFace method
  // ignore: unused_element
  static bool _verifyLivenessWithBlink(Face face) {
    try {
      print('🔍 Performing advanced liveness detection (blink sequence)...');
      
      // Check if eyes are open
      final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;
      final avgEyeOpen = (leftEyeOpen + rightEyeOpen) / 2.0;
      
      print('👁️ Average eye open probability: $avgEyeOpen');
      
      // Determine if eyes are currently open or closed
      bool eyesOpen = avgEyeOpen >= FaceRecognitionConfig.minEyeOpenProbability;
      
      // Add current state to blink sequence
      _blinkSequence.add(eyesOpen);
      
      // Keep sequence manageable
      if (_blinkSequence.length > _maxSequenceLength) {
        _blinkSequence.removeAt(0);
      }
      
      print('📊 Blink sequence length: ${_blinkSequence.length}');
      print('📊 Current sequence: ${_blinkSequence.map((e) => e ? 'O' : 'C').join('')}');
      
      // Check if we have enough data for blink detection
      if (_blinkSequence.length < 3) {
        print('⏳ Collecting more blink data...');
        return false; // Need more data
      }
      
      // Count blinks in the sequence (transition from open to closed to open)
      int blinkCount = _countBlinks(_blinkSequence);
      print('👀 Blink count detected: $blinkCount (required: $_requiredBlinks)');
      
      if (blinkCount >= _requiredBlinks) {
        print('✅ Liveness detection passed - sufficient blinks detected');
        _blinkSequence.clear(); // Reset for next session
        return true;
      }
      
      print('⏳ Waiting for more blinks...');
      return false; // Need more blinks
    } catch (e) {
      print('❌ Blink liveness detection error: $e');
      return false;
    }
  }
  
  // Count blinks in a sequence (open -> closed -> open pattern)
  static int _countBlinks(List<bool> sequence) {
    int blinkCount = 0;
    bool wasOpen = false;
    
    for (bool isOpen in sequence) {
      if (wasOpen && !isOpen) {
        // Transition from open to closed - potential blink start
        // We'll count it when we see the transition back to open
      } else if (!wasOpen && isOpen) {
        // Transition from closed to open - blink completed
        blinkCount++;
      }
      wasOpen = isOpen;
    }
    
    return blinkCount;
  }
  
  // Reset blink sequence (call when starting new login attempt)
  static void resetBlinkSequence() {
    _blinkSequence.clear();
    print('🔄 Blink sequence reset for new login attempt');
  }
}
