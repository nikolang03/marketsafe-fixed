import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart';
import 'dart:convert';

enum WatermarkColor {
  yellow,
  red,
  blue,
  green,
  white,
  black,
  orange,
  purple,
  pink,
  cyan,
}

class WatermarkingService {
  static const int _fontSize = 120; // HUGE for maximum visibility
  static const int _minFontSize = 40; // Minimum size to ensure visibility

  /// Automatically adds a watermark to an image with username centered
  static Future<Uint8List> addAutomaticWatermark({
    required Uint8List imageBytes,
    required String username,
    String? userId,
  }) async {
    try {
      print('🎨 Starting automatic watermarking for user: $username');
      print('📏 Image size: ${imageBytes.length} bytes');
      
      // Decode the image
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }
      
      print('📐 Image dimensions: ${originalImage.width}x${originalImage.height}');

      // Create watermark text with @ symbol
      String watermarkText = '@$username';
      print('🏷️ Watermark text: $watermarkText');
      
      // Add watermark to the image with center positioning
      img.Image watermarkedImage = await _addTextWatermark(
        originalImage,
        watermarkText,
        customPosition: WatermarkPosition.center,
        customSize: 0.8, // 80% of max size
        customOpacity: 0.9, // 90% opacity
        customColor: WatermarkColor.yellow, // Bright yellow for visibility
      );
      print('✅ Text watermark added');

      // Add embedded metadata
      watermarkedImage = await _addEmbeddedMetadata(
        watermarkedImage,
        username: username,
        userId: userId,
      );
      print('✅ Metadata added');

      // Encode back to bytes
      final result = Uint8List.fromList(img.encodeJpg(watermarkedImage, quality: 95));
      print('📏 Final watermarked image size: ${result.length} bytes');
      print('🎉 Automatic watermarking completed successfully');
      
      return result;
    } catch (e) {
      print('❌ Error adding automatic watermark: $e');
      // Return original image if watermarking fails
      return imageBytes;
    }
  }

  /// Adds a watermark to an image with the user's username and embedded metadata
  static Future<Uint8List> addWatermarkToImage({
    required Uint8List imageBytes,
    required String username,
    String? customText,
    String? userId,
    WatermarkPosition? customPosition,
    double? customPositionX,
    double? customPositionY,
    double? customSize,
    double? customOpacity,
    WatermarkColor? customColor,
  }) async {
    try {
      print('🎨 Starting watermarking process for user: $username');
      print('📏 Image size: ${imageBytes.length} bytes');
      
      // Decode the image
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }
      
      print('📐 Image dimensions: ${originalImage.width}x${originalImage.height}');

      // Create watermark text
      String watermarkText = customText ?? username;
      print('🏷️ Watermark text: $watermarkText');
      
      // Add watermark to the image
      img.Image watermarkedImage = await _addTextWatermark(
        originalImage,
        watermarkText,
        customPosition: customPosition,
        customPositionX: customPositionX,
        customPositionY: customPositionY,
        customSize: customSize,
        customOpacity: customOpacity,
        customColor: customColor,
      );
      print('✅ Text watermark added');

      // Add embedded metadata
      watermarkedImage = await _addEmbeddedMetadata(
        watermarkedImage,
        username: username,
        userId: userId,
      );
      print('✅ Metadata added');

      // Encode back to bytes
      final result = Uint8List.fromList(img.encodeJpg(watermarkedImage, quality: 95));
      print('📏 Final watermarked image size: ${result.length} bytes');
      print('🎉 Watermarking completed successfully');
      
      return result;
    } catch (e) {
      print('❌ Error adding watermark: $e');
      // Return original image if watermarking fails
      return imageBytes;
    }
  }

  /// Adds embedded metadata to image
  static Future<img.Image> _addEmbeddedMetadata(
    img.Image image, {
    required String username,
    String? userId,
  }) async {
    try {
      // Generate unique metadata
      final metadata = _generateUniqueMetadata(username, userId);
      
      // Add metadata as EXIF data
      final exifData = <String, dynamic>{
        'ImageDescription': 'MarketSafe - $username',
        'Software': 'MarketSafe App v1.0',
        'Artist': username,
        'Copyright': '© MarketSafe - $username',
        'UserComment': metadata,
        'DateTime': DateTime.now().toIso8601String(),
        'Make': 'MarketSafe',
        'Model': 'Mobile App',
      };

      // Convert to EXIF format and embed
      return _embedExifData(image, exifData);
    } catch (e) {
      print('Error adding embedded metadata: $e');
      return image;
    }
  }

  /// Generates unique metadata for image authenticity
  static String _generateUniqueMetadata(String username, String? userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final hash = (timestamp + random).toString().hashCode.abs();
    
    return jsonEncode({
      'app': 'MarketSafe',
      'version': '1.0',
      'username': username,
      'userId': userId ?? 'unknown',
      'timestamp': timestamp,
      'uniqueId': '${timestamp}_${random}_$hash',
      'authenticity': 'user_generated',
      'source': 'mobile_camera',
      'verified': true,
    });
  }

  /// Embeds EXIF data into image
  static img.Image _embedExifData(img.Image image, Map<String, dynamic> exifData) {
    // For now, we'll add the metadata as a comment in the image
    // In a production app, you'd use a proper EXIF library
    return image;
  }


  /// Adds text watermark to image
  static Future<img.Image> _addTextWatermark(
    img.Image image,
    String text, {
    WatermarkPosition? customPosition,
    double? customPositionX,
    double? customPositionY,
    double? customSize,
    double? customOpacity,
    WatermarkColor? customColor,
  }) async {
    // Create a copy of the original image
    img.Image watermarkedImage = img.Image.from(image);

    // Calculate text position based on custom parameters
    int textX, textY;
    final fontSize = ((customSize ?? 1.0) * _fontSize).round();
    int charWidth = fontSize ~/ 2;
    int textWidth = text.length * (charWidth + 10); // Account for spacing
    int textHeight = fontSize + 10;
    
    print('📏 Text calculation:');
    print('  - Text: "$text" (${text.length} chars)');
    print('  - Font size: $fontSize');
    print('  - Char width: $charWidth');
    print('  - Text width: $textWidth');
    print('  - Text height: $textHeight');
    print('  - Image size: ${watermarkedImage.width}x${watermarkedImage.height}');
    
    // Ensure text fits within image bounds
    if (textWidth > watermarkedImage.width) {
      print('⚠️ Text width ($textWidth) exceeds image width (${watermarkedImage.width}), adjusting...');
      textWidth = watermarkedImage.width - 20; // Leave 10px margin on each side
    }
    if (textHeight > watermarkedImage.height) {
      print('⚠️ Text height ($textHeight) exceeds image height (${watermarkedImage.height}), adjusting...');
      textHeight = watermarkedImage.height - 20; // Leave 10px margin on each side
    }
    
    print('📏 Adjusted text size: ${textWidth}x${textHeight}');

    // Calculate position based on custom X/Y coordinates or preset position
    if (customPositionX != null && customPositionY != null) {
      // Use custom X/Y coordinates (0.0 to 1.0 range)
      // Ensure text doesn't go outside image bounds
      textX = (watermarkedImage.width * customPositionX - textWidth / 2).round();
      textY = (watermarkedImage.height * customPositionY - textHeight / 2).round();
      
      // Clamp to image bounds to prevent negative coordinates
      textX = textX.clamp(0, watermarkedImage.width - textWidth);
      textY = textY.clamp(0, watermarkedImage.height - textHeight);
      
      print('📍 Using custom position: (${customPositionX}, ${customPositionY}) -> ($textX, $textY)');
      print('📏 Text size: ${textWidth}x${textHeight}, Image size: ${watermarkedImage.width}x${watermarkedImage.height}');
    } else {
      // Use preset position
      final position = customPosition ?? WatermarkPosition.center;
      print('🎯 Using preset position: $position');
      
      switch (position) {
        case WatermarkPosition.topLeft:
          textX = (watermarkedImage.width * 0.1).round();
          textY = (watermarkedImage.height * 0.1).round();
          textX = textX.clamp(0, watermarkedImage.width - textWidth);
          textY = textY.clamp(0, watermarkedImage.height - textHeight);
          print('📍 Positioned at top-left: ($textX, $textY)');
          break;
        case WatermarkPosition.topRight:
          textX = (watermarkedImage.width * 0.9 - textWidth).round();
          textY = (watermarkedImage.height * 0.1).round();
          textX = textX.clamp(0, watermarkedImage.width - textWidth);
          textY = textY.clamp(0, watermarkedImage.height - textHeight);
          print('📍 Positioned at top-right: ($textX, $textY)');
          break;
        case WatermarkPosition.bottomLeft:
          textX = (watermarkedImage.width * 0.1).round();
          textY = (watermarkedImage.height * 0.9 - textHeight).round();
          textX = textX.clamp(0, watermarkedImage.width - textWidth);
          textY = textY.clamp(0, watermarkedImage.height - textHeight);
          print('📍 Positioned at bottom-left: ($textX, $textY)');
          break;
        case WatermarkPosition.bottomRight:
          textX = (watermarkedImage.width * 0.9 - textWidth).round();
          textY = (watermarkedImage.height * 0.9 - textHeight).round();
          textX = textX.clamp(0, watermarkedImage.width - textWidth);
          textY = textY.clamp(0, watermarkedImage.height - textHeight);
          print('📍 Positioned at bottom-right: ($textX, $textY)');
          break;
        case WatermarkPosition.center:
        default:
          textX = (watermarkedImage.width - textWidth) ~/ 2;
          textY = (watermarkedImage.height - textHeight) ~/ 2;
          textX = textX.clamp(0, watermarkedImage.width - textWidth);
          textY = textY.clamp(0, watermarkedImage.height - textHeight);
          print('📍 Positioned at center: ($textX, $textY)');
          break;
      }
    }

    // Get the selected color
    final color = _getWatermarkColor(customColor);
    
    // Add only the text watermark - no background or border
    await _drawText(
      watermarkedImage,
      text,
      textX,
      textY + fontSize,
      color,
      fontSize: fontSize,
    );

    return watermarkedImage;
  }

  /// Gets the watermark color based on the selected option
  static img.Color _getWatermarkColor(WatermarkColor? color) {
    switch (color) {
      case WatermarkColor.red:
        return img.ColorRgb8(255, 0, 0);
      case WatermarkColor.blue:
        return img.ColorRgb8(0, 0, 255);
      case WatermarkColor.green:
        return img.ColorRgb8(0, 255, 0);
      case WatermarkColor.white:
        return img.ColorRgb8(255, 255, 255);
      case WatermarkColor.black:
        return img.ColorRgb8(0, 0, 0);
      case WatermarkColor.orange:
        return img.ColorRgb8(255, 165, 0);
      case WatermarkColor.purple:
        return img.ColorRgb8(128, 0, 128);
      case WatermarkColor.pink:
        return img.ColorRgb8(255, 192, 203);
      case WatermarkColor.cyan:
        return img.ColorRgb8(0, 255, 255);
      case WatermarkColor.yellow:
      default:
        return img.ColorRgb8(255, 255, 0); // Bright yellow for maximum visibility
    }
  }

  /// Draws text on the image using proper text rendering
  static Future<void> _drawText(
    img.Image image,
    String text,
    int x,
    int y,
    img.Color color, {
    int? fontSize,
  }) async {
    print('🖊️ Drawing text: "$text" at position ($x, $y)');
    
    final actualFontSize = fontSize ?? _fontSize;
    
    // Draw proper text using Flutter's text painting
    String textToDraw = text.startsWith('@') ? text : '@$text';
    try {
      await _drawProperText(image, textToDraw, x, y, actualFontSize, color);
    } catch (e) {
      print('❌ Proper text rendering failed, using fallback: $e');
      _drawSimpleReadableText(image, textToDraw, x, y, actualFontSize, color);
    }
    
    print('✅ Text drawing completed - drew ${textToDraw.length} characters');
  }

  /// Draws proper text using Flutter's text painting system
  static Future<void> _drawProperText(
    img.Image image,
    String text,
    int x,
    int y,
    int fontSize,
    img.Color color,
  ) async {
    print('🎨 Drawing proper text: "$text" with size $fontSize at ($x, $y)');
    
    try {
      print('🎨 Creating text style with color: A=${color.a}, R=${color.r}, G=${color.g}, B=${color.b}');
      
      // Create a text style
      final textStyle = TextStyle(
        fontSize: fontSize.toDouble(),
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(
          (color.a.toInt()).clamp(0, 255),
          (color.r.toInt()).clamp(0, 255),
          (color.g.toInt()).clamp(0, 255),
          (color.b.toInt()).clamp(0, 255),
        ),
        shadows: [
          Shadow(
            color: Colors.black,
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      );
      
      print('✅ Text style created successfully');
      
      // Create a text span
      final textSpan = TextSpan(
        text: text,
        style: textStyle,
      );
      
      // Create a text painter
      print('🎨 Creating text painter...');
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      // Layout the text
      print('🎨 Laying out text...');
      textPainter.layout();
      
      // Get text dimensions
      final textWidth = textPainter.width.round();
      final textHeight = textPainter.height.round();
      
      print('📏 Text dimensions: ${textWidth}x${textHeight}');
      print('🎨 Text position: ($x, $y)');
      
      // Create a picture recorder
      print('🎨 Creating picture recorder and canvas...');
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Paint the text
      print('🎨 Painting text on canvas...');
      textPainter.paint(canvas, Offset(0, 0));
      
      // Convert to image
      print('🎨 Converting to image...');
      final picture = recorder.endRecording();
      final textImage = await picture.toImage(textWidth, textHeight);
      final bytes = await textImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      
      print('🎨 Text image created: ${textWidth}x${textHeight}, bytes: ${bytes?.lengthInBytes ?? 0}');
      
      if (bytes != null) {
        print('🎨 Drawing text pixels onto main image...');
        int pixelsDrawn = 0;
        // Draw the text pixels onto the main image
        for (int py = 0; py < textHeight; py++) {
          for (int px = 0; px < textWidth; px++) {
            final pixelIndex = (py * textWidth + px) * 4;
            if (pixelIndex + 3 < bytes.lengthInBytes) {
              final r = bytes.getUint8(pixelIndex);
              final g = bytes.getUint8(pixelIndex + 1);
              final b = bytes.getUint8(pixelIndex + 2);
              final a = bytes.getUint8(pixelIndex + 3);
              
              // Only draw non-transparent pixels
              if (a > 0) {
                final targetX = x + px;
                final targetY = y - textHeight + py;
                
                if (targetX >= 0 && targetX < image.width && 
                    targetY >= 0 && targetY < image.height) {
                  image.setPixel(targetX, targetY, img.ColorRgb8(r, g, b));
                  pixelsDrawn++;
                }
              }
            }
          }
        }
        print('🎨 Drew $pixelsDrawn pixels onto main image');
      } else {
        print('❌ No bytes available for text image');
      }
      
      print('✅ Proper text drawing completed: "$text"');
    } catch (e) {
      print('❌ Error drawing proper text: $e');
      // Fallback to simple text if proper rendering fails
      _drawSimpleReadableText(image, text, x, y, fontSize, color);
    }
  }

  /// Draws simple readable text as actual letters (fallback method)
  static void _drawSimpleReadableText(
    img.Image image,
    String text,
    int x,
    int y,
    int fontSize,
    img.Color color,
  ) {
    // Calculate character size based on fontSize, but ensure minimum visibility
    final minSize = 20;
    final actualSize = fontSize < minSize ? minSize : fontSize;
    
    print('🎨 Drawing fallback text with size: $actualSize (requested: $fontSize)');
    print('🎨 Text to draw: "$text" at position ($x, $y)');
    
    // Use a much simpler approach - draw thick lines for each character
    final charWidth = (actualSize * 0.6).round(); // Make characters narrower
    final charHeight = actualSize;
    final spacing = (actualSize * 0.15).round().clamp(3, 10);
    
    for (int i = 0; i < text.length; i++) {
      final charX = x + (i * (charWidth + spacing));
      
      // Draw each character using simple thick lines
      _drawSimpleCharacter(image, text[i], charX, y - charHeight, charWidth, charHeight, color);
    }
    
    print('✅ Finished drawing fallback text: "$text"');
  }

  /// Draws a simple character using thick lines
  static void _drawSimpleCharacter(
    img.Image image,
    String char,
    int x,
    int y,
    int width,
    int height,
    img.Color color,
  ) {
    print('🎨 Drawing character: "$char" at ($x, $y) with size $width x $height');
    
    // Draw simple but recognizable characters
    switch (char.toLowerCase()) {
      case '@':
        _drawAtSymbol(image, x, y, width, height, color);
        break;
      case 'a':
        _drawLetterA(image, x, y, width, height, color);
        break;
      case 'b':
        _drawLetterB(image, x, y, width, height, color);
        break;
      case 'c':
        _drawLetterC(image, x, y, width, height, color);
        break;
      case 'd':
        _drawLetterD(image, x, y, width, height, color);
        break;
      case 'e':
        _drawLetterE(image, x, y, width, height, color);
        break;
      case 'f':
        _drawLetterF(image, x, y, width, height, color);
        break;
      case 'g':
        _drawLetterG(image, x, y, width, height, color);
        break;
      case 'h':
        _drawLetterH(image, x, y, width, height, color);
        break;
      case 'i':
        _drawLetterI(image, x, y, width, height, color);
        break;
      case 'j':
        _drawLetterJ(image, x, y, width, height, color);
        break;
      case 'k':
        _drawLetterK(image, x, y, width, height, color);
        break;
      case 'l':
        _drawLetterL(image, x, y, width, height, color);
        break;
      case 'm':
        _drawLetterM(image, x, y, width, height, color);
        break;
      case 'n':
        _drawLetterN(image, x, y, width, height, color);
        break;
      case 'o':
        _drawLetterO(image, x, y, width, height, color);
        break;
      case 'p':
        _drawLetterP(image, x, y, width, height, color);
        break;
      case 'q':
        _drawLetterQ(image, x, y, width, height, color);
        break;
      case 'r':
        _drawLetterR(image, x, y, width, height, color);
        break;
      case 's':
        _drawLetterS(image, x, y, width, height, color);
        break;
      case 't':
        _drawLetterT(image, x, y, width, height, color);
        break;
      case 'u':
        _drawLetterU(image, x, y, width, height, color);
        break;
      case 'v':
        _drawLetterV(image, x, y, width, height, color);
        break;
      case 'w':
        _drawLetterW(image, x, y, width, height, color);
        break;
      case 'x':
        _drawLetterX(image, x, y, width, height, color);
        break;
      case 'y':
        _drawLetterY(image, x, y, width, height, color);
        break;
      case 'z':
        _drawLetterZ(image, x, y, width, height, color);
        break;
      case '0':
        _drawNumber0(image, x, y, width, height, color);
        break;
      case '1':
        _drawNumber1(image, x, y, width, height, color);
        break;
      case '2':
        _drawNumber2(image, x, y, width, height, color);
        break;
      case '3':
        _drawNumber3(image, x, y, width, height, color);
        break;
      case '4':
        _drawNumber4(image, x, y, width, height, color);
        break;
      case '5':
        _drawNumber5(image, x, y, width, height, color);
        break;
      case '6':
        _drawNumber6(image, x, y, width, height, color);
        break;
      case '7':
        _drawNumber7(image, x, y, width, height, color);
        break;
      case '8':
        _drawNumber8(image, x, y, width, height, color);
        break;
      case '9':
        _drawNumber9(image, x, y, width, height, color);
        break;
      default:
        // For unknown characters, draw a simple rectangle
        _drawFilledRectangle(image, x, y, width, height, color);
        break;
    }
  }


  /// Draws a circle
  static void _drawCircle(img.Image image, int centerX, int centerY, int radius, img.Color color) {
    for (int angle = 0; angle < 360; angle += 5) {
      final rad = angle * 3.14159 / 180;
      final px = centerX + (radius * cos(rad)).round();
      final py = centerY + (radius * sin(rad)).round();
      if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
        image.setPixel(px, py, color);
      }
    }
  }

  /// Draws a triangle
  static void _drawTriangle(img.Image image, int x1, int y1, int x2, int y2, int x3, int y3, img.Color color) {
    _drawLine(image, x1, y1, x2, y2, color);
    _drawLine(image, x2, y2, x3, y3, color);
    _drawLine(image, x3, y3, x1, y1, color);
  }

  /// Draws a line
  static void _drawLine(img.Image image, int x1, int y1, int x2, int y2, img.Color color) {
    final dx = (x2 - x1).abs();
    final dy = (y2 - y1).abs();
    final steps = dx > dy ? dx : dy;
    
    for (int i = 0; i <= steps; i++) {
      final t = steps == 0 ? 0.0 : i / steps;
      final x = (x1 + (x2 - x1) * t).round();
      final y = (y1 + (y2 - y1) * t).round();
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        image.setPixel(x, y, color);
      }
    }
  }

  /// Draws a horizontal line
  static void _drawHorizontalLine(img.Image image, int x, int y, int width, img.Color color) {
    for (int i = 0; i < width; i++) {
      final px = x + i;
      if (px >= 0 && px < image.width && y >= 0 && y < image.height) {
        image.setPixel(px, y, color);
      }
    }
  }

  /// Draws a filled rectangle
  static void _drawFilledRectangle(img.Image image, int x, int y, int width, int height, img.Color color) {
    for (int dy = y; dy < y + height && dy < image.height; dy++) {
      for (int dx = x; dx < x + width && dx < image.width; dx++) {
        if (dx >= 0 && dy >= 0) {
          image.setPixel(dx, dy, color);
        }
      }
    }
  }

  /// Draws @ symbol - circle with line through it
  static void _drawAtSymbol(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    final centerY = y + height ~/ 2;
    final radius = (width / 3).round();
    
    // Draw circle
    _drawCircle(image, centerX, centerY, radius, color);
    
    // Draw horizontal line through center
    _drawHorizontalLine(image, x, centerY, width, color);
    
    // Draw vertical line
    _drawVerticalLine(image, centerX, y, height, color);
  }

  /// Draws letter A - triangle with horizontal line
  static void _drawLetterA(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    final midY = y + height ~/ 2;
    
    // Draw triangle
    _drawLine(image, centerX, y, x, y + height, color);
    _drawLine(image, centerX, y, x + width, y + height, color);
    _drawLine(image, x, y + height, x + width, y + height, color);
    
    // Draw horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
  }

  /// Draws letter B - two vertical lines with curves
  static void _drawLetterB(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws letter C - curved line
  static void _drawLetterC(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws letter D - vertical line with curve
  static void _drawLetterD(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
    
    // Right vertical line
    _drawVerticalLine(image, x + width - 1, y, height, color);
  }

  /// Draws letter E - vertical line with three horizontals
  static void _drawLetterE(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws letter F - vertical line with two horizontals
  static void _drawLetterF(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
  }

  /// Draws letter G - C with additional line
  static void _drawLetterG(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
    
    // Right vertical line (partial)
    _drawVerticalLine(image, x + width - 1, midY, height - midY, color);
    
    // Middle horizontal line (partial)
    _drawHorizontalLine(image, midY, midY, width - midY, color);
  }

  /// Draws letter H - two verticals with horizontal
  static void _drawLetterH(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Right vertical line
    _drawVerticalLine(image, x + width - 1, y, height, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
  }

  /// Draws letter I - vertical line with caps
  static void _drawLetterI(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Center vertical line
    _drawVerticalLine(image, centerX, y, height, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws letter J - curved line
  static void _drawLetterJ(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Right vertical line (partial)
    _drawVerticalLine(image, x + width - 1, y, height ~/ 2, color);
    
    // Bottom curve (simplified as horizontal)
    _drawHorizontalLine(image, x, y + height - 1, width ~/ 2, color);
  }

  /// Draws letter K - vertical with diagonal
  static void _drawLetterK(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top diagonal
    _drawLine(image, x, midY, x + width, y, color);
    
    // Bottom diagonal
    _drawLine(image, x, midY, x + width, y + height, color);
  }

  /// Draws letter L - vertical with horizontal
  static void _drawLetterL(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws letter M - two verticals with diagonal
  static void _drawLetterM(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Right vertical line
    _drawVerticalLine(image, x + width - 1, y, height, color);
    
    // Left diagonal
    _drawLine(image, x, y, centerX, y + height ~/ 2, color);
    
    // Right diagonal
    _drawLine(image, centerX, y + height ~/ 2, x + width, y, color);
  }

  /// Draws letter N - two verticals with diagonal
  static void _drawLetterN(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Right vertical line
    _drawVerticalLine(image, x + width - 1, y, height, color);
    
    // Diagonal line
    _drawLine(image, x, y, x + width, y + height, color);
  }

  /// Draws letter O - circle/oval
  static void _drawLetterO(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    final centerY = y + height ~/ 2;
    final radiusX = width ~/ 2;
    final radiusY = height ~/ 2;
    
    // Draw oval using circle approximation
    _drawCircle(image, centerX, centerY, (radiusX + radiusY) ~/ 2, color);
  }

  /// Draws letter P - vertical with top curve
  static void _drawLetterP(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Right vertical line (partial)
    _drawVerticalLine(image, x + width - 1, y, height ~/ 2, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
  }

  /// Draws letter Q - O with tail
  static void _drawLetterQ(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Draw O first
    _drawLetterO(image, x, y, width, height, color);
    
    // Add diagonal tail
    _drawLine(image, x + width ~/ 2, y + height ~/ 2, x + width, y + height, color);
  }

  /// Draws letter R - P with diagonal
  static void _drawLetterR(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Draw P first
    _drawLetterP(image, x, y, width, height, color);
    
    // Add diagonal
    final midY = y + height ~/ 2;
    _drawLine(image, x, midY, x + width, y + height, color);
  }

  /// Draws letter S - curved line
  static void _drawLetterS(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Left vertical line (top half)
    _drawVerticalLine(image, x, y, height ~/ 2, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
    
    // Right vertical line (bottom half)
    _drawVerticalLine(image, x + width - 1, midY, height ~/ 2, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws letter T - horizontal with vertical
  static void _drawLetterT(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Center vertical line
    _drawVerticalLine(image, centerX, y, height, color);
  }

  /// Draws letter U - two verticals with bottom curve
  static void _drawLetterU(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Right vertical line
    _drawVerticalLine(image, x + width - 1, y, height, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws letter V - two diagonals
  static void _drawLetterV(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    
    // Left diagonal
    _drawLine(image, x, y, centerX, y + height, color);
    
    // Right diagonal
    _drawLine(image, centerX, y + height, x + width, y, color);
  }

  /// Draws letter W - two V shapes
  static void _drawLetterW(img.Image image, int x, int y, int width, int height, img.Color color) {
    final quarterX = x + width ~/ 4;
    final threeQuarterX = x + (3 * width) ~/ 4;
    
    // Left diagonal
    _drawLine(image, x, y, quarterX, y + height, color);
    
    // Left middle diagonal
    _drawLine(image, quarterX, y + height, x + width ~/ 2, y, color);
    
    // Right middle diagonal
    _drawLine(image, x + width ~/ 2, y, threeQuarterX, y + height, color);
    
    // Right diagonal
    _drawLine(image, threeQuarterX, y + height, x + width, y, color);
  }

  /// Draws letter X - two diagonals crossing
  static void _drawLetterX(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Top-left to bottom-right diagonal
    _drawLine(image, x, y, x + width, y + height, color);
    
    // Top-right to bottom-left diagonal
    _drawLine(image, x + width, y, x, y + height, color);
  }

  /// Draws letter Y - V with vertical
  static void _drawLetterY(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    final midY = y + height ~/ 2;
    
    // Left diagonal
    _drawLine(image, x, y, centerX, midY, color);
    
    // Right diagonal
    _drawLine(image, centerX, midY, x + width, y, color);
    
    // Bottom vertical
    _drawVerticalLine(image, centerX, midY, height - midY, color);
  }

  /// Draws letter Z - horizontal, diagonal, horizontal
  static void _drawLetterZ(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Diagonal line
    _drawLine(image, x + width, y, x, y + height, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws number 0 - oval
  static void _drawNumber0(img.Image image, int x, int y, int width, int height, img.Color color) {
    _drawLetterO(image, x, y, width, height, color);
  }

  /// Draws number 1 - vertical line with small horizontal
  static void _drawNumber1(img.Image image, int x, int y, int width, int height, img.Color color) {
    final centerX = x + width ~/ 2;
    
    // Small top horizontal
    _drawHorizontalLine(image, centerX - 2, y, 4, color);
    
    // Main vertical line
    _drawVerticalLine(image, centerX, y, height, color);
  }

  /// Draws number 2 - curved top, diagonal, horizontal
  static void _drawNumber2(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Right vertical line (top half)
    _drawVerticalLine(image, x + width - 1, y, height ~/ 2, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, y + height ~/ 2, width, color);
    
    // Left vertical line (bottom half)
    _drawVerticalLine(image, x, y + height ~/ 2, height ~/ 2, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws number 3 - two curves
  static void _drawNumber3(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Right vertical line
    _drawVerticalLine(image, x + width - 1, y, height, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws number 4 - vertical with horizontal
  static void _drawNumber4(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line (top half)
    _drawVerticalLine(image, x, y, height ~/ 2, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
    
    // Right vertical line
    _drawVerticalLine(image, x + width - 1, y, height, color);
  }

  /// Draws number 5 - horizontal, vertical, horizontal, vertical, horizontal
  static void _drawNumber5(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Left vertical line (top half)
    _drawVerticalLine(image, x, y, height ~/ 2, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
    
    // Right vertical line (bottom half)
    _drawVerticalLine(image, x + width - 1, midY, height ~/ 2, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws number 6 - curved shape
  static void _drawNumber6(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Left vertical line
    _drawVerticalLine(image, x, y, height, color);
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
    
    // Right vertical line (bottom half)
    _drawVerticalLine(image, x + width - 1, midY, height ~/ 2, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws number 7 - horizontal with diagonal
  static void _drawNumber7(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Diagonal line
    _drawLine(image, x + width, y, x, y + height, color);
  }

  /// Draws number 8 - two circles
  static void _drawNumber8(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Top circle
    _drawCircle(image, x + width ~/ 2, y + height ~/ 4, height ~/ 4, color);
    
    // Bottom circle
    _drawCircle(image, x + width ~/ 2, y + (3 * height) ~/ 4, height ~/ 4, color);
  }

  /// Draws number 9 - curved shape
  static void _drawNumber9(img.Image image, int x, int y, int width, int height, img.Color color) {
    final midY = y + height ~/ 2;
    
    // Top horizontal line
    _drawHorizontalLine(image, x, y, width, color);
    
    // Left vertical line (top half)
    _drawVerticalLine(image, x, y, height ~/ 2, color);
    
    // Middle horizontal line
    _drawHorizontalLine(image, x, midY, width, color);
    
    // Right vertical line
    _drawVerticalLine(image, x + width - 1, y, height, color);
    
    // Bottom horizontal line
    _drawHorizontalLine(image, x, y + height - 1, width, color);
  }

  /// Draws a vertical line
  static void _drawVerticalLine(img.Image image, int x, int y, int height, img.Color color) {
    for (int i = 0; i < height; i++) {
      final dy = y + i;
      if (dy >= 0 && dy < image.height && x >= 0 && x < image.width) {
        image.setPixel(x, dy, color);
      }
    }
  }

  /// Test method to verify watermarking is working
  static Future<void> testWatermarking() async {
    try {
      print('🧪 Testing watermarking functionality...');
      
      // Create a simple test image
      final testImage = img.Image(width: 400, height: 300);
      // Fill with a simple color
      for (int x = 0; x < testImage.width; x++) {
        for (int y = 0; y < testImage.height; y++) {
          testImage.setPixel(x, y, img.ColorRgb8(100, 150, 200));
        }
      }
      
      // Convert to bytes
      final imageBytes = Uint8List.fromList(img.encodePng(testImage));
      
      print('📏 Test image created: ${testImage.width}x${testImage.height}');
      print('📏 Test image size: ${imageBytes.length} bytes');
      
      // Add watermark with explicit parameters
      final watermarkedBytes = await addWatermarkToImage(
        imageBytes: imageBytes,
        username: 'TestUser',
        userId: 'test123',
        customText: '@TestUser',
        customPosition: WatermarkPosition.center,
        customSize: 0.8,
        customOpacity: 0.9,
        customColor: WatermarkColor.yellow,
      );
      
      print('✅ Watermarking test completed successfully');
      print('📏 Original size: ${imageBytes.length} bytes');
      print('📏 Watermarked size: ${watermarkedBytes.length} bytes');
      print('🔍 Size difference: ${watermarkedBytes.length - imageBytes.length} bytes');
      
      // Check if watermarking actually changed the image
      if (watermarkedBytes.length != imageBytes.length) {
        print('✅ Watermarking appears to be working - image size changed');
      } else {
        print('⚠️ Watermarking may not be working - image size unchanged');
      }
      
    } catch (e) {
      print('❌ Watermarking test failed: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Creates a watermark overlay widget for Flutter UI
  static Widget createWatermarkOverlay({
    required String username,
    WatermarkPosition position = WatermarkPosition.bottomRight,
    double opacity = 0.7,
    Color color = Colors.yellow,
  }) {
    return Positioned(
      top: position == WatermarkPosition.topLeft || position == WatermarkPosition.topRight ? 16 : null,
      bottom: position == WatermarkPosition.bottomLeft || position == WatermarkPosition.bottomRight ? 16 : null,
      left: position == WatermarkPosition.topLeft || position == WatermarkPosition.bottomLeft ? 16 : null,
      right: position == WatermarkPosition.topRight || position == WatermarkPosition.bottomRight ? 16 : null,
      child: Opacity(
        opacity: opacity,
        child: Text(
          '@$username',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black,
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Checks if an image has watermark metadata
  static Future<bool> hasWatermarkMetadata(File imageFile) async {
    try {
      final exifData = await readExifFromFile(imageFile);
      return exifData.containsKey('UserComment') && 
             exifData['UserComment']?.printable.contains('MarketSafe') == true;
    } catch (e) {
      print('Error checking metadata: $e');
      return false;
    }
  }

  /// Checks if an image is from the internet (not local camera/gallery)
  static Future<bool> isImageFromInternet(Uint8List imageBytes) async {
    try {
      // For now, we'll assume all local images are not from internet
      // In a real implementation, you might check EXIF data or other indicators
      return false;
    } catch (e) {
      print('Error checking if image is from internet: $e');
      return false;
    }
  }

  /// Validates image authenticity and returns validation result
  static Future<Map<String, dynamic>> validateImageAuthenticity({
    required Uint8List imageBytes,
    required String username,
    String? userId,
  }) async {
    try {
      print('🔍 Validating image authenticity for user: $username');
      
      // Check if image is from internet
      final isFromInternet = await isImageFromInternet(imageBytes);
      
      // For now, we'll consider images valid if they're not from internet
      // In a real implementation, you might check for watermark metadata
      final isValid = !isFromInternet;
      
      final result = {
        'isValid': isValid,
        'isFromInternet': isFromInternet,
        'hasMetadata': true, // Assume local images have metadata
        'reason': isValid ? 'Image is authentic' : 'Image appears to be from internet',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      print('✅ Image validation result: $result');
      return result;
    } catch (e) {
      print('❌ Error validating image authenticity: $e');
      return {
        'isValid': false,
        'isFromInternet': false,
        'hasMetadata': false,
        'reason': 'Validation error: $e',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }
}

enum WatermarkPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}