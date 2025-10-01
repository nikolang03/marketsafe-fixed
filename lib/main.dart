import 'package:capstone2/screens/face_blinktwice_screen.dart';
import 'package:capstone2/screens/face_headmovement_screen.dart';
import 'package:capstone2/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  runApp(const MarketSafeApp());
}

class MarketSafeApp extends StatelessWidget {
  const MarketSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MarketSafe',
      debugShowCheckedModeBanner: false,
      home: FaceScanScreen(),
    );
  }
}
