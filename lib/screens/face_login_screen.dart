import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_login_service.dart';
import '../services/lockout_service.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';
import 'under_verification_screen.dart';
import '../navigation_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  late final FaceDetector _faceDetector;
  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  bool _isAuthenticating = false;
  bool _isFaceDetected = false;
  Timer? _detectionTimer;
  double _progressPercentage = 0.0;
  bool _useImageStream = true;
  DateTime? _lastAuthenticationAttempt;
  DateTime? _lastDialogShown;
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;
  static const Duration _authenticationCooldown = Duration(seconds: 3);
  static const Duration _dialogCooldown = Duration(seconds: 10);
  static const Duration _lockoutDuration = Duration(minutes: 5);
  static const int _maxFailedAttempts = 5;
  

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // Enable for better detection
        enableLandmarks: true, // Enable for better detection
        enableContours: true, // Enable for better detection
        performanceMode:
            FaceDetectorMode.accurate, // Use accurate mode for better detection
        minFaceSize: 0.01, // Very small minimum face size for better detection
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
    } catch (_) {}
    _faceDetector.close();
    _cameraController?.dispose();
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

      _cameraController = controller;
      setState(() {
        _isCameraInitialized = true;
      });

      print('Camera initialized successfully!');
      print('Camera preview size: ${controller.value.previewSize}');
      print('Camera description: ${controller.description}');

      // Try image stream first, fallback to timer-based detection
      try {
        _startImageStream();
      } catch (e) {
        print('Image stream failed, using timer-based detection: $e');
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

  void _startImageStream() {
    if (_cameraController == null) return;

    try {
      print('Starting image stream for face detection...');
      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessingImage || _isAuthenticating) return;
        _processImage(image);
      });
      _useImageStream = true;
    } catch (e) {
      print('Error starting image stream: $e');
      // If image stream fails, use timer-based detection
      _useImageStream = false;
      _startTimerBasedDetection();
    }
  }

  void _startTimerBasedDetection() {
    print('Starting timer-based face detection...');
    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (_isProcessingImage || _isAuthenticating) return;
      print('Timer tick - processing image...');
      _processImageFromFile();
    });
  }

  bool _isDialogShowing = false;

  void _stopCamera() {
    print('Stopping camera...');
    _detectionTimer?.cancel();
    _detectionTimer = null;

    // Also stop image stream if it's running
  if (_useImageStream && _cameraController != null) {
    try {
      _cameraController!.stopImageStream();
    } catch (e) {
      print('Error stopping image stream: $e');
    }
  }
  _isDialogShowing = true;
}

  void _resumeCamera() {
  print('Resuming camera...');
  _isDialogShowing = false; // Reset the flag
  if (_detectionTimer == null) {
    _startTimerBasedDetection();
  }
}

  void _trackFailedAttempt() {
    _failedAttempts++;
    _lastFailedAttempt = DateTime.now();
    print('Failed attempt $_failedAttempts/$_maxFailedAttempts');
  }

  bool _isLockedOut() {
    if (_failedAttempts < _maxFailedAttempts) return false;
    if (_lastFailedAttempt == null) return false;

    final now = DateTime.now();
    final timeSinceLastAttempt = now.difference(_lastFailedAttempt!);

    if (timeSinceLastAttempt > _lockoutDuration) {
      // Reset lockout after 5 minutes
      _failedAttempts = 0;
      _lastFailedAttempt = null;
      return false;
    }

    return true;
  }

  // Update the _processImage method to check the flag
