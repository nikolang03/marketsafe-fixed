import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'real_face_recognition_service.dart';
import 'watermarking_service.dart';

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
      final storedBiometricFeatures = userData['biometricFeatures'];

      if (storedBiometricFeatures == null) {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'No face data found for this user. Please complete face verification first.',
          similarity: 0.0,
        );
      }

      // Extract features from the uploaded photo
      final detectedFeatures = await RealFaceRecognitionService.extractBiometricFeatures(detectedFace);
      
      // Handle biometric features format with fallback to face features
      List<double> storedFeatures = [];
      
      if (storedBiometricFeatures is Map && storedBiometricFeatures.containsKey('biometricSignature')) {
        // New format: {biometricSignature: [...], featureCount: 64, ...}
        final biometricSignature = storedBiometricFeatures['biometricSignature'];
        if (biometricSignature is List) {
          storedFeatures = biometricSignature.cast<double>();
          print('📊 Using biometric signature: ${storedFeatures.length} features');
        }
      } else if (storedBiometricFeatures is List) {
        // Old format: direct list of features
        storedFeatures = storedBiometricFeatures.cast<double>();
        print('📊 Using direct biometric features: ${storedFeatures.length} features');
      } else {
        // Fallback to face features if biometric features not available
        print('⚠️ No biometric features found, checking face features...');
        final faceFeatures = userData['faceFeatures'];
        if (faceFeatures is String) {
          final faceFeaturesList = faceFeatures.split(',').map((e) => double.tryParse(e) ?? 0.0).toList();
          if (faceFeaturesList.isNotEmpty) {
            storedFeatures = faceFeaturesList;
            print('📊 Using legacy face features: ${storedFeatures.length} features');
          }
        }
      }

      if (storedFeatures.isEmpty) {
        return ProfilePhotoVerificationResult(
          success: false,
          error: 'Invalid face data format',
          similarity: 0.0,
        );
      }

      // Use a strict threshold for profile photos (security is important)
      const double verificationThreshold = 0.7; // 70% similarity required (strict)
      
      // Calculate similarity
      final similarity = RealFaceRecognitionService.calculateBiometricSimilarity(
        detectedFeatures, 
        storedFeatures,
      );
      
      print('📊 Face similarity calculation:');
      print('   - Detected features: ${detectedFeatures.length}');
      print('   - Stored features: ${storedFeatures.length}');
      print('   - Similarity score: $similarity');
      print('   - Threshold required: $verificationThreshold');
      print('   - Sample detected features: ${detectedFeatures.take(3).toList()}');
      print('   - Sample stored features: ${storedFeatures.take(3).toList()}');
      
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
      
      // Get username for watermarking
      String username = 'user_$userId';
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null && userData['username'] != null) {
          username = userData['username'];
        }
      } catch (e) {
        print('⚠️ Could not get username for watermarking: $e');
      }
      
      // Validate image authenticity and add watermark
      print('🎨 Adding watermark and metadata to profile photo for user: $username');
      final fileBytes = await file.readAsBytes();
      
      // Check if image is from internet
      final isFromInternet = await WatermarkingService.isImageFromInternet(fileBytes);
      if (isFromInternet) {
        throw Exception('Profile photos from internet/web are not allowed. Please use images taken with your device camera.');
      }
      
      // Validate image authenticity
      final validationResult = await WatermarkingService.validateImageAuthenticity(
        imageBytes: fileBytes,
        username: username,
        userId: userId,
      );
      
      if (!validationResult['isAuthentic'] && validationResult['warnings'].isNotEmpty) {
        print('⚠️ Profile photo authenticity warnings: ${validationResult['warnings']}');
        // Continue with upload but log warnings
      }
      
      final watermarkedBytes = await WatermarkingService.addWatermarkToImage(
        imageBytes: fileBytes,
        username: username,
        userId: userId,
        customText: '@$username',
        customPosition: WatermarkPosition.center,
        customSize: 0.8,
        customOpacity: 0.9,
        customColor: WatermarkColor.yellow,
      );
      print('✅ Watermark and metadata added to profile photo successfully');
      
      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('profile_photos/$userId/profile_$timestamp.jpg');
      
      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'watermarked': 'true',
          'username': username,
        },
      );
      
      print('☁️ Uploading watermarked profile photo to Firebase Storage path: ${ref.fullPath}');
      final uploadTask = await ref.putData(watermarkedBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('🎉 Watermarked profile photo upload completed. Download URL: $downloadUrl');
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
      final biometricFeatures = userData['biometricFeatures'];
      final faceData = userData['faceData'];
      
      // Check if user has biometric features stored
      bool hasBiometricFeatures = biometricFeatures != null;
      
      // Check if user has completed face verification steps
      bool hasCompletedVerification = faceData != null &&
          faceData['blinkCompleted'] == true &&
          faceData['moveCloserCompleted'] == true &&
          faceData['headMovementCompleted'] == true;
      
      return hasBiometricFeatures && hasCompletedVerification;
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