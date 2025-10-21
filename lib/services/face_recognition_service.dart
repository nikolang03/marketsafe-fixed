import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'dart:math';
import 'real_face_recognition_service.dart';

// Configuration class for face recognition sensitivity
class FaceRecognitionConfig {
  // Multi-layer security thresholds - Made more lenient for better authentication success
  static const double primarySimilarityThreshold = 0.75;  // Primary threshold (more lenient)
  static const double strictSimilarityThreshold = 0.90;   // Strict threshold for high security
  static const double friendRejectionThreshold = 0.70;    // Threshold to reject friends (lowered)
  static const double friendRejectionUpper = 0.98;        // Upper bound of friend similarity band (expanded)
  static const double confidenceThreshold = 0.60;          // Confidence level for decision (lowered)
  
  // Simple liveness detection (blink-based)
  static const double minEyeOpenProbability = 0.3; // Minimum eye open probability for basic liveness (lowered)
  
  // Similarity calculation weights
  static const double cosineWeight = 0.8; // Weight for cosine similarity (increased)
  static const double euclideanWeight = 0.2; // Weight for Euclidean similarity (decreased)
  
  // Face embedding configuration
  static const int embeddingSize = 128; // 128D embeddings for better accuracy
  static const bool useDeepLearningEmbeddings = true; // Use 128D embeddings instead of landmarks
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

  // Extract 128D face features/embeddings from a detected face
  static Future<List<double>> extractFaceFeatures(Face face, [CameraImage? cameraImage]) async {
    try {
      print('🔍 FaceRecognitionService: Extracting 128D face features...');
      
      if (FaceRecognitionConfig.useDeepLearningEmbeddings) {
        // Always use 128D deep learning embeddings for better accuracy
        print('🧠 Using 128D deep learning embeddings...');
        
        if (cameraImage != null) {
          // Use camera image for better embedding quality
          final embedding = await RealFaceRecognitionService.extractBiometricFeatures(face, cameraImage);
          print('✅ Generated ${embedding.length}D face embedding from camera image');
          return embedding;
        } else {
          // Generate 128D embedding without camera image (using face landmarks)
          print('⚠️ No camera image available, generating 128D embedding from face landmarks...');
          final embedding = await RealFaceRecognitionService.extractBiometricFeatures(face, null);
          print('✅ Generated ${embedding.length}D face embedding from landmarks');
          return embedding;
        }
      } else {
        throw Exception('Deep learning embeddings are required but disabled in configuration');
      }
    } catch (e) {
      print('❌ FaceRecognitionService: Error extracting 128D face features: $e');
      throw Exception('Failed to extract 128D face features: $e');
    }
  }
  
  
  
