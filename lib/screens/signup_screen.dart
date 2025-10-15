import 'package:capstone2/services/email_service.dart';
import 'package:capstone2/services/user_check_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _inputType; // 'phone' or 'email'

  void _detectInputType(String input) {
    // Check if it's a Philippine phone number (starts with 09, 10 digits total)
    if (RegExp(r'^09\d{9}$').hasMatch(input)) {
      _inputType = 'phone';
    } else if (input.contains('@')) {
      _inputType = 'email';
    } else {
      _inputType = null;
    }
  }

  String _formatPhoneNumber(String phone) {
    // Convert 09123456789 to +639123456789
    if (phone.startsWith('09')) {
      return '+63${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _sendOtp() async {
    final input = _inputController.text.trim();

    if (input.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number or email');
      return;
    }

    // Detect input type
    _detectInputType(input);

    if (_inputType == null) {
      setState(() => _errorMessage =
          'Please enter a valid phone number (09123456789) or email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if user already exists
      print('🔍 Checking if user already exists...');
      final userCheck = await UserCheckService.checkUserExists(input);
      
      if (userCheck['exists']) {
        setState(() {
          _isLoading = false;
          _errorMessage = userCheck['message'];
        });
        return;
      }

      print('✅ User does not exist - proceeding with OTP...');

      if (_inputType == 'phone') {
        // Phone verification - convert to international format
        String phoneNumber = _formatPhoneNumber(input);

        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto sign-in
          },
          verificationFailed: (FirebaseAuthException e) {
            setState(() => _errorMessage = e.message);
          },
          codeSent: (String verificationId, int? resendToken) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  verificationId: verificationId,
                  phoneNumber: input, // Keep original format for display
                  verificationType: 'phone',
                ),
              ),
            );
          },
          codeAutoRetrievalTimeout: (_) {},
        );
      } else {
        // Email verification
        await EmailService.sendOtp(input);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              verificationId: '', // Not needed for email
              phoneNumber: input, // Reusing phoneNumber field for email
              verificationType: 'email',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                            MediaQuery.of(context).padding.top - 
                            MediaQuery.of(context).padding.bottom - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Image.asset('assets/logo.png', height: 80),
                    const SizedBox(height: 30),
                    const Text(
                      "SIGN UP",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Single input field for phone or email
                    TextField(
                      controller: _inputController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "Phone Number or Email",
                        hintText: "Enter 09123456789 or your@email.com",
                        prefixIcon: Icon(Icons.person, color: Colors.white),
                        labelStyle: TextStyle(color: Colors.white),
                        hintStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        // Clear error message when user starts typing
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    // Show detected input type
                    if (_inputController.text.isNotEmpty)
                      Text(
                        _inputType == 'phone'
                            ? "📱 Phone verification will be used"
                            : _inputType == 'email'
                                ? "📧 Email verification will be used"
                                : "❌ Invalid format",
                        style: TextStyle(
                          color: _inputType != null ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),

                    const SizedBox(height: 20),

                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: 180,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "SEND OTP",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Help text
                    const Text(
                      "Enter your phone number (09123456789) or email address",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
