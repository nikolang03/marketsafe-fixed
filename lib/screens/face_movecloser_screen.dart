import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'face_headmovement_screen.dart';
import '../services/face_recognition_service.dart';
import '../services/face_uniqueness_service.dart';

class FaceMoveCloserScreen extends StatefulWidget {
  const FaceMoveCloserScreen({super.key});

  @override
  State<FaceMoveCloserScreen> createState() => _FaceMoveCloserScreenState();
}

class _FaceMoveCloserScreenState extends State<FaceMoveCloserScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  late final FaceDetector _faceDetector;
  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  bool _isFaceCloseEnough = false;
  Timer? _detectionTimer;
  bool _useImageStream = true;
  double _progressPercentage = 0.0;
  bool _hasCheckedFaceUniqueness = false;
  Face? _lastDetectedFace; // Store the last detected face for feature extraction

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1,
      ),
    );
    // Add a delay to ensure the previous camera is fully disposed
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _initializeCamera();
      }
    });
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
      // Check camera permission first
      final cameraStatus = await Permission.camera.status;

      if (cameraStatus.isDenied) {
        final result = await Permission.camera.request();
        if (result.isDenied) {
          if (mounted) {
            setState(() {
              _isCameraInitialized = false;
            });
          }
          return;
        }
      }

      if (cameraStatus.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
        return;
      }

      // Wait a bit more if camera is still in use
      await Future.delayed(const Duration(milliseconds: 200));

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

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = controller.value.isInitialized;
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
          _detectFaceDistance(faces.first);
        } else {
          if (mounted) {
            setState(() {
              _progressPercentage = 0.0;
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

      if (faces.isNotEmpty) {
        _detectFaceDistance(faces.first);
      } else {
        if (mounted) {
          setState(() {
            _progressPercentage = 0.0;
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

  void _detectFaceDistance(Face face) async {
    // Store the face for feature extraction
    _lastDetectedFace = face;
    
    // Check face uniqueness on first detection
    if (!_hasCheckedFaceUniqueness && _progressPercentage == 0.0) {
      final isFaceAlreadyRegistered =
          await FaceUniquenessService.isFaceAlreadyRegistered(face);
      if (isFaceAlreadyRegistered) {
        if (mounted) {
          _showFaceAlreadyRegisteredDialog();
        }
        return;
      }
      _hasCheckedFaceUniqueness = true;
    }
    
    final box = face.boundingBox;
    final faceHeight = box.height;
    final faceWidth = box.width;

    // Calculate progress based on face size
    // Target: face should fill most of the screen (350x350+ pixels)
    const targetSize = 350.0;

    final sizeProgress = ((faceHeight + faceWidth) / 2) / targetSize;
    final progress = (sizeProgress * 100).clamp(0.0, 100.0);

    if (mounted) {
      setState(() {
        _progressPercentage = progress;
        _isFaceCloseEnough = faceHeight > targetSize && faceWidth > targetSize;
      });
    }

    // If face is close enough, proceed to next screen
    if (_isFaceCloseEnough) {
      if (mounted) {
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
          print('🔄 Saving move closer verification data to SharedPreferences with imagePath: $imagePath');
          final prefs = await SharedPreferences.getInstance();
          
          // Save verification step completion
          await prefs.setBool('face_verification_moveCloserCompleted', true);
          await prefs.setString('face_verification_moveCloserCompletedAt', DateTime.now().toIso8601String());
          
          // Upload face image to Firebase Storage and save path
          String? firebaseImageUrl;
          if (imagePath != null) {
            print('🔄 Storing face image locally during signup...');
            // Store local path - will upload to Firebase Storage after signup completion
            firebaseImageUrl = imagePath;
            await prefs.setString('face_verification_moveCloserImagePath', firebaseImageUrl);
            print('✅ Face image stored locally: $firebaseImageUrl');
          } else {
            print('⚠️ No image path to save for move closer');
          }
          
          // Save metrics
          await prefs.setString('face_verification_moveCloserMetrics', 
            '{"completionTime": "${DateTime.now().toIso8601String()}", "faceSize": $faceHeight}');
          
          // Store face features for recognition
          if (_lastDetectedFace != null) {
            final faceFeatures = FaceRecognitionService.extractFaceFeatures(_lastDetectedFace!);
            final featuresString = faceFeatures.map((f) => f.toString()).join(',');
            await prefs.setString('face_verification_moveCloserFeatures', featuresString);
            print('✅ Face features extracted and saved: ${faceFeatures.length} dimensions');
          }
          
          print('✅ Move closer verification data saved to SharedPreferences successfully');
        } catch (e) {
          // Handle error silently or show user feedback
          print('⚠️ Failed to save move closer verification data to SharedPreferences: $e');
        }

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FaceHeadMovementScreen()),
            );
          }
        });
      }
    }
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
                          _isFaceCloseEnough ? Colors.green : Colors.red,
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
                        child: _isCameraInitialized &&
                                _cameraController != null &&
                                _cameraController!.value.isInitialized
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
                _isFaceCloseEnough ? "SUCCESS!" : "MOVE CLOSER",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: _isFaceCloseEnough ? Colors.green : Colors.red,
                  letterSpacing: 0.5,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Helpful instruction
              Text(
                _isFaceCloseEnough 
                  ? "Great job! Moving to next step..." 
                  : "Move your face closer to the camera until it fills the frame",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Progress text
              Text(
                "Progress: ${_progressPercentage.toInt()}%",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 5),
              
              // Instructions
              Text(
                "Position your face in the center and move closer",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              
              
              if (_isFaceCloseEnough)
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

  void _showFaceAlreadyRegisteredDialog() {
    // Navigate directly to welcome screen with dialog flag
    Navigator.pushReplacementNamed(
      context, 
      '/welcome',
      arguments: {'showFaceDuplicationDialog': true},
    );
  }
}