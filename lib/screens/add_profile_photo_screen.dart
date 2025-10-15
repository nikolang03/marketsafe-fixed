import 'dart:io';

import 'package:capstone2/screens/under_verification_screen.dart';
import 'package:capstone2/services/profile_photo_verification_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddProfilePhotoScreen extends StatefulWidget {
  const AddProfilePhotoScreen({super.key});

  @override
  State<AddProfilePhotoScreen> createState() => _AddProfilePhotoScreenState();
}

class _AddProfilePhotoScreenState extends State<AddProfilePhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  bool _isVerifying = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedImage = await _picker.pickImage(source: source);
    if (pickedImage != null) {
      setState(() {
        _image = pickedImage;
      });
    }
  }

  Future<void> _saveProfilePhoto() async {
    if (_image != null) {
      setState(() {
        _isVerifying = true;
      });

      try {
        // Get current user ID
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('signup_user_id') ?? 
                      prefs.getString('current_user_id') ?? '';
        
        if (userId.isEmpty) {
          _showErrorDialog('Error', 'No user logged in');
          return;
        }

        // Check if user has completed face verification
        final hasCompletedVerification = await ProfilePhotoVerificationService.hasUserCompletedFaceVerification(userId);
        
        if (!hasCompletedVerification) {
          _showErrorDialog(
            'Face Verification Required',
            'Please complete face verification first to upload profile photos.',
          );
          return;
        }

        // Verify and upload the profile photo
        final verificationResult = await ProfilePhotoVerificationService.verifyAndUploadProfilePhoto(_image!.path);
        
        if (verificationResult.success) {
          // Save the Firebase Storage URL to SharedPreferences for immediate access
          if (verificationResult.downloadUrl != null) {
            await prefs.setString('profile_photo_url', verificationResult.downloadUrl!);
            print('📸 Profile photo URL saved to SharedPreferences: ${verificationResult.downloadUrl}');
          }
          
          // Photo verified successfully - proceed to under verification screen
          _showSuccessDialog(
            'Photo Verified',
            'Your profile photo has been verified and uploaded successfully!',
            () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const UnderVerificationScreen()),
              );
            },
          );
          
          print('📸 Profile photo verified and uploaded: ${verificationResult.downloadUrl}');
        } else {
          // Photo verification failed
          _showErrorDialog(
            'Photo Verification Failed',
            verificationResult.error ?? 'The uploaded photo doesn\'t match to the face verification',
          );
        }
      } catch (e) {
        print('❌ Error saving profile photo: $e');
        _showErrorDialog(
          'Error',
          'Failed to verify profile photo: $e',
        );
      } finally {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _showSuccessDialog(String title, String message, VoidCallback onOk) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            title,
            style: const TextStyle(color: Colors.green),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onOk();
              },
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            title,
            style: const TextStyle(color: Colors.red),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
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
        body: Container(
          width: double.infinity,
          height: double.infinity, // full screen
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color(0xFF2B0000)], // same gradient as OTP
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [

            const Text(
              "ADD PROFILE PHOTO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Profile photo preview
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              backgroundImage: _image != null ? FileImage(
                // ignore: unnecessary_cast
                  (File(_image!.path)) as File
              ) : null,
              child: _image == null
                  ? const Icon(Icons.person, size: 60, color: Colors.black)
                  : null,
            ),

            const SizedBox(height: 30),

            // Buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // New Picture button
                GestureDetector(
                  onTap: _isVerifying ? null : () => _pickImage(ImageSource.camera),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isVerifying ? Colors.grey : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.camera_alt, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text("NEW PICTURE", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),

                const SizedBox(width: 40),

                // From Gallery button
                GestureDetector(
                  onTap: _isVerifying ? null : () => _pickImage(ImageSource.gallery),
                   child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isVerifying ? Colors.grey : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text("FROM GALLERY", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Next button
            ElevatedButton(
              onPressed: _isVerifying ? null : () async {
                if (_image == null) {
                  _showErrorDialog('No Photo Selected', 'Please select a photo first.');
                  return;
                }
                
                await _saveProfilePhoto();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isVerifying ? Colors.grey : Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isVerifying 
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text("VERIFYING...", style: TextStyle(color: Colors.white)),
                    ],
                  )
                : const Text("NEXT", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
        ),
    );
  }
}