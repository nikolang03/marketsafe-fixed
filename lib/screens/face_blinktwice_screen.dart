import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_movecloser_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // required for eye probabilities
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _cameraController?.dispose();
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
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      await controller.startImageStream(_processCameraImage);

      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Camera init failed: $e\n$st');
      }
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  // Concatenate Y, U, V planes for ML Kit with plane metadata
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
    if (_isProcessingImage || !_isCameraInitialized || _cameraController == null) return;
    _isProcessingImage = true;

    try {
      final camera = _cameraController!.description;

      final bytes = _bytesFromPlanes(image);
      final size = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = _rotationFromSensor(camera.sensorOrientation);

      final planeData = image.planes
          .map((Plane plane) => InputImagePlaneMetadata(bytesPerRow: plane.bytesPerRow))
          .toList();

      final metadata = InputImageMetadata(
        size: size,
        rotation: rotation,
        format: InputImageFormat.yuv420,
        planeData: planeData,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

      final faces = await _faceDetector.processImage(inputImage);
      if (kDebugMode) debugPrint("Faces detected: ${faces.length}");

      if (faces.isNotEmpty) {
        _detectBlink(faces.first);
      }
    } catch (e, st) {
      debugPrint('Error processing camera image: $e\n$st');
    } finally {
      _isProcessingImage = false;
    }
  }

  void _detectBlink(Face face) {
    final leftProb = face.leftEyeOpenProbability;
    final rightProb = face.rightEyeOpenProbability;

    if (leftProb == null || rightProb == null) return;

    const closedThreshold = 0.3;
    const openThreshold = 0.6;

    final eyesClosed = (leftProb < closedThreshold && rightProb < closedThreshold);

    if (eyesClosed && !isBlinking) {
      isBlinking = true;
    } else if (!eyesClosed && isBlinking && leftProb > openThreshold && rightProb > openThreshold) {
      isBlinking = false;
      _handleBlink();
    }
  }

  void _handleBlink() {
    final now = DateTime.now();
    if (lastBlinkTime != null && now.difference(lastBlinkTime!).inMilliseconds < 2000) {
      if (!mounted) return;
      setState(() => isAccomplished = true);
      try {
        _cameraController?.stopImageStream();
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FaceMoveCloserScreen()),
      );
    }
    lastBlinkTime = now;
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
                "FACE VERIFICATION",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                width: 270,
                height: 370,
                decoration: BoxDecoration(
                  border: Border.all(color: isAccomplished ? Colors.green : Colors.red, width: 5),
                  borderRadius: const BorderRadius.all(Radius.elliptical(270, 370)),
                ),
                child: ClipOval(
                  child: _isCameraInitialized && _cameraController != null
                      ? CameraPreview(_cameraController!)
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                isAccomplished ? "SUCCESS ✅" : "BLINK TWICE",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}