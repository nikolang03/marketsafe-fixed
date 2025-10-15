import 'dart:async';
import 'package:capstone2/services/email_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_profile_photo_screen.dart';
import '../services/admin_sync_service.dart';
import 'face_instruction_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber; // This will contain phone or email
  final String verificationType; // 'phone' or 'email'

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.verificationType,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  int _secondsRemaining = 60;
  Timer? _timer;
  String? _currentVerificationId;
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 45,
      height: 55,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].clear();
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 3),
            ),
          ),
          onChanged: (value) {
            print('🔍 OTP input changed at index $index: $value');
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            }
            // Show current OTP for debugging
            final currentOtp = getOtpCode();
            print('🔍 Current OTP: $currentOtp (length: ${currentOtp.length})');
          },
        ),
      ),
    );
  }

  String getOtpCode() => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    // Prevent multiple simultaneous verification attempts
    if (_isLoading) return;
    
    final otp = getOtpCode();
    print('🔍 OTP Verification: Starting verification for ${widget.verificationType}');
    print('🔍 OTP Code entered: $otp');
    print('🔍 Phone/Email: ${widget.phoneNumber}');
    
    if (otp.length != 6) {
      print('❌ OTP length invalid: ${otp.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter all 6 digits")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    // Add a small delay to prevent rapid UI updates
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      if (widget.verificationType == 'phone') {
        // Phone verification
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _currentVerificationId!,
          smsCode: otp,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
        
        // Initialize user in admin system for phone verification (non-blocking)
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          AdminSyncService.initializeUser(
            email: '',
            phoneNumber: widget.phoneNumber,
          ).catchError((error) {
            print('⚠️ Admin sync failed (non-blocking): $error');
          });
        }
      } else {
        // Email verification
        print('🔍 Starting email verification process...');
        try {
          print('🔍 Calling EmailService.verifyOtp...');
          final isValid = await EmailService.verifyOtp(widget.phoneNumber, otp);
          print('🔍 EmailService.verifyOtp returned: $isValid');

          if (!isValid) {
            print('❌ OTP verification failed - invalid code');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Invalid OTP code. Please try again.")),
              );
              setState(() {
                _isLoading = false;
              });
            }
            return;
          }
          print('✅ OTP verification successful - proceeding to Firebase auth');
        } catch (e) {
          print('❌ OTP verification error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("OTP verification failed: $e")),
            );
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        // For email OTP verification, create a Firebase Auth user
        print('🔍 Email OTP verified successfully - creating Firebase Auth user');
        
        // Create Firebase Auth user with email and password
        // We'll use the OTP as a temporary password since we verified it
        try {
          final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: widget.phoneNumber, // This contains the email
            password: otp, // Use OTP as temporary password
          );
          
          print('✅ Firebase Auth user created for email: ${widget.phoneNumber}');
          print('✅ User UID: ${credential.user?.uid}');
          
          // Initialize user in admin system for email verification (non-blocking)
          AdminSyncService.initializeUser(
            email: widget.phoneNumber,
            phoneNumber: '',
          ).catchError((error) {
            print('⚠️ Admin sync failed (non-blocking): $error');
          });
        } catch (e) {
          print('❌ Failed to create Firebase Auth user: $e');
          // If user already exists, try to sign in
          try {
            final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: widget.phoneNumber,
              password: otp,
            );
            print('✅ Signed in existing Firebase Auth user: ${credential.user?.uid}');
          } catch (signInError) {
            print('❌ Failed to sign in existing user: $signInError');
            // Continue anyway - we'll handle this in the fill information screen
          }
        }
      }

      print('✅ OTP verification successful, navigating to next screen...');
      
      // Store signup data for the fill information screen
      try {
        final prefs = await SharedPreferences.getInstance();
        if (widget.verificationType == 'phone') {
          await prefs.setString('signup_phone', widget.phoneNumber);
          await prefs.setString('signup_email', '');
          print('📱 Stored signup phone: ${widget.phoneNumber}');
        } else {
          await prefs.setString('signup_email', widget.phoneNumber);
          await prefs.setString('signup_phone', '');
          print('📧 Stored signup email: ${widget.phoneNumber}');
        }
      } catch (e) {
        print('⚠️ Error storing signup data: $e');
        // Continue anyway - this is not critical
      }
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FaceVerificationScreen()),
        );
      }
    } catch (e) {
      print('❌ OTP verification failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (widget.verificationType == 'phone') {
      // Resend phone OTP
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to resend OTP: ${e.message}")),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _currentVerificationId = verificationId;
              _secondsRemaining = 60;
              _startTimer();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("OTP resent successfully")),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _currentVerificationId = verificationId;
        },
      );
    } else {
      // Resend email OTP
      try {
        await EmailService.sendOtp(widget.phoneNumber);
        if (mounted) {
          setState(() {
            _secondsRemaining = 60;
            _startTimer();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("OTP resent successfully")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to resend OTP: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C0000),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Image.asset('assets/logo.png', height: 80),
              const SizedBox(height: 20),
                
              const Text(
                "We sent a 6 digit verification code to",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text(
                widget.phoneNumber,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 30),
              
              const Text(
                "Enter OTP", 
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              
              const SizedBox(height: 15),
              
              // OTP Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    6,
                    (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: _buildOtpBox(index),
                        )),
              ),
              
              const SizedBox(height: 15),
              
              GestureDetector(
                onTap: _secondsRemaining == 0 ? _resendOtp : null,
                child: Text(
                  _secondsRemaining == 0
                      ? "Resend"
                      : "Resend ${_secondsRemaining}s",
                  style: TextStyle(
                    color: _secondsRemaining == 0 ? Colors.redAccent : Colors.grey,
                    decoration: _secondsRemaining == 0
                        ? TextDecoration.underline
                        : null,
                    fontSize: 14,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
                
              SizedBox(
                width: 180,
                height: 40,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
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
                          "VERIFY",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
