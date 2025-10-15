import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class SignupFaceVerificationService {
  static final SignupFaceVerificationService _instance = SignupFaceVerificationService._internal();
  factory SignupFaceVerificationService() => _instance;
  SignupFaceVerificationService._internal();

  late FaceDetector _faceDetector;
  
  // Verification state
  bool _isVerificationComplete = false;
  double _verificationProgress = 0.0;
  String _currentStep = "Initializing...";
  Map<String, dynamic> _verificationData = {};
  
  // Face tracking variables
  List<Rect> _facePositions = [];
  List<double> _faceSizes = [];
  List<double> _eyeProbabilities = [];
  int _frameCount = 0;
  DateTime? _verificationStartTime;

  void initialize() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1,
      ),
    );
  }

  // Main verification method for signup
  Future<bool> performSignupVerification(CameraController cameraController) async {
    print('🔍 Starting comprehensive signup face verification...');
    
    _verificationStartTime = DateTime.now();
    _isVerificationComplete = false;
    _verificationProgress = 0.0;
    _currentStep = "Detecting face...";
    
    const int maxFrames = 200; // 40 seconds at 200ms intervals
    int verificationStep = 0;
    
    for (int i = 0; i < maxFrames; i++) {
      try {
        final image = await cameraController.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final faces = await _faceDetector.processImage(inputImage);
        
        if (faces.isNotEmpty) {
          final face = faces.first;
          _frameCount++;
          
          // Update face tracking data
          _updateFaceTrackingData(face);
          
          // Perform verification steps
          
          switch (verificationStep) {
            case 0:
              // Step 1: Face presence and quality check
              if (_verifyFacePresence(face)) {
                _currentStep = "Face detected - checking quality...";
                _verificationProgress = 20.0;
                verificationStep = 1;
              }
              break;
              
            case 1:
              // Step 2: Face stability check (anti-spoofing)
              if (_verifyFaceStability()) {
                _currentStep = "Face stable - checking liveness...";
                _verificationProgress = 40.0;
                verificationStep = 2;
              }
              break;
              
            case 2:
              // Step 3: Liveness detection (blink + movement)
              if (_verifyLiveness(face)) {
                _currentStep = "Liveness confirmed - checking angles...";
                _verificationProgress = 60.0;
                verificationStep = 3;
              }
              break;
              
            case 3:
              // Step 4: Head pose verification
              if (_verifyHeadPose(face)) {
                _currentStep = "Pose verified - final validation...";
                _verificationProgress = 80.0;
                verificationStep = 4;
              }
              break;
              
            case 4:
              // Step 5: Final comprehensive check
              if (_performFinalVerification(face)) {
                _currentStep = "Verification complete!";
                _verificationProgress = 100.0;
                _isVerificationComplete = true;
                
                // Save verification data
                _saveVerificationData(face);
                
                print('🎉 Signup face verification successful!');
                return true;
              }
              break;
          }
          
          // Debug output every 20 frames
          if (_frameCount % 20 == 0) {
            print('Verification Step: $verificationStep, Progress: ${_verificationProgress.toStringAsFixed(1)}%');
            print('Current Step: $_currentStep');
            print('Face Area: ${face.boundingBox.width * face.boundingBox.height}');
            print('Eye Probabilities: ${_eyeProbabilities.isNotEmpty ? _eyeProbabilities.last.toStringAsFixed(3) : "N/A"}');
          }
        } else {
          _currentStep = "No face detected - please look at camera";
          _verificationProgress = 0.0;
        }
        
        // Clean up
        try {
          final file = File(image.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore cleanup errors
        }
        
        await Future.delayed(const Duration(milliseconds: 200));
        
      } catch (e) {
        print('Error in signup verification: $e');
      }
    }
    
    print('❌ Signup verification failed - timeout');
    return false;
  }

  // Step 1: Verify face presence and quality
  bool _verifyFacePresence(Face face) {
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final hasEyes = face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null;
    final hasLandmarks = face.landmarks.isNotEmpty;
    
    // Quality checks
    bool isGoodQuality = faceArea > 20000; // Minimum face size
    bool hasRequiredFeatures = hasEyes && hasLandmarks;
    bool isWellPositioned = _isFaceWellPositioned(face);
    
    return isGoodQuality && hasRequiredFeatures && isWellPositioned;
  }

  // Check if face is well positioned in frame
  bool _isFaceWellPositioned(Face face) {
    final bbox = face.boundingBox;
    final centerX = bbox.left + bbox.width / 2;
    final centerY = bbox.top + bbox.height / 2;
    
    // Face should be roughly centered
    return centerX > 100 && centerX < 300 && centerY > 100 && centerY < 400;
  }

  // Step 2: Verify face stability (anti-spoofing)
  bool _verifyFaceStability() {
    if (_facePositions.length < 10) return false;
    
    // Check position stability
    double positionVariance = _calculatePositionVariance();
    bool isPositionStable = positionVariance < 1000; // Threshold for stability
    
    // Check size stability
    double sizeVariance = _calculateSizeVariance();
    bool isSizeStable = sizeVariance < 5000; // Threshold for size stability
    
    return isPositionStable && isSizeStable;
  }

  // Calculate position variance
  double _calculatePositionVariance() {
    if (_facePositions.length < 2) return 0.0;
    
    double totalVariance = 0.0;
    for (int i = 1; i < _facePositions.length; i++) {
      final prev = _facePositions[i - 1];
      final curr = _facePositions[i];
      final distance = math.sqrt(
        math.pow(prev.center.dx - curr.center.dx, 2) + 
        math.pow(prev.center.dy - curr.center.dy, 2)
      );
      totalVariance += distance;
    }
    
    return totalVariance / (_facePositions.length - 1);
  }

  // Calculate size variance
  double _calculateSizeVariance() {
    if (_faceSizes.length < 2) return 0.0;
    
    final mean = _faceSizes.reduce((a, b) => a + b) / _faceSizes.length;
    final variance = _faceSizes.map((size) => math.pow(size - mean, 2)).reduce((a, b) => a + b) / _faceSizes.length;
    
    return variance;
  }

  // Step 3: Verify liveness (blink + movement)
  bool _verifyLiveness(Face face) {
    // Check for eye blink
    bool hasBlinked = _detectBlink(face);
    
    // Check for natural movement
    bool hasMovement = _detectNaturalMovement();
    
    // Check for eye probability variation
    bool hasEyeVariation = _detectEyeVariation();
    
    return hasBlinked && hasMovement && hasEyeVariation;
  }

  // Detect blink
  bool _detectBlink(Face face) {
    final leftEyeProb = face.leftEyeOpenProbability ?? 0.0;
    final rightEyeProb = face.rightEyeOpenProbability ?? 0.0;
    
    if (leftEyeProb > 0.0 && rightEyeProb > 0.0) {
      final avgEyeProb = (leftEyeProb + rightEyeProb) / 2.0;
      _eyeProbabilities.add(avgEyeProb);
      
      // Keep only last 20 probabilities
      if (_eyeProbabilities.length > 20) {
        _eyeProbabilities.removeAt(0);
      }
      
      // Check for blink pattern (low probability followed by high)
      if (_eyeProbabilities.length >= 10) {
        final recent = _eyeProbabilities.skip(_eyeProbabilities.length - 10).toList();
        final minProb = recent.reduce(math.min);
        final maxProb = recent.reduce(math.max);
        
        return minProb < 0.3 && maxProb > 0.7; // Blink detected
      }
    }
    
    return false;
  }

  // Detect natural movement
  bool _detectNaturalMovement() {
    if (_facePositions.length < 15) return false;
    
    // Check for subtle movement patterns
    double totalMovement = 0.0;
    for (int i = 1; i < _facePositions.length; i++) {
      final prev = _facePositions[i - 1];
      final curr = _facePositions[i];
      final movement = math.sqrt(
        math.pow(prev.center.dx - curr.center.dx, 2) + 
        math.pow(prev.center.dy - curr.center.dy, 2)
      );
      totalMovement += movement;
    }
    
    final avgMovement = totalMovement / (_facePositions.length - 1);
    return avgMovement > 2.0 && avgMovement < 20.0; // Natural movement range
  }

  // Detect eye variation
  bool _detectEyeVariation() {
    if (_eyeProbabilities.length < 10) return false;
    
    final recent = _eyeProbabilities.skip(_eyeProbabilities.length - 10).toList();
    final minProb = recent.reduce(math.min);
    final maxProb = recent.reduce(math.max);
    
    return (maxProb - minProb) > 0.3; // Sufficient variation
  }

  // Step 4: Verify head pose
  bool _verifyHeadPose(Face face) {
    // Check if face is roughly frontal
    final bbox = face.boundingBox;
    final aspectRatio = bbox.width / bbox.height;
    
    // Face should be roughly square (not too wide or too tall)
    bool isGoodAspectRatio = aspectRatio > 0.7 && aspectRatio < 1.3;
    
    // Check for landmarks presence
    bool hasKeyLandmarks = face.landmarks.containsKey(FaceLandmarkType.leftEye) &&
                          face.landmarks.containsKey(FaceLandmarkType.rightEye) &&
                          face.landmarks.containsKey(FaceLandmarkType.noseBase);
    
    return isGoodAspectRatio && hasKeyLandmarks;
  }

  // Step 5: Final comprehensive verification
  bool _performFinalVerification(Face face) {
    // All previous checks must pass
    bool faceQuality = _verifyFacePresence(face);
    bool stability = _verifyFaceStability();
    bool liveness = _verifyLiveness(face);
    bool pose = _verifyHeadPose(face);
    
    // Additional final checks
    bool sufficientFrames = _frameCount >= 50; // At least 10 seconds of data
    bool goodEyeProbabilities = _eyeProbabilities.isNotEmpty && 
                               _eyeProbabilities.last > 0.5; // Eyes should be open at end
    
    return faceQuality && stability && liveness && pose && sufficientFrames && goodEyeProbabilities;
  }

  // Update face tracking data
  void _updateFaceTrackingData(Face face) {
    _facePositions.add(face.boundingBox);
    _faceSizes.add(face.boundingBox.width * face.boundingBox.height);
    
    // Keep only last 30 positions
    if (_facePositions.length > 30) {
      _facePositions.removeAt(0);
    }
    if (_faceSizes.length > 30) {
      _faceSizes.removeAt(0);
    }
  }

  // Save verification data
  void _saveVerificationData(Face face) {
    _verificationData = {
      'verificationTime': DateTime.now().toIso8601String(),
      'verificationDuration': _verificationStartTime != null 
          ? DateTime.now().difference(_verificationStartTime!).inMilliseconds 
          : 0,
      'frameCount': _frameCount,
      'faceArea': face.boundingBox.width * face.boundingBox.height,
      'eyeProbabilities': _eyeProbabilities,
      'facePositions': _facePositions.map((pos) => {
        'x': pos.left,
        'y': pos.top,
        'width': pos.width,
        'height': pos.height,
      }).toList(),
      'verificationSteps': [
        'Face presence and quality check',
        'Face stability verification',
        'Liveness detection',
        'Head pose verification',
        'Final comprehensive check'
      ],
      'success': true,
    };
  }

  // Get current verification status
  Map<String, dynamic> getVerificationStatus() {
    return {
      'isComplete': _isVerificationComplete,
      'progress': _verificationProgress,
      'currentStep': _currentStep,
      'frameCount': _frameCount,
      'data': _verificationData,
    };
  }

  // Reset verification state
  void reset() {
    _isVerificationComplete = false;
    _verificationProgress = 0.0;
    _currentStep = "Initializing...";
    _verificationData = {};
    _facePositions.clear();
    _faceSizes.clear();
    _eyeProbabilities.clear();
    _frameCount = 0;
    _verificationStartTime = null;
  }

  void dispose() {
    _faceDetector.close();
  }
}
