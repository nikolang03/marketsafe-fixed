import 'dart:async';
import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'face_login_screen.dart';
import '../services/lockout_service.dart';
import '../services/navigation_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> 
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration? _remainingTime;
  
  // Animation controllers
  late AnimationController _logoAnimationController;
  late AnimationController _flipAnimationController;
  late AnimationController _textAnimationController;
  late AnimationController _buttonAnimationController;
  late AnimationController _glowAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _backgroundAnimationController;
  
  // Animations
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _spinAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _buttonSlideAnimation;
  late Animation<double> _buttonOpacityAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
    _startTimer();
    
    // Initialize animation controllers
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _flipAnimationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _glowAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    // Initialize animations
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
    
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    
    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _buttonOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Smooth spinning animation
    _spinAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipAnimationController,
      curve: Curves.linear, // Linear for smooth continuous spinning
    ));
    
    // Background floating animation
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.easeInOut,
    ));
    
    
    // Start animations
    _startAnimations();
    
    // Check if we should show face already registered dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForFaceDuplicationDialog();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logoAnimationController.dispose();
    _flipAnimationController.dispose();
    _textAnimationController.dispose();
    _buttonAnimationController.dispose();
    _glowAnimationController.dispose();
    _pulseAnimationController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    // Start logo animation immediately
    _logoAnimationController.forward();
    
    // Start text animation after logo starts
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _textAnimationController.forward();
      }
    });
    
    // Start button animation after text starts
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _buttonAnimationController.forward();
      }
    });
    
    // Start continuous animations (only for logo)
    _glowAnimationController.repeat(reverse: true);
    _pulseAnimationController.repeat(reverse: true);
    
    // Start background animation
    _backgroundAnimationController.repeat(reverse: true);
  }

  void _checkLockoutStatus() {
    if (LockoutService.isLockedOut()) {
      _remainingTime = LockoutService.getRemainingTime();
    } else {
      _remainingTime = null;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _checkLockoutStatus();
        });
      }
    });
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _checkForFaceDuplicationDialog() {
    // Check if we came from face duplication detection
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['showFaceDuplicationDialog'] == true) {
      _showFaceAlreadyRegisteredDialog();
    }
  }

  void _showFaceAlreadyRegisteredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Face Already Registered",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: const Text(
            "This face has already been registered in our system. Please use a different account or contact support if you believe this is an error.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text(
                "OK",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF1a1a1a), Color(0xFF2B0000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated background elements
            ..._buildAnimatedBackgroundElements(),
            // Main Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                child: Column(
                  children: [
                    // Top spacing
                    const Spacer(flex: 2),
                    
                    // Logo at the top
                    Image.asset(
                      "assets/logo.png",
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    // Red accent line below logo
                    Container(
                      width: 50,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Epic Welcome Text with Typewriter Effect
                    AnimatedBuilder(
                      animation: _textAnimationController,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _textSlideAnimation,
                          child: FadeTransition(
                            opacity: _textOpacityAnimation,
                            child: Column(
                              children: [
                                const Text(
                                  "Welcome to",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // MarketSafe text below "Welcome to" with different colors
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "Market",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.0,
                                          fontFamily: 'Plank',
                                        ),
                                      ),
                                      TextSpan(
                                        text: "Safe",
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.0,
                                          fontFamily: 'Plank',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  "Your trusted marketplace for secure transactions",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w300,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Feature highlights
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildFeatureItem(Icons.security, "Secure"),
                                    _buildFeatureItem(Icons.verified_user, "Verified"),
                                    _buildFeatureItem(Icons.support_agent, "Support"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const Spacer(flex: 2),
                    
                    // Epic Buttons with Hover Effects
                    AnimatedBuilder(
                      animation: _buttonAnimationController,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _buttonSlideAnimation,
                          child: FadeTransition(
                            opacity: _buttonOpacityAnimation,
                            child: Column(
                              children: [
                                // Login Button
                                _buildProfessionalButton(
                                  text: _remainingTime != null
                                      ? "LOG IN (${_formatTime(_remainingTime!)})"
                                      : "LOG IN",
                                  onPressed: _remainingTime != null
                                      ? null
                                      : () {
                                          NavigationService.navigateWithLoading(
                                            context,
                                            const FaceLoginScreen(),
                                            loadingMessage: "Preparing login...",
                                            loadingDuration: const Duration(milliseconds: 800),
                                            transitionType: PageTransitionType.slideFromRight,
                                          );
                                        },
                                  isEnabled: _remainingTime == null,
                                  isPrimary: true,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Sign Up Button
                                _buildProfessionalButton(
                                  text: "SIGN UP",
                                  onPressed: () {
                                    NavigationService.navigateWithLoading(
                                      context,
                                      const SignUpScreen(),
                                      loadingMessage: "Preparing registration...",
                                      loadingDuration: const Duration(milliseconds: 800),
                                      transitionType: PageTransitionType.slideFromRight,
                                    );
                                  },
                                  isEnabled: true,
                                  isPrimary: false,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Footer
                    const Text(
                      "By continuing, you agree to our Terms of Service and Privacy Policy",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        height: 1.3,
                      ),
                    ),
                    
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFeatureItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.red,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isEnabled,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isPrimary
                  ? (isEnabled ? Colors.red : Colors.grey[600])
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isPrimary
                  ? null
                  : Border.all(
                      color: isEnabled ? Colors.white.withOpacity(0.3) : Colors.grey,
                      width: 1.5,
                    ),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: isPrimary
                      ? Colors.white
                      : (isEnabled ? Colors.white : Colors.grey),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedBackgroundElements() {
    return [
      // Firefly/Dust particles - Small glowing dots
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 80 + (60 * _backgroundAnimation.value),
            left: 40 + (40 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.3 + (0.4 * _backgroundAnimation.value),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.8),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 150 - (30 * _backgroundAnimation.value),
            right: 60 + (50 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.2 + (0.3 * _backgroundAnimation.value),
              child: Container(
                width: 2,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.6),
                      blurRadius: 3,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 220 + (80 * _backgroundAnimation.value),
            left: 120 - (60 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.25 + (0.35 * _backgroundAnimation.value),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.7),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 100 - (40 * _backgroundAnimation.value),
            right: 100 + (30 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.15 + (0.25 * _backgroundAnimation.value),
              child: Container(
                width: 2.5,
                height: 2.5,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 2,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 300 + (50 * _backgroundAnimation.value),
            left: 20 - (30 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.2 + (0.3 * _backgroundAnimation.value),
              child: Container(
                width: 3.5,
                height: 3.5,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 180 + (70 * _backgroundAnimation.value),
            right: 30 - (40 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.18 + (0.28 * _backgroundAnimation.value),
              child: Container(
                width: 2,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 3,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 250 - (50 * _backgroundAnimation.value),
            left: 180 + (60 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.22 + (0.32 * _backgroundAnimation.value),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 3,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 350 + (40 * _backgroundAnimation.value),
            right: 150 + (20 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.16 + (0.26 * _backgroundAnimation.value),
              child: Container(
                width: 2.5,
                height: 2.5,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 2,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 120 + (90 * _backgroundAnimation.value),
            left: 60 - (50 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.2 + (0.3 * _backgroundAnimation.value),
              child: Container(
                width: 1.5,
                height: 1.5,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 2,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Positioned(
            top: 280 - (60 * _backgroundAnimation.value),
            right: 80 + (40 * _backgroundAnimation.value),
            child: Opacity(
              opacity: 0.24 + (0.34 * _backgroundAnimation.value),
              child: Container(
                width: 3.5,
                height: 3.5,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}
