// facemovement_screen.dart
import 'dart:typed_data';
import 'package:capstone2/screens/fill_information_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceHeadMovementScreen extends StatefulWidget {
  const FaceHeadMovementScreen({super.key});

  @override
  State<FaceHeadMovementScreen> createState() => _FaceHeadMovementScreenState();
}

class _FaceHeadMovementScreenState extends State<FaceHeadMovementScreen> {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  late FaceDetector _faceDetector;

  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  bool _navigated = false;

  double? _initialX;
  bool _movedLeft = false;
  bool _movedRight = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableContours: false,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    final frontCamera = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    _cameraController = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
    await _cameraController!.initialize();
    await _cameraController!.startImageStream(_processCameraImage);
    setState(() => _isCameraInitialized = true);
  }

  // same NV21 converter as above
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final Plane planeY = image.planes[0];
    if (planeY.bytesPerRow == width) {
      nv21.setRange(0, ySize, planeY.bytes);
    } else {
      int dst = 0;
      for (int row = 0; row < height; row++) {
        final int srcOffset = row * planeY.bytesPerRow;
        nv21.setRange(dst, dst + width, planeY.bytes, srcOffset);
        dst += width;
      }
    }

    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];
    final int pixelStrideU = planeU.bytesPerPixel ?? 1;
    final int pixelStrideV = planeV.bytesPerPixel ?? 1;
    final int rowStrideU = planeU.bytesPerRow;
    final int rowStrideV = planeV.bytesPerRow;

    int uvDst = ySize;
    for (int row = 0; row < height ~/ 2; row++) {
      int uRowStart = row * rowStrideU;
      int vRowStart = row * rowStrideV;
      int colU = 0;
      for (int col = 0; col < width ~/ 2; col++) {
        final int vIndex = vRowStart + col * pixelStrideV;
        final int uIndex = uRowStart + colU;
        final int v = planeV.bytes[vIndex];
        final int u = planeU.bytes[uIndex];
        nv21[uvDst++] = v;
        nv21[uvDst++] = u;
        colU += pixelStrideU;
      }
    }

    return nv21;
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation, CameraLensDirection lensDirection) {
    InputImageRotation rotation = InputImageRotation.rotation0deg;
    switch (sensorOrientation) {
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
    }
    if (lensDirection == CameraLensDirection.front) {
      if (rotation == InputImageRotation.rotation90deg) rotation = InputImageRotation.rotation270deg;
      else if (rotation == InputImageRotation.rotation270deg) rotation = InputImageRotation.rotation90deg;
    }
    return rotation;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage) return;
    _isProcessingImage = true;

    try {
      final camera = _cameraController!.description;
      final Uint8List bytes = defaultTargetPlatform == TargetPlatform.android ? _yuv420ToNv21(image) : image.planes[0].bytes;

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = _rotationFromSensor(camera.sensorOrientation, camera.lensDirection);

      final InputImageFormat format = defaultTargetPlatform == TargetPlatform.android
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: InputImageRotationValue.fromRawValue(rotation.index) ?? rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final headX = face.headEulerAngleY ?? 0; // negative = left, positive = right

        _initialX ??= headX;

        // Detect LEFT
        if (!_movedLeft && headX > _initialX! + 15) {
          setState(() => _movedLeft = true);
          debugPrint("✅ Head moved LEFT");
        }

        // Detect RIGHT (only after left)
        if (_movedLeft && !_movedRight && headX < _initialX! - 15) {
          setState(() {
            _movedRight = true;
            _success = true;
          });
          debugPrint("✅ Head moved RIGHT");

          if (!_navigated) {
            _navigated = true;
            await _cameraController?.stopImageStream();
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FillInformationScreen()));
              }
            });
          }
        }
      } else {
        if (kDebugMode) debugPrint("⚠️ No faces detected");
      }
    } catch (e, st) {
      debugPrint("Head movement error: $e\n$st");
    } finally {
      _isProcessingImage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /* your UI (same as before) */
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
                const Text("FACE VERIFICATION",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Container(
                  width: 270,
                  height: 370,
                  decoration: BoxDecoration(
                    border: Border.all(color: _success ? Colors.green : Colors.red, width: 4),
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
                  !_movedLeft
                      ? "MOVE YOUR HEAD LEFT"
                      : !_movedRight
                      ? "MOVE YOUR HEAD RIGHT"
                      : "SUCCESS ✅",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
