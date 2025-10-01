import 'dart:io';

import 'package:capstone2/screens/face_instruction_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddProfilePhotoScreen extends StatefulWidget {
  const AddProfilePhotoScreen({super.key});

  @override
  State<AddProfilePhotoScreen> createState() => _AddProfilePhotoScreenState();
}

class _AddProfilePhotoScreenState extends State<AddProfilePhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;

  Future<void> _pickImage(ImageSource source) async {
    final pickedImage = await _picker.pickImage(source: source);
    if (pickedImage != null) {
      setState(() {
        _image = pickedImage;
      });
    }
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
                  onTap: () => _pickImage(ImageSource.camera),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                  onTap: () => _pickImage(ImageSource.gallery),
                   child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FaceVerificationScreen()),
                );
                // TODO: Navigate to next page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text("NEXT", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
        ),
    );
  }
}
