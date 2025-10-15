import 'package:flutter/material.dart';

class ResponsiveUtils {
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double screenHeightPercentage(BuildContext context, double percentage) {
    return screenHeight(context) * percentage / 100;
  }

  static double screenWidthPercentage(BuildContext context, double percentage) {
    return screenWidth(context) * percentage / 100;
  }

  // Responsive font sizes
  static double fontSize(BuildContext context, double baseSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    // Base width for scaling (360dp - typical Android phone)
    double baseWidth = 360.0;
    return (screenWidth / baseWidth) * baseSize;
  }

  // Responsive spacing
  static double spacing(BuildContext context, double baseSpacing) {
    double screenHeight = MediaQuery.of(context).size.height;
    // Base height for scaling (640dp - typical Android phone)
    double baseHeight = 640.0;
    return (screenHeight / baseHeight) * baseSpacing;
  }

  // Responsive padding
  static EdgeInsets responsivePadding(BuildContext context, {
    double horizontal = 24.0,
    double vertical = 24.0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: screenWidthPercentage(context, horizontal / screenWidth(context) * 100),
      vertical: screenHeightPercentage(context, vertical / screenHeight(context) * 100),
    );
  }

  // Get safe responsive padding that accounts for screen notches
  static EdgeInsets safePadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      left: mediaQuery.padding.left + 16,
      right: mediaQuery.padding.right + 16,
      top: mediaQuery.padding.top + 16,
      bottom: mediaQuery.padding.bottom + 16,
    );
  }

  // Responsive image size
  static double imageSize(BuildContext context, double baseSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleFactor = screenWidth / 360.0; // Base width
    return baseSize * scaleFactor.clamp(0.8, 1.5); // Limit scaling between 80% and 150%
  }

  // Responsive button size
  static Size buttonSize(BuildContext context, {double widthFactor = 0.7, double height = 50}) {
    return Size(
      screenWidth(context) * widthFactor,
      spacing(context, height),
    );
  }

  // Check if device is tablet (width > 600dp)
  static bool isTablet(BuildContext context) {
    return screenWidth(context) > 600;
  }

  // Check if device is small (width < 360dp)
  static bool isSmallDevice(BuildContext context) {
    return screenWidth(context) < 360;
  }

  // Get responsive camera preview size for face verification
  static Size cameraPreviewSize(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double size = screenWidth * 0.75; // 75% of screen width
    size = size.clamp(250.0, 350.0); // Minimum 250, maximum 350
    
    return Size(size, size * 1.4); // Aspect ratio for oval shape
  }

  // Responsive text scale factor
  static double textScaleFactor(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 0.9;
    if (screenWidth > 600) return 1.1;
    return 1.0;
  }
}

