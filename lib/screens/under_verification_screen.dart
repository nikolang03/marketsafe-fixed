import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation_wrapper.dart';
import 'welcome_screen.dart';

class UnderVerificationScreen extends StatefulWidget {
  const UnderVerificationScreen({super.key});

  @override
  State<UnderVerificationScreen> createState() =>
      _UnderVerificationScreenState();
}

class _UnderVerificationScreenState extends State<UnderVerificationScreen> {
  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    try {
      // Get the stored user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('signup_user_id') ?? '';
      
      if (userId.isEmpty) {
        print('❌ No signup user ID found for verification check');
        return;
      }
      
      print('🔍 Checking verification status for user: $userId');
      
      // Get the user document directly using the stored user ID
      final userDoc = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'marketsafe',
      )
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final verificationStatus = userData['verificationStatus'] ?? 'pending';
        
        print('📊 User verification status: $verificationStatus');
        
        if (verificationStatus == 'verified') {
          // User is verified, navigate to categories
          print('✅ User is verified! Navigating to categories...');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const NavigationWrapper()),
            );
          }
        } else if (verificationStatus == 'rejected') {
          print('❌ User was rejected');
          // Could show a message or navigate back to signup
        } else {
          print('⏳ User still pending verification');
        }
      } else {
        print('❌ User document not found in database');
      }
    } catch (e) {
      print('❌ Error checking verification status: $e');
    }
  }

  /// Sign out the user and clear all stored data
  Future<void> _signOut() async {
    try {
      print('🔄 Starting sign out process...');
      
      // Clear all SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('✅ Cleared SharedPreferences data');
      
      // Sign out from Firebase Auth (if user was authenticated)
      try {
        await FirebaseAuth.instance.signOut();
        print('✅ Signed out from Firebase Auth');
      } catch (e) {
        print('⚠️ No Firebase Auth session to sign out from: $e');
      }
      
      print('✅ Sign out completed successfully');
      
      if (mounted) {
        // Navigate to welcome screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      print('❌ Error during sign out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                "YOUR ACCOUNT IS\nUNDER VERIFICATION",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.account_circle,
                        size: 70, color: Colors.black54),
                    const SizedBox(height: 20),
                    const Text(
                      "We are currently reviewing your account verification.\n"
                      "We will notify you once your account is verified.\n\n"
                      "Please wait for admin approval.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Admin Dashboard: https://your-domain.com/admin.html",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Sign Out Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _signOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'SIGN OUT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
