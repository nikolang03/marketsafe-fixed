import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'face_recognition_service.dart';

class ProfilePhotoVerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );

  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: false, // Not needed for static image
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  /// Verify that the uploaded profile photo matches the user's registered face
  /// and upload it to Firebase Storage
  static Future<ProfilePhotoVerificationResult> verifyAndUploadProfilePhoto(
    String imagePath,
  ) async {
    try {
      print('🔍 Starting profile photo verification and upload...');

      // Get current user ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('signup_user_id') ?? 
                    prefs.getString('current_user_id') ?? '';
      
      if (userId.isEmpty) {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'No user logged in',
          similarity: 0.0,
        );
      }

      // Load and process the image
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'No face detected in the uploaded photo',
          similarity: 0.0,
        );
      }

      if (faces.length > 1) {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'Multiple faces detected. Please upload a photo with only one face.',
          similarity: 0.0,
        );
      }

      final detectedFace = faces.first;

      // Check if the face in the photo matches the user's registered face
      final verificationResult = await _verifyFaceMatch(userId, detectedFace);
      
      if (verificationResult.success) {
        // Upload photo to Firebase Storage
        try {
          final downloadUrl = await _uploadProfilePhotoToStorage(imagePath, userId);
          
          // Update user document with profile photo URL
          await _updateUserProfilePhoto(userId, downloadUrl);
          
          // Save local path to SharedPreferences
          await prefs.setString('profile_image_path', imagePath);
          await prefs.setString('profile_image_url', downloadUrl);
          
          return ProfilePhotoVerificationResult(
            success: true,
            error: null,
            similarity: verificationResult.similarity,
            message: 'Profile photo verified and uploaded successfully',
            downloadUrl: downloadUrl,
          );
        } catch (e) {
          return ProfilePhotoVerificationResult(
            success: false,
            error: 'Failed to upload photo: $e',
            similarity: verificationResult.similarity,
          );
        }
      } else {
        return verificationResult;
      }

    } catch (e) {
      print('❌ Error in profile photo verification: $e');
      return ProfilePhotoVerificationResult(
        success: false,
        error: 'Verification failed: $e',
        similarity: 0.0,
      );
    }
  }

  /// Verify if the detected face matches the user's registered face
  static Future<ProfilePhotoVerificationResult> _verifyFaceMatch(
    String userId,
    Face detectedFace,
  ) async {
    try {
      // Get user's stored face features
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'User data not found',
          similarity: 0.0,
        );
      }

      final userData = userDoc.data()!;
      final storedFaceFeatures = userData['faceFeatures'];

      if (storedFaceFeatures == null) {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'No face data found for this user. Please complete face verification first.',
          similarity: 0.0,
        );
      }

      // Extract features from the uploaded photo
      final detectedFeatures = FaceRecognitionService.extractFaceFeatures(detectedFace);
      
      // Handle different face features formats
      List<double> storedFeatures = [];
      
      if (storedFaceFeatures is Map && storedFaceFeatures.containsKey('featureVector')) {
        // New format: {featureVector: [...], featureCount: 128, ...}
        final featureVector = storedFaceFeatures['featureVector'];
        if (featureVector is List) {
          storedFeatures = featureVector.cast<double>();
        }
      } else if (storedFaceFeatures is List) {
        // Old format: direct list of features
        storedFeatures = storedFaceFeatures.cast<double>();
      }

      if (storedFeatures.isEmpty) {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'Invalid face data format',
          similarity: 0.0,
        );
      }

      // Calculate similarity
      final similarity = FaceRecognitionService.calculateSimilarity(
        detectedFeatures, 
        storedFeatures,
      );

      print('📊 Face similarity calculation:');
      print('   - Detected features: ${detectedFeatures.length}');
      print('   - Stored features: ${storedFeatures.length}');
      print('   - Similarity score: $similarity');

      // Use a higher threshold for profile photo verification (more strict)
      const double verificationThreshold = 0.6; // 60% similarity required
      
      if (similarity >= verificationThreshold) {
        return ProfilePhotoVerificationResult(
          success: true,
          error: null,
          similarity: similarity,
          message: 'Profile photo verified successfully',
        );
      } else {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'The uploaded photo doesn\'t match to the face verification',
          similarity: similarity,
        );
      }

    } catch (e) {
      print('❌ Error verifying face match: $e');
      return ProfilePhotoVerificationResult(
        success: false,
        error: 'Face verification failed: $e',
        similarity: 0.0,
      );
    }
  }

  /// Upload profile photo to Firebase Storage
  static Future<String> _uploadProfilePhotoToStorage(String imagePath, String userId) async {
    try {
      print('📤 Uploading profile photo to Firebase Storage...');
      
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file does not exist at path: $imagePath');
      }
      
      final fileSize = await file.length();
      print('📏 Profile photo file size: $fileSize bytes');
      
      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('profile_photos/$userId/profile_$timestamp.jpg');
      
      print('☁️ Uploading to Firebase Storage path: ${ref.fullPath}');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('🎉 Profile photo upload completed. Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('💥 Profile photo upload failed: $e');
      throw Exception('Failed to upload profile photo: $e');
    }
  }

  /// Update user document with profile photo URL
  static Future<void> _updateUserProfilePhoto(String userId, String downloadUrl) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'profilePictureUrl': downloadUrl,
        'profilePhotoUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ User profile photo URL updated in database');
    } catch (e) {
      print('❌ Error updating user profile photo URL: $e');
      throw Exception('Failed to update user profile photo: $e');
    }
  }

  /// Check if user has completed face verification
  static Future<bool> hasUserCompletedFaceVerification(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final faceFeatures = userData['faceFeatures'];
      final faceData = userData['faceData'];
      
      // Check if user has face features stored
      bool hasFaceFeatures = faceFeatures != null;
      
      // Check if user has completed face verification steps
      bool hasCompletedVerification = faceData != null &&
          faceData['blinkCompleted'] == true &&
          faceData['moveCloserCompleted'] == true &&
          faceData['headMovementCompleted'] == true;
      
      return hasFaceFeatures && hasCompletedVerification;
    } catch (e) {
      print('❌ Error checking face verification status: $e');
      return false;
    }
  }
}

/// Result of profile photo verification
class ProfilePhotoVerificationResult {
  final bool success;
  final String? error;
  final double similarity;
  final String? message;
  final String? downloadUrl;

  ProfilePhotoVerificationResult({
    required this.success,
    this.error,
    required this.similarity,
    this.message,
    this.downloadUrl,
  });
}