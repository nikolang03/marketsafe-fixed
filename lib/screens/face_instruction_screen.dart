import 'package:flutter/material.dart';
import 'face_ready_screen.dart';

class FaceVerificationScreen extends StatelessWidget {
  const FaceVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF2B0000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo.png',
                    height: 60,
                  ),
                  
                  const SizedBox(height: 30),

                  // Title
                  Text(
                    "FACE VERIFICATION",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // Face icon
                  Image.asset(
                    'assets/faceicon.png',
                    height: 180,
                  ),
                  
                  const SizedBox(height: 20),

                  // Instructions
                  Text(
                    "REMOVE ANY ITEMS OBSTRUCTING YOUR FACE.\n"
                        "POSITION YOUR FACE WITHIN THE FRAME.\n"
                        "YOUR FACE WILL BE AUTOMATICALLY SCANNED.\n"
                        "CLICK NEXT IF YOU'RE READY",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 1.0,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Next button
                  ElevatedButton(
                    onPressed: () {
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
                      elevation: 8,
                    ),
                    child: const Text(
                      "NEXT",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
