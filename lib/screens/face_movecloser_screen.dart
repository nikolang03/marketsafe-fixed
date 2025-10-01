import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_headmovement_screen.dart';

class FaceMoveCloserScreen extends StatefulWidget {
  const FaceMoveCloserScreen({super.key});

  @override
  State<FaceMoveCloserScreen> createState() => _FaceMoveCloserScreenState();
}

class _FaceMoveCloserScreenState extends State<FaceMoveCloserScreen> {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  late FaceDetector _faceDetector;
  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  bool _isFaceCloseEnough = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(
      _cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
      ),
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (!mounted) return;
    setState(() => _isCameraInitialized = true);

    // ✅ Start image stream *after* preview is ready
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        _cameraController!.startImageStream(_processCameraImage);
      }
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage) return;
    _isProcessingImage = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
      Size(image.width.toDouble(), image.height.toDouble());

      final camera = _cameraController!.description;
      final imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage =
      InputImage.fromBytes(bytes: bytes, metadata: inputImageData);

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final box = faces.first.boundingBox;

        if (box.height > 350 && box.width > 350) {
          setState(() => _isFaceCloseEnough = true);

          await _cameraController?.stopImageStream();
          await Future.delayed(const Duration(milliseconds: 500)); // 👀 short delay to show green outline

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FaceHeadMovementScreen()),
            );
          }
        } else {
          setState(() => _isFaceCloseEnough = false);
        }
      } else {
        setState(() => _isFaceCloseEnough = false);
      }
    } catch (e) {
      debugPrint('Face detection error: $e');
    } finally {
      _isProcessingImage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 0),
                Image.asset('assets/logo.png', height: 50),
                const SizedBox(height: 20),
                const Text(
                  "FACE VERIFICATION",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 270,
                  height: 370,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isFaceCloseEnough ? Colors.green : Colors.red, // ✅ dynamic border
                      width: 4,
                    ),
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(270, 370),
                    ),
                  ),
                  child: ClipOval(
                    child: _isCameraInitialized
                        ? CameraPreview(_cameraController!)
                        : const CircularProgressIndicator(),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  _isFaceCloseEnough
                      ? "FACE DETECTED ✅"
                      : "MOVE CLOSER TO THE FRAME",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _isFaceCloseEnough ? Colors.green : Colors.black, // ✅ text also turns green
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
