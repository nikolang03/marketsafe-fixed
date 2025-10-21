import 'package:flutter/material.dart';

class CleanFaceGuide extends StatefulWidget {
  final Map<String, dynamic>? positionData;
  final bool isVisible;
  final double screenWidth;
  final double screenHeight;
  final bool isAuthenticating;

  const CleanFaceGuide({
    Key? key,
    this.positionData,
    required this.isVisible,
    required this.screenWidth,
    required this.screenHeight,
    this.isAuthenticating = false,
  }) : super(key: key);

  @override
  State<CleanFaceGuide> createState() => _CleanFaceGuideState();
}

class _CleanFaceGuideState extends State<CleanFaceGuide>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    if (widget.isAuthenticating) {
      _scanController.repeat();
    }
  }

  @override
  void didUpdateWidget(CleanFaceGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAuthenticating && !oldWidget.isAuthenticating) {
      _scanController.repeat();
    } else if (!widget.isAuthenticating && oldWidget.isAuthenticating) {
      _scanController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        // Clean elliptical frame
        _buildEllipticalFrame(),
        
        // Face detection overlay
        if (widget.positionData != null)
          _buildFaceDetectionOverlay(),
        
        // Scanning indicator
        if (widget.isAuthenticating)
          _buildScanningIndicator(),
        
        // Status indicator
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildEllipticalFrame() {
    return Center(
      child: Container(
        width: 280,
        height: 380,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(140),
          border: Border.all(
            color: _getFrameColor(),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: _getFrameColor().withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(140),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceDetectionOverlay() {
    final positionData = widget.positionData!;
    final faceCenter = positionData['faceCenter'] as Map<String, dynamic>;
    final isGoodPosition = positionData['score'] >= 75;
    
    // Calculate position relative to the elliptical frame (280x380)
    final frameCenterX = 140; // 280/2
    final frameCenterY = 190; // 380/2
    final relativeX = (faceCenter['x'] as double) - frameCenterX;
    final relativeY = (faceCenter['y'] as double) - frameCenterY;
    
    return Positioned(
      left: frameCenterX + relativeX - 35,
      top: frameCenterY + relativeY - 35,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isGoodPosition ? Colors.green : Colors.orange,
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Center(
      child: AnimatedBuilder(
        animation: _scanAnimation,
        builder: (context, child) {
          return Container(
            width: 180,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(90),
              border: Border.all(
                color: Colors.green.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                // Rotating scanning line
                Center(
                  child: Transform.rotate(
                    angle: _scanAnimation.value * 2 * 3.14159,
                    child: Container(
                      width: 2,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                // Center dot
                Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (widget.positionData == null) return const SizedBox.shrink();
    
    final positionData = widget.positionData!;
    final status = positionData['status'] as String;
    final score = positionData['score'] as int;
    final lighting = positionData['lighting'] as Map<String, dynamic>?;
    
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor(status),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status indicator
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$status ($score%)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            // Lighting indicator
            if (lighting != null) ...[
              const SizedBox(width: 12),
              Icon(
                _getLightingIcon(lighting['lightingStatus']),
                color: _getLightingColor(lighting['lightingStatus']),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${lighting['lightingStatus']}',
                style: TextStyle(
                  color: _getLightingColor(lighting['lightingStatus']),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getFrameColor() {
    if (widget.positionData == null) return Colors.grey;
    final score = widget.positionData!['score'] as int;
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PERFECT':
        return Colors.green;
      case 'GOOD':
        return Colors.lightGreen;
      case 'FAIR':
        return Colors.orange;
      case 'POOR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getLightingIcon(String status) {
    switch (status) {
      case 'EXCELLENT':
        return Icons.wb_sunny;
      case 'GOOD':
        return Icons.wb_sunny_outlined;
      case 'FAIR':
        return Icons.wb_cloudy;
      case 'POOR':
        return Icons.wb_cloudy_outlined;
      default:
        return Icons.lightbulb_outline;
    }
  }

  Color _getLightingColor(String status) {
    switch (status) {
      case 'EXCELLENT':
        return Colors.yellow;
      case 'GOOD':
        return Colors.lightGreen;
      case 'FAIR':
        return Colors.orange;
      case 'POOR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
