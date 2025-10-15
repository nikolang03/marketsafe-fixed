import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'face_movecloser_screen.dart';
import '../services/face_uniqueness_service.dart';
import '../services/face_recognition_service.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  late final FaceDetector _faceDetector;

  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  bool isBlinking = false;
  bool isAccomplished = false;
  DateTime? lastBlinkTime;
  Timer? _detectionTimer;
  bool _useImageStream = true;
  double _progressPercentage = 0.0;
  int _blinkCount = 0;
  bool _hasCheckedFaceUniqueness = false;
  Face? _lastDetectedFace; // Store the last detected face for feature extraction


  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // required for eye probabilities
        enableLandmarks: true, // helps with eye detection
        enableContours: true, // helps with face shape detection
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1, // smaller minimum face size for better detection
      ),
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    try {
      _cameraController?.stopImageStream();
    } catch (_) {
      // Ignore camera disposal errors
    }
    try {
      _cameraController?.dispose();
    } catch (_) {
      // Ignore camera disposal errors
    }
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
      });

      // Try image stream first, fallback to timer-based detection
      try {
        await controller.startImageStream(_processCameraImage);
        _useImageStream = true;
      } catch (e) {
        _useImageStream = false;
        _startTimerBasedDetection();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _startTimerBasedDetection() {
    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_isProcessingImage || _cameraController == null || !mounted) return;

      try {
        final XFile image = await _cameraController!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          _detectBlink(faces.first);
        } else {
          if (mounted) {
            setState(() {
              _progressPercentage = 0.0;
              _blinkCount = 0;
            });
          }
        }
      } catch (e) {
        // Timer-based detection error
      }
    });
  }

  // Convert camera image to bytes for ML Kit
  Uint8List _bytesFromPlanes(CameraImage image) {
    final bytesBuilder = BytesBuilder(copy: false);
    for (final Plane plane in image.planes) {
      bytesBuilder.add(plane.bytes);
    }
    return bytesBuilder.toBytes();
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage ||
        !_isCameraInitialized ||
        _cameraController == null) return;
    _isProcessingImage = true;

    try {
      final camera = _cameraController!.description;
      final bytes = _bytesFromPlanes(image);
      final size = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = _rotationFromSensor(camera.sensorOrientation);

      // Try different image formats based on the camera image format
      InputImageFormat inputFormat;
      switch (image.format.group) {
        case ImageFormatGroup.yuv420:
          inputFormat = InputImageFormat.yuv420;
          break;
        case ImageFormatGroup.bgra8888:
          inputFormat = InputImageFormat.bgra8888;
          break;
        case ImageFormatGroup.nv21:
          inputFormat = InputImageFormat.nv21;
          break;
        default:
          inputFormat = InputImageFormat.yuv420; // Default fallback
      }

      final metadata = InputImageMetadata(
        size: size,
        rotation: rotation,
        format: inputFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

      final faces = await _faceDetector.processImage(inputImage);

      print('🔍 Face detection result: ${faces.length} faces found');

      if (faces.isNotEmpty) {
        print('👤 Processing first face for blink detection');
        _detectBlink(faces.first);
      } else {
        print('❌ No faces detected');
        if (mounted) {
          setState(() {
            _progressPercentage = 0.0;
            _blinkCount = 0;
          });
        }
      }
    } catch (e) {
      // If image stream fails, try timer-based detection
      if (_useImageStream) {
        try {
          _cameraController?.stopImageStream();
        } catch (_) {}
        _useImageStream = false;
        _startTimerBasedDetection();
      }
    } finally {
      _isProcessingImage = false;
    }
  }

  void _detectBlink(Face face) async {
    final leftProb = face.leftEyeOpenProbability;
    final rightProb = face.rightEyeOpenProbability;

    if (leftProb == null || rightProb == null) {
      return;
    }

    // Store the face for feature extraction
    _lastDetectedFace = face;

    print('👁️ Eye probabilities - Left: $leftProb, Right: $rightProb, Blink count: $_blinkCount');

    // Check face uniqueness only once on first detection
    if (!_hasCheckedFaceUniqueness && _blinkCount == 0 && _progressPercentage == 0.0) {
      _hasCheckedFaceUniqueness = true;
      final isFaceAlreadyRegistered =
          await FaceUniquenessService.isFaceAlreadyRegistered(face);
      if (isFaceAlreadyRegistered) {
        if (mounted) {
          _showFaceAlreadyRegisteredDialog();
        }
        return;
      }
    }

    // More lenient thresholds for better detection
    const closedThreshold = 0.4;
    const openThreshold = 0.5;

    // Update UI with current eye probabilities
    if (mounted) {
      setState(() {
        _progressPercentage = 10.0; // Show some progress when face is detected
      });
    }

    final eyesClosed =
        (leftProb < closedThreshold && rightProb < closedThreshold);
    final eyesOpen = (leftProb > openThreshold && rightProb > openThreshold);

    print('👁️ Eyes closed: $eyesClosed, Eyes open: $eyesOpen, Currently blinking: $isBlinking');

    if (eyesClosed && !isBlinking) {
      print('👁️ Eyes closed detected - starting blink');
      if (mounted) {
        setState(() {
          isBlinking = true;
          _progressPercentage = 30.0; // Progress when eyes are closed
        });
      }
    } else if (eyesOpen && isBlinking) {
      print('👁️ Eyes open detected - completing blink #${_blinkCount + 1}');
      if (mounted) {
        setState(() {
          isBlinking = false;
          _blinkCount++;
          _progressPercentage = 50.0 +
              (_blinkCount * 25.0); // 50% for first blink, 75% for second
        });
      }
      _handleBlink();
    }
  }

  void _handleBlink() async {
    final now = DateTime.now();

    // Check if we have enough blinks (2 or more)
    if (_blinkCount >= 2) {
      if (!mounted) return;
      setState(() {
        isAccomplished = true;
        _progressPercentage = 100.0; // Complete success
      });

      // Capture face image before proceeding
      String? imagePath;
      try {
        if (_cameraController != null && 
            _cameraController!.value.isInitialized) {
          print('📸 Attempting to capture face image...');
          final XFile image = await _cameraController!.takePicture();
          imagePath = image.path;
          print('📸 Face image captured successfully: $imagePath');
          
          // Verify the file exists
          final file = File(imagePath);
          if (await file.exists()) {
            final fileSize = await file.length();
            print('📏 Captured image file size: $fileSize bytes');
          } else {
            print('❌ Captured image file does not exist!');
            imagePath = null;
          }
        } else {
          print('⚠️ Camera not ready for image capture:');
          print('   - Controller null: ${_cameraController == null}');
          if (_cameraController != null) {
            print('   - Initialized: ${_cameraController!.value.isInitialized}');
            print('   - Error: ${_cameraController!.value.errorDescription}');
          }
        }
      } catch (e) {
        print('⚠️ Failed to capture face image: $e');
        imagePath = null;
      }

      // Save face verification progress to SharedPreferences
      try {
        print('🔄 Saving face verification data to SharedPreferences with imagePath: $imagePath');
        final prefs = await SharedPreferences.getInstance();
        
        // Save verification step completion
        await prefs.setBool('face_verification_blinkCompleted', true);
        await prefs.setString('face_verification_blinkCompletedAt', DateTime.now().toIso8601String());
        
        // Upload face image to Firebase Storage and save path
        String? firebaseImageUrl;
        if (imagePath != null) {
          print('🔄 Storing face image locally during signup...');
          // Store local path - will upload to Firebase Storage after signup completion
          firebaseImageUrl = imagePath;
          await prefs.setString('face_verification_blinkImagePath', firebaseImageUrl);
          print('✅ Face image stored locally: $firebaseImageUrl');
        } else {
          print('⚠️ No image path to save for blink verification');
        }
        
        // Save metrics
        await prefs.setString('face_verification_blinkMetrics', 
          '{"blinkCount": $_blinkCount, "completionTime": "${DateTime.now().toIso8601String()}"}');
        
        // Store face features for recognition
        if (_lastDetectedFace != null) {
          print('🔍 Extracting face features from last detected face...');
          final faceFeatures = FaceRecognitionService.extractFaceFeatures(_lastDetectedFace!);
          final featuresString = faceFeatures.map((f) => f.toString()).join(',');
          await prefs.setString('face_verification_blinkFeatures', featuresString);
          print('✅ Face features extracted and saved: ${faceFeatures.length} dimensions');
          print('📊 Sample features: ${faceFeatures.take(5).toList()}');
        } else {
          print('⚠️ No face detected to extract features from');
        }
        
        print('✅ Face verification data saved to SharedPreferences successfully');
      } catch (e) {
        // Handle error silently or show user feedback
        print('⚠️ Failed to save face verification data to SharedPreferences: $e');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FaceMoveCloserScreen()),
      );
    }
    lastBlinkTime = now;
  }

  void _showFaceAlreadyRegisteredDialog() {
    // Navigate directly to welcome screen with dialog flag
    Navigator.pushReplacementNamed(
      context, 
      '/welcome',
      arguments: {'showFaceDuplicationDialog': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/logo.png', 
                height: 60,
              ),
              
              const SizedBox(height: 30),
              
              // Title
              Text(
                "FACE VERIFICATION",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 20,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
              
              
              const SizedBox(height: 30),
              
              // Camera preview with elliptical shape and progress border
              SizedBox(
                width: 250,
                height: 350,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress border
                    SizedBox(
                      width: 250,
                      height: 350,
                      child: CircularProgressIndicator(
                        value: _progressPercentage / 100.0,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isAccomplished ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    // Camera preview container
                    Container(
                      width: 240,
                      height: 340,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.elliptical(120, 170),
                          topRight: Radius.elliptical(120, 170),
                          bottomLeft: Radius.elliptical(120, 170),
                          bottomRight: Radius.elliptical(120, 170),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.elliptical(120, 170),
                          topRight: Radius.elliptical(120, 170),
                          bottomLeft: Radius.elliptical(120, 170),
                          bottomRight: Radius.elliptical(120, 170),
                        ),
                        child: _isCameraInitialized && _cameraController != null
                            ? CameraPreview(_cameraController!)
                            : Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Status text
              Text(
                isAccomplished ? "SUCCESS!" : "BLINK TWICE",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isAccomplished ? Colors.green : Colors.red,
                  letterSpacing: 0.5,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Helpful instruction
              Text(
                isAccomplished 
                  ? "Great job! Moving to next step..." 
                  : "Just blink naturally - any eye movement will be detected!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Progress text
              Text(
                "Progress: ${_progressPercentage.toInt()}% (${_blinkCount}/2 blinks)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 5),
              
              // Instructions
              Text(
                "Blink naturally - the system will detect your eye movements",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              
              
              if (isAccomplished)
                const Text(
                  "Navigating to next screen...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}