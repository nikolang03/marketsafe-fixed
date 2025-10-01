/*import 'package:cloud_functions/cloud_functions.dart';

class OtpService {
  static final HttpsCallable _sendEmailOtp =
  FirebaseFunctions.instanceFor()
      .httpsCallable('sendEmailOtp');

  static final HttpsCallable _verifyEmailOtp =
  FirebaseFunctions.instanceFor()
      .httpsCallable('verifyEmailOtp');

  static Future<void> sendOtp(String email) async {
    email = email.trim();
    final emailRegex = RegExp(r'\S+@\S+\.\S+');
    if (!emailRegex.hasMatch(email)) {
      throw Exception("Invalid email format.");
    }

    print("DEBUG (Flutter) sending email: $email");

    try {
      // ✅ Send email directly, no extra 'data' key
      final result = await _sendEmailOtp.call({'email': email});

      if (result.data['success'] != true) {
        throw Exception("Failed to send OTP.");
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception("Failed to send OTP: ${e.code} - ${e.message}");
    }
  }

  static Future<bool> verifyOtp(String email, String code) async {
    email = email.trim();
    code = code.trim();

    try {
      final result = await _verifyEmailOtp.call({'email': email, 'code': code});
      return result.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw Exception("Verification failed: ${e.code} - ${e.message}");
    }
  }
}*/