Future<void> _processImage(CameraImage image) async {
  if (_isProcessingImage || _isAuthenticating || _isDialogShowing) return;
    setState(() {
      _isProcessingImage = true;
    });

    try {
      // Try the direct camera image approach first
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        print(
            'Failed to create input image from camera image, trying alternative approach...');
        // Try alternative approach using takePicture
        await _processImageAlternative();
        return;
      }

      print('Processing image for face detection...');
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      print('Face detection result: ${faces.length} faces found');

      if (faces.isNotEmpty) {
        final face = faces.first;
        print('Face detected! Processing for login...');
        print('Face bounding box: ${face.boundingBox}');
        _detectFaceForLogin(face, image);
      } else {
        print('No face detected');
        if (mounted) {
          setState(() {
            _isFaceDetected = false;
            _progressPercentage = 0.0;
          });
        }
      }
    } catch (e) {
      print('Error processing image: $e');
      // If image stream fails, try timer-based detection
      if (_useImageStream) {
        try {
          _cameraController?.stopImageStream();
        } catch (_) {}
        _useImageStream = false;
        _startTimerBasedDetection();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  Future<void> _processImageAlternative() async {
    if (_isDialogShowing) return;
    
    try {
      // Use takePicture as alternative
      final XFile image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      print('Processing alternative image for face detection...');
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        print('Face detected! Processing for login...');

        // Check if enough time has passed since last authentication attempt
        final now = DateTime.now();
        if (_lastAuthenticationAttempt == null ||
            now.difference(_lastAuthenticationAttempt!) >
                _authenticationCooldown) {
          _lastAuthenticationAttempt = now;
          _detectFaceForLogin(face, null); // No camera image available in alternative method
        } else {
          print('Authentication cooldown active, skipping...');
        }
      } else {
        print('No face detected');
        if (mounted) {
          setState(() {
            _isFaceDetected = false;
            _progressPercentage = 0.0;
          });
        }
      }
    } catch (e) {
      print('Error processing alternative image: $e');
    }
  }

  // Update the _processImageFromFile method as well
Future<void> _processImageFromFile() async {
  if (_cameraController == null || !_cameraController!.value.isInitialized || _isDialogShowing) return; // Add _isDialogShowing check

    setState(() {
      _isProcessingImage = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      print('Picture taken, processing with InputImage.fromFilePath...');
      print('Image path: ${image.path}');
      print('Image size: ${await image.length()} bytes');

      // Use InputImage.fromFilePath which should work better
      final inputImage = InputImage.fromFilePath(image.path);
      print('InputImage created successfully');

      final List<Face> faces = await _faceDetector.processImage(inputImage);
      print('Face detection result: ${faces.length} faces found');

      if (faces.isNotEmpty) {
        final face = faces.first;
        print('Face detected! Processing for login...');
        print('Face bounding box: ${face.boundingBox}');
        print('Face landmarks: ${face.landmarks}');
        print('Face contours: ${face.contours}');

        // Check if enough time has passed since last authentication attempt
        final now = DateTime.now();
        if (_lastAuthenticationAttempt == null ||
            now.difference(_lastAuthenticationAttempt!) >
                _authenticationCooldown) {
          _lastAuthenticationAttempt = now;
          _detectFaceForLogin(face, null); // No camera image available in alternative method
        } else {
          print('Authentication cooldown active, skipping...');
        }
      } else {
        print('No face detected');
        if (mounted) {
          setState(() {
            _isFaceDetected = false;
            _progressPercentage = 0.0;
          });
        }
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final size = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = InputImageRotationValue.fromRawValue(
            _cameraController!.description.sensorOrientation,
          ) ??
          InputImageRotation.rotation0deg;

      print('Camera image format: ${image.format.group}');
      print('Camera image planes: ${image.planes.length}');
      print('Camera image size: ${image.width}x${image.height}');

      InputImageFormat inputFormat;
      if (image.format.group == ImageFormatGroup.yuv420) {
        inputFormat = InputImageFormat.yuv420;
        print('Using YUV420 format');
      } else if (image.format.group == ImageFormatGroup.nv21) {
        inputFormat = InputImageFormat.nv21;
        print('Using NV21 format');
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        inputFormat = InputImageFormat.bgra8888;
        print('Using BGRA8888 format');
      } else {
        print('Unsupported image format: ${image.format.group}');
        print('Available formats: YUV420, NV21, BGRA8888');
        return null;
      }

      final metadata = InputImageMetadata(
        size: size,
        rotation: rotation,
        format: inputFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final bytes = _cameraImageToBytes(image);
      print('Image bytes length: ${bytes.length}');
      print('Bytes per row: ${image.planes.first.bytesPerRow}');

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      print('Error creating input image: $e');
      return null;
    }
  }

  Uint8List _cameraImageToBytes(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    return bytes;
  }

  void _detectFaceForLogin(Face face, [CameraImage? cameraImage]) async {
    final box = face.boundingBox;
    final faceHeight = box.height;
    final faceWidth = box.width;

    // Simple face detection - no positioning or lighting requirements
    final isFaceDetected = faceHeight > 50 && faceWidth > 50; // Very lenient requirements

    if (mounted) {
      setState(() {
        _progressPercentage = 100.0; // Always show 100% when face is detected
        _isFaceDetected = isFaceDetected;
        // No positioning data needed
      });
    }

    // Proceed with authentication as soon as any face is detected
    if (isFaceDetected) {
      await _authenticateFace(face, cameraImage);
    }
  }

  Future<void> _authenticateFace(Face face, [CameraImage? cameraImage]) async {
    if (_isAuthenticating) return;

    // Check for lockout
    if (_isLockedOut()) {
      _showLockoutDialog();
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    try {
      // First check if there are any verified users in the database
      final hasVerifiedUsers = await FaceLoginService.hasVerifiedUsers();

      if (!hasVerifiedUsers) {
        // No verified users exist, show sign up message
        if (mounted) {
          setState(() {
            _progressPercentage = 0.0;
            _isAuthenticating = false;
          });

          // Track failed attempt
          _trackFailedAttempt();

          // Check if enough time has passed since last dialog
          final now = DateTime.now();
          if (_lastDialogShown == null ||
              now.difference(_lastDialogShown!) > _dialogCooldown) {
            _lastDialogShown = now;
            _stopCamera(); // Stop camera when showing dialog
            _showSignUpRequiredDialog();
          } else {
            print('Dialog cooldown active, skipping sign up dialog...');
          }
        }
        return;
      }

      // Try to authenticate the face using real biometric authentication
      print('Attempting real biometric face authentication...');
      final userId = await FaceLoginService.authenticateUser(face, cameraImage);
      print('Biometric authentication result: $userId');

      if (userId == "LIVENESS_FAILED") {
        // Liveness detection failed, show specific dialog
        if (mounted) {
          setState(() {
            _progressPercentage = 0.0;
            _isAuthenticating = false;
          });
          _stopCamera(); // Stop camera when showing dialog
          _showLivenessDetectionDialog();
        }
      } else if (userId != null) {
        // Check if user is rejected
        if (userId.startsWith('REJECTED_USER:')) {
          final actualUserId = userId.split(':')[1];
          print('User was rejected: $actualUserId');

          if (mounted) {
            setState(() {
              _progressPercentage = 0.0;
              _isAuthenticating = false;
            });
            _showRejectedUserDialog();
          }
        } else {
          // User is verified or pending, get user data and check verification status
          final userData = await FaceLoginService.getUserData(userId);

          if (userData != null) {
            // Store the current user ID, username, and profile picture for profile access
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('current_user_id', userId);
            await prefs.setString('current_user_name', userData['username'] ?? 'User');
            await prefs.setString('current_user_profile_picture', userData['profilePictureUrl'] ?? '');
            print('✅ Stored current user ID: $userId');
            print('✅ Stored current username: ${userData['username'] ?? 'User'}');
            print('✅ Stored current profile picture: ${userData['profilePictureUrl'] ?? 'none'}');

            // Check verification status
            final verificationStatus = userData['verificationStatus'] ?? 'pending';
            print('📊 User verification status: $verificationStatus');

            if (mounted) {
              setState(() {
                _progressPercentage = 100.0;
              });

              // Navigate based on verification status
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) {
                  if (verificationStatus == 'verified') {
                    // User is verified, navigate to main app
                    print('✅ User is verified! Navigating to main app...');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const NavigationWrapper()),
                    );
                  } else {
                    // User is pending, navigate to under verification screen
                    print('⏳ User is pending verification! Navigating to under verification screen...');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const UnderVerificationScreen()),
                    );
                  }
                }
              });
            }
          }
        }
      } else {
        // Face not recognized, show sign up message
        if (mounted) {
          setState(() {
            _progressPercentage = 0.0;
            _isAuthenticating = false;
          });
          _stopCamera(); // Add this line to stop camera
          _showSignUpRequiredDialog();
        }
      }
    } catch (e) {
      // Handle error silently
      if (mounted) {
        setState(() {
          _progressPercentage = 0.0;
          _isAuthenticating = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _showLivenessDetectionDialog() {
    setState(() {
      _isDialogShowing = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.visibility_off,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                "Liveness Detection Failed",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "We couldn't verify that you're a real person. Please try:",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text("Make sure your eyes are open and visible"),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text("Look directly at the camera"),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text("Make sure your face is visible"),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text("Try blinking naturally"),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                setState(() {
                  _isDialogShowing = false;
                });
                _resumeCamera(); // Resume camera when retrying
              },
              child: const Text(
                "Try Again",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                setState(() {
                  _isDialogShowing = false;
                });
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                );
              },
              child: const Text(
                "Sign Up Instead",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRejectedUserDialog() {
    setState(() {
      _isDialogShowing = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.block,
                color: Colors.red,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                "Account Rejected",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your account has been rejected and cannot access the system.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                "Please contact support if you believe this is an error.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                setState(() {
                  _isDialogShowing = false;
                });
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
              child: const Text(
                "OK",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSignUpRequiredDialog() {
    setState(() {
      _isDialogShowing = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Sign Up Required",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: const Text(
            "You must sign up first to use face login. Please create an account to continue.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                setState(() {
                  _isDialogShowing = false;
                });
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                );
              },
              child: const Text(
                "Sign Up",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                setState(() {
                  _isDialogShowing = false;
                });
                _resumeCamera(); // Resume camera when cancelled
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLockoutDialog() {
    _stopCamera(); // Stop camera during lockout
    LockoutService.setLockout(); // Set global lockout
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Too Many Attempts",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: const Text(
            "You have tried logging in too many times. Please try again in 5 minutes.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
              child: const Text(
                "OK",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Image.asset('assets/logo.png', height: 50),
              const SizedBox(height: 20),
              const Text(
                "FACE LOGIN",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Camera container with elliptical shape (matching 3 facial verification)
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
                          _isAuthenticating ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    // Camera preview container with elliptical shape
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
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
                            ? Stack(
                                children: [
                                  // Camera preview - properly fitted within ellipse
                                  Positioned.fill(
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        width: _cameraController!.value.previewSize?.height ?? 400,
                                        height: _cameraController!.value.previewSize?.width ?? 300,
                                        child: CameraPreview(_cameraController!),
                                      ),
                                    ),
                                  ),
                                  // Face detection indicator
                                  if (_isFaceDetected && !_isAuthenticating)
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.elliptical(120, 170),
                                          topRight: Radius.elliptical(120, 170),
                                          bottomLeft: Radius.elliptical(120, 170),
                                          bottomRight: Radius.elliptical(120, 170),
                                        ),
                                        border: Border.all(
                                          color: Colors.green,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  // Camera ready indicator
                                  if (!_isFaceDetected && !_isAuthenticating)
                                    Positioned(
                                      bottom: 20,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Position your face in the oval',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.elliptical(120, 170),
                                    topRight: Radius.elliptical(120, 170),
                                    bottomLeft: Radius.elliptical(120, 170),
                                    bottomRight: Radius.elliptical(120, 170),
                                  ),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Initializing Camera...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isAuthenticating
                    ? "AUTHENTICATING..."
                    : "LOGIN USING YOUR FACE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _isAuthenticating ? Colors.green : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              // Sign up button
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  );
                },
                child: const Text(
                  "Don't have an account? Sign up",
                  style: TextStyle(
                    color: Colors.red,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

