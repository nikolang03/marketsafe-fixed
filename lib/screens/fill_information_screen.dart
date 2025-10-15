import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'under_verification_screen.dart';
import '../services/user_check_service.dart';
import '../services/face_uniqueness_service.dart';
import '../services/face_recognition_service.dart';
import 'add_profile_photo_screen.dart';

class FillInformationScreen extends StatefulWidget {
  const FillInformationScreen({super.key});

  @override
  State<FillInformationScreen> createState() => _FillInformationScreenState();
}

class _FillInformationScreenState extends State<FillInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  bool _isLoading = false;

  // Controllers for fields
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();

  String? gender; // Male or Female

  /// Get face verification data from SharedPreferences
  Future<Map<String, dynamic>> _getFaceVerificationDataWithoutUpload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get completion status
      final blinkCompleted = prefs.getBool('face_verification_blinkCompleted') ?? false;
      final moveCloserCompleted = prefs.getBool('face_verification_moveCloserCompleted') ?? false;
      final headMovementCompleted = prefs.getBool('face_verification_headMovementCompleted') ?? false;
      
      // Get completion timestamps
      final blinkCompletedAt = prefs.getString('face_verification_blinkCompletedAt') ?? '';
      final moveCloserCompletedAt = prefs.getString('face_verification_moveCloserCompletedAt') ?? '';
      final headMovementCompletedAt = prefs.getString('face_verification_headMovementCompletedAt') ?? '';
      
      // Get image paths
      final blinkImagePath = prefs.getString('face_verification_blinkImagePath') ?? '';
      final moveCloserImagePath = prefs.getString('face_verification_moveCloserImagePath') ?? '';
      final headMovementImagePath = prefs.getString('face_verification_headMovementImagePath') ?? '';
      
      // Get metrics
      final blinkMetrics = prefs.getString('face_verification_blinkMetrics') ?? '{}';
      final moveCloserMetrics = prefs.getString('face_verification_moveCloserMetrics') ?? '{}';
      final headMovementMetrics = prefs.getString('face_verification_headMovementMetrics') ?? '{}';
      
      // Get face features
      final blinkFeatures = prefs.getString('face_verification_blinkFeatures') ?? '';
      final moveCloserFeatures = prefs.getString('face_verification_moveCloserFeatures') ?? '';
      final headMovementFeatures = prefs.getString('face_verification_headMovementFeatures') ?? '';
      
      print('📊 Retrieved face verification data:');
      print('  - Blink completed: $blinkCompleted');
      print('  - Move closer completed: $moveCloserCompleted');
      print('  - Head movement completed: $headMovementCompleted');
      print('  - Blink image path: $blinkImagePath');
      print('  - Move closer image path: $moveCloserImagePath');
      print('  - Head movement image path: $headMovementImagePath');
      
      return {
        'blinkCompleted': blinkCompleted,
        'moveCloserCompleted': moveCloserCompleted,
        'headMovementCompleted': headMovementCompleted,
        'blinkCompletedAt': blinkCompletedAt,
        'moveCloserCompletedAt': moveCloserCompletedAt,
        'headMovementCompletedAt': headMovementCompletedAt,
        'blinkImagePath': blinkImagePath,
        'moveCloserImagePath': moveCloserImagePath,
        'headMovementImagePath': headMovementImagePath,
        'blinkMetrics': blinkMetrics,
        'moveCloserMetrics': moveCloserMetrics,
        'headMovementMetrics': headMovementMetrics,
        'blinkFeatures': blinkFeatures,
        'moveCloserFeatures': moveCloserFeatures,
        'headMovementFeatures': headMovementFeatures,
        'verificationTimestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error retrieving face verification data: $e');
      // Return basic completion status if data retrieval fails
      return {
        'blinkCompleted': true,
        'moveCloserCompleted': true,
        'headMovementCompleted': true,
        'verificationTimestamp': DateTime.now().toIso8601String(),
        'error': 'Failed to retrieve detailed face verification data',
      };
    }
  }

  Future<void> _submitForm() async {
    if (!mounted) return;
    
    if (_formKey.currentState!.validate() &&
        gender != null &&
        _selectedDate != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get signup data from OTP verification (stored in SharedPreferences)
        final prefs = await SharedPreferences.getInstance();
        final userEmail = prefs.getString('signup_email') ?? '';
        final userPhone = prefs.getString('signup_phone') ?? '';
        
        if (userEmail.isEmpty && userPhone.isEmpty) {
          throw Exception('No signup data found. Please restart the signup process.');
        }
        
        print('✅ Submitting signup form for: ${userEmail.isNotEmpty ? userEmail : userPhone}');
        
        // Final duplicate check before saving
        print('🔍 Final duplicate check before saving user data...');
        
        if (userEmail.isNotEmpty) {
          final emailCheck = await UserCheckService.checkUserExists(userEmail);
          if (emailCheck['exists']) {
            throw Exception('This email is already registered. Please use a different email or try logging in.');
          }
        }
        
        if (userPhone.isNotEmpty) {
          final phoneCheck = await UserCheckService.checkUserExists(userPhone);
          if (phoneCheck['exists']) {
            throw Exception('This phone number is already registered. Please use a different phone number or try logging in.');
          }
        }
        
        print('✅ Final duplicate check passed - proceeding with user registration');
        
        // Parse age safely
        final age = int.tryParse(ageController.text);
        if (age == null) {
          throw Exception('Invalid age format');
        }

        print('🔄 Starting to save user data to Firestore...');
        print('👤 Username: ${usernameController.text.trim()}');
        print('🏠 Address: ${addressController.text.trim()}');

        // Generate a unique user ID for signup
        final userId = 'user_${DateTime.now().millisecondsSinceEpoch}_${userEmail.isNotEmpty ? userEmail.split('@')[0] : userPhone.replaceAll('+', '').replaceAll(' ', '')}';
        
        // Store the user ID and username in SharedPreferences for later verification checks
        await prefs.setString('signup_user_id', userId);
        await prefs.setString('signup_user_name', usernameController.text.trim());
        print('🆔 Stored signup user ID: $userId');
        print('👤 Stored signup username: ${usernameController.text.trim()}');
        
        // Get face verification data
        final faceData = await _getFaceVerificationDataWithoutUpload();
        
        // Store face features for face login authentication
        final faceFeatures = _extractFaceFeaturesForLogin(faceData);
        print('🔍 Face features extracted for database storage:');
        print('  - Feature count: ${faceFeatures['featureCount']}');
        print('  - Extracted from: ${faceFeatures['extractedFrom']}');
        print('  - Feature vector length: ${faceFeatures['featureVector']?.length ?? 0}');
        
        // Get profile picture URL from SharedPreferences if available
        final profilePhotoUrl = prefs.getString('profile_photo_url') ?? '';
        
        final userData = {
          'uid': userId,
          'phoneNumber': userPhone,
          'email': userEmail,
          'username': usernameController.text.trim(),
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'age': age,
          'address': addressController.text.trim(),
          'birthday': _selectedDate!,
          'gender': gender!,
          'profilePictureUrl': profilePhotoUrl,
          'verificationStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'faceData': faceData,
          'faceFeatures': faceFeatures, // For face login authentication
          'isSignupUser': true, // Mark as signup user (not authenticated yet)
        };
        
        print('🔍 User data being saved to Firestore:');
        print('  - User ID: $userId');
        print('  - Email: $userEmail');
        print('  - Phone: $userPhone');
        print('  - Username: ${usernameController.text.trim()}');
        print('  - First Name: ${firstNameController.text.trim()}');
        print('  - Last Name: ${lastNameController.text.trim()}');
        print('  - Age: $age');
        print('  - Address: ${addressController.text.trim()}');
        print('  - Birthday: $_selectedDate');
        print('  - Gender: $gender');
        print('  - Face data keys: ${faceData.keys.toList()}');
        print('  - Face features keys: ${faceFeatures.keys.toList()}');
        
        await FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'marketsafe',
        )
            .collection('users')
            .doc(userId)
            .set(userData);

        print('✅ User data saved successfully to Firestore with signup ID: $userId');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Form Submitted Successfully!"),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate after a short delay to ensure the snackbar is shown
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AddProfilePhotoScreen()),
              );
            }
          });
        }
      } catch (e) {
        print('Error submitting form: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please fill in all required fields"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Extract face features for face login authentication
  Map<String, dynamic> _extractFaceFeaturesForLogin(Map<String, dynamic> faceData) {
    try {
      print('🔍 Extracting face features for login authentication...');
      
      // Get the best face features from the three verification steps
      final blinkFeatures = faceData['blinkFeatures'] ?? '';
      final moveCloserFeatures = faceData['moveCloserFeatures'] ?? '';
      final headMovementFeatures = faceData['headMovementFeatures'] ?? '';
      
      print('  - Blink features: "$blinkFeatures"');
      print('  - Move closer features: "$moveCloserFeatures"');
      print('  - Head movement features: "$headMovementFeatures"');
      
      // Use the most complete feature set (prefer head movement as it's the last step)
      String bestFeatures = headMovementFeatures.isNotEmpty ? headMovementFeatures : 
                           moveCloserFeatures.isNotEmpty ? moveCloserFeatures : 
                           blinkFeatures;
      
      print('  - Best features selected: ${bestFeatures.isNotEmpty ? 'YES' : 'NO'}');
      print('  - Best features length: ${bestFeatures.length}');
      
      // Parse features if they exist
      List<double> featureVector = [];
      if (bestFeatures.isNotEmpty) {
        try {
          featureVector = bestFeatures.split(',').map((f) => double.tryParse(f) ?? 0.0).toList();
          print('  - Parsed feature vector length: ${featureVector.length}');
          print('  - Sample features: ${featureVector.take(5).toList()}');
        } catch (e) {
          print('⚠️ Error parsing face features: $e');
        }
      } else {
        print('⚠️ No face features found in any verification step');
      }
      
      final result = {
        'featureVector': featureVector,
        'featureCount': featureVector.length,
        'extractedFrom': bestFeatures.isNotEmpty ? 'face_verification' : 'none',
        'extractionTimestamp': DateTime.now().toIso8601String(),
      };
      
      print('✅ Face features extraction result:');
      print('  - Feature count: ${result['featureCount']}');
      print('  - Feature vector: ${featureVector.take(5).toList()}');
      print('  - Extracted from: ${result['extractedFrom']}');
      
      return result;
    } catch (e) {
      print('❌ Error extracting face features for login: $e');
      return {
        'featureVector': <double>[],
        'featureCount': 0,
        'extractedFrom': 'error',
        'extractionTimestamp': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF2B0000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 17),
                  const Text(
                    "FILL OUT THE FOLLOWING",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildTextField("Username", usernameController),
                        _buildTextField("First Name", firstNameController),
                        _buildTextField("Last Name", lastNameController),
                        _buildTextField(
                          "Age",
                          ageController,
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField("Address", addressController),
                        const SizedBox(height: 16),

                        // Birthday Picker
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Birthday",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime(2000),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );

                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                width: double.infinity, // ✅ full width
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: Text(
                                  _selectedDate == null
                                      ? "Select your birthday"
                                      : "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedDate == null
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        const Text(
                          "Gender",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Radio<String>(
                              value: "Male",
                              groupValue: gender,
                              onChanged: (value) {
                                setState(() {
                                  gender = value;
                                });
                              },
                            ),
                            const Text("Male"),
                            const SizedBox(width: 20),
                            Radio<String>(
                              value: "Female",
                              groupValue: gender,
                              onChanged: (value) {
                                setState(() {
                                  gender = value;
                                });
                              },
                            ),
                            const Text("Female"),
                          ],
                        ),

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 50,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "SIGN UP",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ],
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

  // ✅ Updated with Username validation
  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "$label is required";
          }

          if (label == "Username" && value.length < 8) {
            return "Username must be at least 8 characters long";
          }

          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: const UnderlineInputBorder(),
        ),
      ),
    );
  }
}
