import 'package:flutter/material.dart';
import 'face_ready_screen.dart';

class FaceVerificationScreen extends StatelessWidget {
  const FaceVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ allow adjusting when keyboard opens
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color(0xFF2B0000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView( // ✅ prevents overflow
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ✅ let it shrink if needed
              children: [
                const SizedBox(height: 150),

                const Text(
                  "FACE VERIFICATION",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 15),

                Image.asset(
                  'assets/faceicon.png',
                  height: 180,
                ),

                const SizedBox(height: 15),

                const Text(
                  "REMOVE ANY ITEMS OBSTRUCTING YOUR FACE.\n"
                      "POSITION YOUR FACE WITHIN THE FRAME.\n"
                      "YOUR FACE WILL BE AUTOMATICALLY SCANNED.\n"
                      "CLICK NEXT IF YOU'RE READY",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),

                const SizedBox(height: 50),

                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus(); // ✅ close keyboard if still open
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FaceReadyScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "NEXT",
                    style: TextStyle(color: Colors.white),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
