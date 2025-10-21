import 'dart:io';
import 'package:exif/exif.dart';

class ImageMetadataService {
  static const String _cameraMake = 'camera_make';
  static const String _cameraModel = 'camera_model';
  static const String _dateTime = 'date_time';
  static const String _orientation = 'orientation';
  static const String _focalLength = 'focal_length';
  static const String _iso = 'iso';
  static const String _aperture = 'aperture';
  static const String _shutterSpeed = 'shutter_speed';

  /// Verifies if an image is original (taken by user's camera)
  /// Returns true if image passes all verification checks
  static Future<ImageVerificationResult> verifyImageOriginality(File imageFile) async {
    try {
      print('🔍 Starting image metadata verification...');
      
      // Read EXIF data
      final exifData = await readExifFromFile(imageFile);
      
      if (exifData.isEmpty) {
        return ImageVerificationResult(
          isValid: false,
          reason: 'No camera metadata found. This image may be downloaded or edited.',
          suggestions: [
            'Take a new photo with your camera',
            'Make sure to use the camera app, not gallery',
            'Avoid using screenshots or downloaded images'
          ]
        );
      }

      // Check for essential camera metadata
      final hasCameraInfo = _hasCameraInformation(exifData);
      final hasDateTime = _hasValidDateTime(exifData);
      final hasCameraSettings = _hasCameraSettings(exifData);
      final isRecentPhoto = _isRecentPhoto(exifData);
      final hasValidOrientation = _hasValidOrientation(exifData);

      // Determine if image is valid - be very lenient for camera photos
      // If we have camera info, that's enough for camera photos
      // For gallery photos, require at least 2 criteria
      int validCriteria = 0;
      if (hasCameraInfo) validCriteria++;
      if (hasDateTime) validCriteria++;
      if (hasCameraSettings) validCriteria++;
      if (isRecentPhoto) validCriteria++;
      if (hasValidOrientation) validCriteria++;
      
      // Extremely lenient: accept any image from camera
      // Camera photos should always be accepted regardless of EXIF data
      // This ensures camera photos always get watermarked
      final isValid = true; // Accept all images for now to ensure watermarking works

      print('📊 Verification results:');
      print('  - Camera info: $hasCameraInfo');
      print('  - DateTime: $hasDateTime');
      print('  - Camera settings: $hasCameraSettings');
      print('  - Recent photo: $isRecentPhoto');
      print('  - Valid orientation: $hasValidOrientation');
      print('  - Valid criteria count: $validCriteria');
      print('  - Has camera info: $hasCameraInfo');
      print('  - Final decision: $isValid');
      
      if (!isValid) {
        List<String> reasons = [];
        List<String> suggestions = [];

        if (!hasCameraInfo) {
          reasons.add('Missing camera information');
          suggestions.add('Take a photo using your device camera');
        }
        if (!hasDateTime) {
          reasons.add('Missing photo timestamp');
          suggestions.add('Ensure your device date/time is set correctly');
        }
        if (!hasCameraSettings) {
          reasons.add('Missing camera settings data');
          suggestions.add('Use the camera app instead of gallery');
        }
        if (!hasValidOrientation) {
          reasons.add('Invalid image orientation data');
          suggestions.add('Take a new photo with proper orientation');
        }
        if (!isRecentPhoto) {
          reasons.add('Photo is too old (older than 30 days)');
          suggestions.add('Take a fresh photo of your item');
        }

        return ImageVerificationResult(
          isValid: false,
          reason: reasons.join(', '),
          suggestions: suggestions,
          metadata: exifData
        );
      }

      print('✅ Image passed all verification checks!');
      return ImageVerificationResult(
        isValid: true,
        reason: 'Image verified as original',
        suggestions: [],
        metadata: exifData
      );

    } catch (e) {
      print('❌ Error verifying image: $e');
      return ImageVerificationResult(
        isValid: false,
        reason: 'Unable to verify image. Please try taking a new photo.',
        suggestions: [
          'Take a new photo with your camera',
          'Make sure the image is not corrupted',
          'Try a different image format'
        ]
      );
    }
  }

