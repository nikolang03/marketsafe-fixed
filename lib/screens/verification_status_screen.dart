import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_sync_service.dart';
import 'welcome_screen.dart';

class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  String _verificationStatus = 'pending';
  String? _rejectionReason;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
    _listenToStatusChanges();
  }

  Future<void> _checkVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final status = await AdminSyncService.getVerificationStatus(user.uid);
      if (status != null) {
        setState(() {
          _verificationStatus = status['status'] ?? 'pending';
          _rejectionReason = status['rejectionReason'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToStatusChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      AdminSyncService.listenToVerificationStatus(user.uid).listen((status) {
        setState(() {
          _verificationStatus = status;
        });
        
        if (status == 'approved') {
          _showApprovalDialog();
        } else if (status == 'rejected') {
          _loadRejectionReason();
        }
      });
    }
  }

  Future<void> _loadRejectionReason() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final reason = await AdminSyncService.getRejectionReason(user.uid);
      setState(() {
        _rejectionReason = reason;
      });
    }
  }

  void _showApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text("Account Approved!"),
            ],
          ),
          content: const Text(
            "Congratulations! Your account has been approved by our admin team. You can now access all features of MarketSafe.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/categories');
              },
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusIcon() {
    switch (_verificationStatus) {
      case 'approved':
        return const Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green,
        );
      case 'rejected':
        return const Icon(
          Icons.cancel,
          size: 80,
          color: Colors.red,
        );
      default:
        return const Icon(
          Icons.hourglass_empty,
          size: 80,
          color: Colors.orange,
        );
    }
  }

  Widget _buildStatusMessage() {
    switch (_verificationStatus) {
      case 'approved':
        return const Column(
          children: [
            Text(
              "Account Approved",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Your account has been approved! You can now access all features.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        );
      case 'rejected':
        return Column(
          children: [
            const Text(
              "Account Rejected",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Unfortunately, your account verification was rejected.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            if (_rejectionReason != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Reason:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _rejectionReason!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      default:
        return const Column(
          children: [
            Text(
              "Under Verification",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Your account is currently being reviewed by our admin team. This usually takes 24-48 hours.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        );
    }
  }

  Widget _buildActionButtons() {
    switch (_verificationStatus) {
      case 'approved':
        return ElevatedButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/categories');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: const Text(
            "Continue to App",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        );
      case 'rejected':
        return Column(
          children: [
            ElevatedButton(
              onPressed: () {
                // Allow user to try again or contact support
                _showContactSupportDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                "Contact Support",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
              child: const Text(
                "Back to Welcome",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      default:
        return Column(
          children: [
            ElevatedButton(
              onPressed: () {
                _checkVerificationStatus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                "Refresh Status",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
              child: const Text(
                "Back to Welcome",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
    }
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Contact Support"),
          content: const Text(
            "Please contact our support team for assistance with your account verification.\n\nEmail: support@marketsafe.com\nPhone: +63 123 456 7890",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2C0000),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2C0000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Logo
              Image.asset('assets/logo.png', height: 80),
              const SizedBox(height: 40),
              
              // Status Icon
              _buildStatusIcon(),
              const SizedBox(height: 30),
              
              // Status Message
              _buildStatusMessage(),
              const SizedBox(height: 40),
              
              // Action Buttons
              _buildActionButtons(),
              
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
