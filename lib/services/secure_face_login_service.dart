import 'dart:async';
import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'real_face_recognition_service.dart';

class SecureFaceLoginService {
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  // Secure login with liveness detection
  static Future<String?> secureFaceLogin(CameraController cameraController, [CameraImage? cameraImage]) async {
    try {
      print('🔒 Starting secure face login with liveness detection...');
      
      // Step 1: Initial face detection
      final initialFace = await _detectFace(cameraController);
      if (initialFace == null) {
        print('❌ No face detected');
        return null;
      }

      // Step 2: Liveness detection (blink test)
      print('👁️ Starting liveness detection...');
      final livenessResult = await _performLivenessDetection(cameraController);
      if (!livenessResult) {
        print('❌ Liveness detection failed');
        return null;
      }

      // Step 3: Face recognition with high threshold
      print('🔍 Performing face recognition...');
      // Use the provided camera image for 128D embedding extraction
      final userId = await RealFaceRecognitionService.findUserByRealFace(initialFace, cameraImage);
      
      if (userId != null) {
        print('✅ Secure login successful for user: $userId');
        return userId;
      } else {
        print('❌ Face recognition failed - no matching user found');
        return null;
      }
    } catch (e) {
      print('❌ Secure login error: $e');
      return null;
    }
  }

  // Detect face from camera
  static Future<Face?> _detectFace(CameraController cameraController) async {
    try {
      final image = await cameraController.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceDetector.processImage(inputImage);
      
      // Clean up
      final file = File(image.path);
      if (await file.exists()) {
        await file.delete();
      }
      
      return faces.isNotEmpty ? faces.first : null;
    } catch (e) {
      print('❌ Error detecting face: $e');
      return null;
    }
  }

  // Perform liveness detection (blink test)
  static Future<bool> _performLivenessDetection(CameraController cameraController) async {
    try {
      List<double> eyeProbabilities = [];
      const int maxFrames = 30; // 6 seconds at 200ms intervals
      
      for (int i = 0; i < maxFrames; i++) {
        final image = await cameraController.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final faces = await _faceDetector.processImage(inputImage);
        
        if (faces.isNotEmpty) {
          final face = faces.first;
          final leftEyeProb = face.leftEyeOpenProbability ?? 0.0;
          final rightEyeProb = face.rightEyeOpenProbability ?? 0.0;
          final avgEyeProb = (leftEyeProb + rightEyeProb) / 2.0;
          
          eyeProbabilities.add(avgEyeProb);
          
          // Keep only last 10 probabilities
          if (eyeProbabilities.length > 10) {
            eyeProbabilities.removeAt(0);
          }
          
          // Check for blink pattern
          if (eyeProbabilities.length >= 8) {
            final recent = eyeProbabilities.skip(eyeProbabilities.length - 8).toList();
            final minProb = recent.reduce((a, b) => a < b ? a : b);
            final maxProb = recent.reduce((a, b) => a > b ? a : b);
            
            if (minProb < 0.3 && maxProb > 0.7) {
              print('✅ Blink detected - liveness confirmed');
              return true;
            }
          }
        }
        
        // Clean up
        final file = File(image.path);
        if (await file.exists()) {
          await file.delete();
        }
        
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      print('❌ No blink detected - liveness failed');
      return false;
    } catch (e) {
      print('❌ Liveness detection error: $e');
      return false;
    }
  }
}