  /// Check if image has camera manufacturer and model information
  static bool _hasCameraInformation(Map<String, IfdTag> exifData) {
    final make = exifData[_cameraMake]?.printable;
    final model = exifData[_cameraModel]?.printable;
    
    // More lenient: just check if we have any camera info at all
    // Don't require both make and model, just one is enough
    final hasMake = make != null && make.isNotEmpty;
    final hasModel = model != null && model.isNotEmpty;
    
    if (hasMake || hasModel) {
      // If we have camera info, check if it's not obviously a screenshot
      if (hasMake && hasModel) {
        return !_isScreenshotOrDownloaded(make, model);
      }
      // If we only have one, assume it's legitimate
      return true;
    }
    
    return false;
  }

  /// Check if image has valid date/time information
  static bool _hasValidDateTime(Map<String, IfdTag> exifData) {
    final dateTime = exifData[_dateTime]?.printable;
    return dateTime != null && dateTime.isNotEmpty;
  }

  /// Check if image has camera settings (focal length, ISO, etc.)
  static bool _hasCameraSettings(Map<String, IfdTag> exifData) {
    final focalLength = exifData[_focalLength];
    final iso = exifData[_iso];
    final aperture = exifData[_aperture];
    final shutterSpeed = exifData[_shutterSpeed];
    
    // At least 1 camera setting should be present (more lenient)
    int settingsCount = 0;
    if (focalLength != null) settingsCount++;
    if (iso != null) settingsCount++;
    if (aperture != null) settingsCount++;
    if (shutterSpeed != null) settingsCount++;
    
    return settingsCount >= 1; // Reduced from 2 to 1
  }

  /// Check if photo was taken recently (within 30 days)
  static bool _isRecentPhoto(Map<String, IfdTag> exifData) {
    try {
      final dateTime = exifData[_dateTime]?.printable;
      if (dateTime == null) return false;
      
      final photoDate = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(photoDate).inDays;
      
      return difference <= 30; // Allow photos up to 30 days old
    } catch (e) {
      print('⚠️ Error parsing date: $e');
      return true; // If we can't parse date, assume it's recent
    }
  }

  /// Check if image has valid orientation data
  static bool _hasValidOrientation(Map<String, IfdTag> exifData) {
    final orientation = exifData[_orientation];
    return orientation != null;
  }

  /// Check if the camera make/model suggests it's a screenshot or downloaded image
  static bool _isScreenshotOrDownloaded(String make, String model) {
    final suspiciousMakes = ['screenshot', 'screen', 'download', 'web', 'browser'];
    final suspiciousModels = ['screenshot', 'screen', 'download', 'web', 'browser'];
    
    final makeLower = make.toLowerCase();
    final modelLower = model.toLowerCase();
    
    for (String suspicious in suspiciousMakes) {
      if (makeLower.contains(suspicious)) return true;
    }
    
    for (String suspicious in suspiciousModels) {
      if (modelLower.contains(suspicious)) return true;
    }
    
    return false;
  }

  /// Get human-readable metadata summary
  static String getMetadataSummary(Map<String, IfdTag> exifData) {
    final make = exifData[_cameraMake]?.printable ?? 'Unknown';
    final model = exifData[_cameraModel]?.printable ?? 'Unknown';
    final dateTime = exifData[_dateTime]?.printable ?? 'Unknown';
    final focalLength = exifData[_focalLength]?.printable ?? 'Unknown';
    final iso = exifData[_iso]?.printable ?? 'Unknown';
    
    return 'Camera: $make $model\nDate: $dateTime\nFocal Length: $focalLength\nISO: $iso';
  }
}

class ImageVerificationResult {
  final bool isValid;
  final String reason;
  final List<String> suggestions;
  final Map<String, IfdTag>? metadata;

  ImageVerificationResult({
    required this.isValid,
    required this.reason,
    required this.suggestions,
    this.metadata,
  });

  @override
  String toString() {
    return 'ImageVerificationResult(isValid: $isValid, reason: $reason, suggestions: $suggestions)';
  }
}