  // Calculate similarity between two face feature vectors with improved robustness
  static double calculateSimilarity(List<double> features1, List<double> features2) {
    if (features1.length != features2.length) return 0.0;
    
    // For 128D embeddings, use cosine similarity (more appropriate for normalized embeddings)
    if (features1.length == FaceRecognitionConfig.embeddingSize) {
      return RealFaceRecognitionService.calculateBiometricSimilarity(features1, features2);
    }
    
    // For legacy features, use the old method
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

  /// Additional security verification: Check face characteristics
  static bool _verifyFaceCharacteristics(List<double> detected, List<double> stored) {
    if (detected.length != stored.length) return false;
    
    // Check for significant differences in key facial features
    // Compare first 32 dimensions (geometry features)
    double geometryDifference = 0.0;
    for (int i = 0; i < 32 && i < detected.length && i < stored.length; i++) {
      geometryDifference += (detected[i] - stored[i]).abs();
    }
    geometryDifference /= 32.0;
    
    // If geometry difference is too high, it's likely a different person (made more lenient)
    if (geometryDifference > 0.5) {
      print('❌ Face characteristics verification failed: geometry difference too high ($geometryDifference)');
      return false;
    }
    
    // Check for pattern consistency in texture features (dimensions 32-64)
    double textureConsistency = 0.0;
    for (int i = 32; i < 64 && i < detected.length && i < stored.length; i++) {
      textureConsistency += (detected[i] - stored[i]).abs();
    }
    textureConsistency /= 32.0;
    
    if (textureConsistency > 0.6) {
      print('❌ Face characteristics verification failed: texture consistency too low ($textureConsistency)');
      return false;
    }
    
    print('✅ Face characteristics verification passed');
    return true;
  }

  /// Additional security verification: Check embedding uniqueness
  static bool _verifyEmbeddingUniqueness(List<double> detected, List<double> stored) {
    if (detected.length != stored.length) return false;
    
    // Calculate multiple similarity metrics
    final cosineSim = _calculateCosineSimilarity(detected, stored);
    final euclideanSim = _calculateEuclideanSimilarity(detected, stored);
    
    // Very lenient thresholds for better usability (made even more lenient)
    if (cosineSim < 0.60 || euclideanSim < 0.15) {
      print('❌ Embedding uniqueness verification failed: cosine=$cosineSim, euclidean=$euclideanSim');
      return false;
    }
    
    // Check for consistent patterns across different feature groups
    final geometrySim = _calculateCosineSimilarity(
      detected.take(32).toList(),
      stored.take(32).toList(),
    );
    
    if (geometrySim < 0.50) {
      print('❌ Embedding uniqueness verification failed: geometry similarity too low ($geometrySim)');
      return false;
    }
    
    print('✅ Embedding uniqueness verification passed');
    return true;
  }
  
  // Store face features for a user
  static Future<void> storeFaceFeatures(String userId, List<double> features) async {
    try {
      print('🔄 FaceRecognitionService: Storing face features for user: $userId');
      print('📊 FaceRecognitionService: Features: ${features.length} dimensions');
      print('📊 FaceRecognitionService: Sample features: ${features.take(5).toList()}');
      
      // Store features in the new format for better compatibility
      final faceData = {
        'featureVector': features,
        'featureCount': features.length,
        'embeddingType': features.length == FaceRecognitionConfig.embeddingSize ? '128D' : '22D',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('users').doc(userId).update({
        'faceFeatures': faceData,
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
  static Future<String?> findUserByFace(Face detectedFace, [CameraImage? cameraImage]) async {
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
      
      // Extract features from the detected face (now supports 128D embeddings)
      final detectedFeatures = await extractFaceFeatures(detectedFace, cameraImage);
      print('Extracted ${detectedFeatures.length} features from detected face');
      
      // Get all users (we'll filter face features and verification status in code)
      final usersSnapshot = await _firestore
          .collection('users')
          .get();
      
      // Filter for verified users with face features
      final verifiedUsers = usersSnapshot.docs.where((doc) {
        final userData = doc.data();
        return userData['verificationStatus'] == 'verified' && 
               userData['faceFeatures'] != null;
      }).toList();
      
      print('🔍 SCANNING ALL VERIFIED ACCOUNTS...');
      print('📊 Found ${verifiedUsers.length} verified users with stored face features');
      print('🎯 Will check each account until exact match is found...');
      
      // Debug: Log details about stored face features
      for (final doc in verifiedUsers) {
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
      
      if (verifiedUsers.isEmpty) {
        print('No verified users with face features found');
        return null;
      }
      
      String? bestMatchUserId;
      double bestSimilarity = 0.0;
      double bestConfidence = 0.0;
      Map<String, dynamic> bestMatchDetails = {};
      
      print('🔄 Starting account-by-account comparison...');
      print('📋 Account list:');
      for (int i = 0; i < verifiedUsers.length; i++) {
        final doc = verifiedUsers[i];
        final userData = doc.data();
        final email = userData['email'] ?? 'Unknown';
        print('  ${i + 1}. ${doc.id} (${email})');
      }
      print('');
      
      // Compare with each user's stored features (scan all accounts)
      for (int i = 0; i < verifiedUsers.length; i++) {
        final doc = verifiedUsers[i];
        final userData = doc.data();
        final email = userData['email'] ?? 'Unknown';
        
        print('🔍 Checking account ${i + 1}/${verifiedUsers.length}: ${doc.id} (${email})');
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
          print('  📊 Similarity score: $similarity');
          print('  🔍 Detected features: ${detectedFeatures.take(5).toList()}');
          print('  🔍 Stored features: ${storedFeatures.take(5).toList()}');
          
          // Multi-layer verification system
          final verificationResult = _performMultiLayerVerification(
            detectedFeatures, 
            storedFeatures, 
            doc.id
          );
          
          print('  📊 Verification result for ${doc.id}:');
          print('    - Similarity: ${verificationResult['similarity']}');
          print('    - Confidence: ${verificationResult['confidence']}');
          print('    - Security Level: ${verificationResult['securityLevel']}');
          print('    - Is Match: ${verificationResult['isMatch']}');
          
          // Update best match if this is better
          if (verificationResult['isMatch'] && 
              verificationResult['confidence'] > bestConfidence) {
            bestMatchUserId = doc.id;
            bestSimilarity = verificationResult['similarity'];
            bestConfidence = verificationResult['confidence'];
            bestMatchDetails = verificationResult;
            print('🎯 NEW BEST MATCH: ${doc.id} (confidence: ${verificationResult['confidence']})');
          }
        } else {
          print('User ${doc.id} has no valid face features');
        }
      }
      
      print('🏁 SCAN COMPLETE - Analyzing results...');
      
      if (bestMatchUserId != null) {
        print('🎯 EXACT USER FOUND!');
        print('✅ User ID: $bestMatchUserId');
        print('✅ Similarity: $bestSimilarity');
        print('✅ Confidence: $bestConfidence');
        print('✅ Security Level: ${bestMatchDetails['securityLevel']}');
        print('✅ This user matches your face exactly!');
        
        // Update last login time
        await _firestore.collection('users').doc(bestMatchUserId).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'lastFaceLoginSimilarity': bestSimilarity,
          'lastFaceLoginConfidence': bestConfidence,
        });
        
        return bestMatchUserId;
      } else {
        print('❌ NO EXACT MATCH FOUND');
        print('❌ Scanned all ${verifiedUsers.length} verified accounts');
        print('❌ Best similarity found: $bestSimilarity');
        print('❌ Best confidence found: $bestConfidence');
        print('❌ Your face does not match any registered user');
        print('🔍 DEBUGGING INFO:');
        print('  - Primary threshold: ${FaceRecognitionConfig.primarySimilarityThreshold}');
        print('  - Confidence threshold: ${FaceRecognitionConfig.confidenceThreshold}');
        print('  - Detected features length: ${detectedFeatures.length}');
        print('  - Sample detected features: ${detectedFeatures.take(5).toList()}');
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

  // Simple liveness detection (very lenient - no positioning requirements)
  static bool _verifyLiveness(Face face) {
    try {
      print('🔍 Performing simple liveness detection (very lenient)...');
      
      // Check if eyes are open (very basic liveness check)
      final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;
      
      print('👁️ Eye probabilities - Left: $leftEyeOpen, Right: $rightEyeOpen');
      
      // Very lenient eye open requirement (almost always passes)
      if (leftEyeOpen < 0.1 || rightEyeOpen < 0.1) {
        print('❌ Liveness check failed: eyes not open enough');
        return false;
      }
      
      print('✅ Liveness detection passed - eyes are open');
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

  /// Multi-layer verification system that combines multiple security checks
  static Map<String, dynamic> _performMultiLayerVerification(
    List<double> detectedFeatures, 
    List<double> storedFeatures, 
    String userId
  ) {
    final similarity = calculateSimilarity(detectedFeatures, storedFeatures);
    
    // Layer 1: Basic similarity check
    final basicSimilarityPass = similarity >= FaceRecognitionConfig.primarySimilarityThreshold;
    
    // Layer 2: Face characteristics verification
    final characteristicsPass = _verifyFaceCharacteristics(detectedFeatures, storedFeatures);
    
    // Layer 3: Embedding uniqueness verification
    final uniquenessPass = _verifyEmbeddingUniqueness(detectedFeatures, storedFeatures);
    
    // Layer 4: Friend rejection check (reject if similarity is in friend range)
    final friendRejectionPass = !(similarity >= FaceRecognitionConfig.friendRejectionThreshold 
      && similarity <= FaceRecognitionConfig.friendRejectionUpper);
    
    // Layer 5: Confidence calculation based on multiple factors
    double confidence = 0.0;
    String securityLevel = 'LOW';
    
    // Calculate confidence based on all layers
    if (basicSimilarityPass) confidence += 0.3;
    if (characteristicsPass) confidence += 0.25;
    if (uniquenessPass) confidence += 0.25;
    if (friendRejectionPass) confidence += 0.2;
    
    // Determine security level
    if (confidence >= 0.9) {
      securityLevel = 'MAXIMUM';
    } else if (confidence >= 0.8) {
      securityLevel = 'HIGH';
    } else if (confidence >= 0.7) {
      securityLevel = 'MEDIUM';
    } else {
      securityLevel = 'LOW';
    }
    
    // Additional check: For very high confidence (1.0), require much higher similarity to distinguish exact matches
    final highConfidenceThreshold = confidence >= 0.95 ? 0.945 : FaceRecognitionConfig.primarySimilarityThreshold;
    final highConfidencePass = similarity >= highConfidenceThreshold;
    
    // Final decision: Must pass all critical layers AND have high confidence AND pass high confidence check
    final isMatch = basicSimilarityPass && 
                   characteristicsPass && 
                   uniquenessPass && 
                   friendRejectionPass && 
                   highConfidencePass &&
                   confidence >= FaceRecognitionConfig.confidenceThreshold;
    
    print('    🔍 Multi-layer analysis:');
    print('      - Basic similarity: $basicSimilarityPass ($similarity)');
    print('      - Characteristics: $characteristicsPass');
    print('      - Uniqueness: $uniquenessPass');
    print('      - Friend rejection: $friendRejectionPass');
    print('      - High confidence check: $highConfidencePass (threshold: $highConfidenceThreshold)');
    print('      - Final confidence: $confidence');
    print('      - Security level: $securityLevel');
    print('      - Is match: $isMatch');
    
    return {
      'similarity': similarity,
      'confidence': confidence,
      'securityLevel': securityLevel,
      'isMatch': isMatch,
      'basicSimilarityPass': basicSimilarityPass,
      'characteristicsPass': characteristicsPass,
      'uniquenessPass': uniquenessPass,
      'friendRejectionPass': friendRejectionPass,
    };
  }
}
