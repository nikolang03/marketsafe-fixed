import 'package:capstone2/screens/face_headmovement_screen.dart';
import 'package:flutter/material.dart';
import 'add_profile_photo_screen.dart';
import 'face_blinktwice_screen.dart';

class FaceReadyScreen extends StatelessWidget {
  const FaceReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: SafeArea(
        child: Center( // 💡 This centers the whole column vertically
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 💡 Prevents taking full height
              mainAxisAlignment: MainAxisAlignment.center,
              children: [


                const SizedBox(height: 40),

                const Text(
                  "GET READY TO VERIFY YOURSELF",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 30),

                // Face image with oval

                Container(
                  width: 160,
                  height: 210,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 4), // Full border
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(160, 210), // Make it a true oval shape
                    ),
                  ),

                    child: Image.asset(
                      'assets/facereadyicon.png', // Your logo asset
                      height: 20,alignment: AlignmentGeometry.xy(-0.2, -0.06),

                    ),
                ),



                const SizedBox(height: 30),

                const Text(
                  "FRAME YOUR FACE IN THE OVAL,\nPRESS I'M READY AND MOVE CLOSER",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: () {
                    // Go to AddProfilePhotoScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FaceScanScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text("I'M READY", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
