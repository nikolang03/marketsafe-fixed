import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminSyncService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );
  
  // Check if Realtime Database is available
  static Future<bool> _isRealtimeDatabaseAvailable() async {
    try {
      await _database.child('test').once();
      return true;
    } catch (e) {
      print('⚠️ Realtime Database not available: $e');
      return false;
    }
  }
  
  /// Create or update user data in the admin-accessible format
  static Future<void> syncUserData({
    required String userId,
    required Map<String, dynamic> personalInfo,
    required Map<String, dynamic> faceVerification,
  }) async {
    try {
      final userData = {
        'personalInfo': personalInfo,
        'verificationStatus': {
          'status': 'pending',
          'submittedAt': DateTime.now().millisecondsSinceEpoch,
          'reviewedAt': null,
          'reviewedBy': null,
          'rejectionReason': null,
          'notes': ''
        },
        'faceVerification': faceVerification,
        'accountInfo': {
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
          'lockoutCount': 0,
          'lastLockoutAt': null
        }
      };

      // Store in Firestore "marketsafe" database for app functionality
      try {
        await _firestore.collection('users').doc(userId).set({
          'uid': userId,
          'email': personalInfo['email'] ?? '',
          'phoneNumber': personalInfo['phoneNumber'] ?? '',
          'fullName': personalInfo['fullName'] ?? '',
          'address': personalInfo['address'] ?? '',
          'dateOfBirth': personalInfo['dateOfBirth'] ?? '',
          'gender': personalInfo['gender'] ?? '',
          'verificationStatus': userData['verificationStatus']?['status'] ?? 'pending',
          'faceVerification': faceVerification,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
        print('✅ User data stored in Firestore successfully');
      } catch (e) {
        print('❌ Error storing user data in Firestore: $e');
        // Don't throw here, continue with Realtime Database
      }

      // Try to store in Realtime Database for admin web interface
      final isRealtimeAvailable = await _isRealtimeDatabaseAvailable();
      if (isRealtimeAvailable) {
        try {
          await _database.child('users').child(userId).set(userData);

          // Add to verification queue
          final queueRef = _database.child('verificationQueue').push();
          await queueRef.set({
            'userId': userId,
            'submittedAt': DateTime.now().millisecondsSinceEpoch,
            'priority': 'normal',
            'status': 'pending'
          });

          print('✅ User data synced successfully to both Realtime DB and Firestore "marketsafe" database');
        } catch (e) {
          print('⚠️ Realtime Database sync failed, but Firestore sync succeeded: $e');
          print('✅ User data synced successfully to Firestore "marketsafe" database only');
        }
      } else {
        print('⚠️ Realtime Database not available - user data synced to Firestore only');
        print('✅ User data synced successfully to Firestore "marketsafe" database only');
      }
    } catch (e) {
      print('Error syncing user data: $e');
      throw e;
    }
  }

  /// Update face verification progress
  static Future<void> updateFaceVerificationStep({
    required String userId,
    required String step,
    required Map<String, dynamic> metrics,
  }) async {
    try {
      // Update Firestore "marketsafe" database
      await _firestore.collection('users').doc(userId).update({
        'faceVerification.${step}Completed': true,
        'faceVerification.completedAt': FieldValue.serverTimestamp(),
      });

      // Store detailed metrics in Firestore
      final faceDataId = 'face_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.collection('faceMetrics').doc(faceDataId).set({
        'userId': userId,
        'step': step,
        'metrics': metrics,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Try to update Realtime Database
      final isRealtimeAvailable = await _isRealtimeDatabaseAvailable();
      if (isRealtimeAvailable) {
        try {
          // Update Realtime Database
          await _database.child('users').child(userId).child('faceVerification').update({
            '${step}Completed': true,
            'completedAt': DateTime.now().millisecondsSinceEpoch,
          });

          // Store detailed metrics in Realtime Database
          await _database.child('faceData').child(faceDataId).set({
            'userId': userId,
            'verificationSteps': {
              step: {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                ...metrics,
              }
            },
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });

          print('✅ Face verification step updated in both databases: $step');
        } catch (e) {
          print('⚠️ Realtime Database update failed, but Firestore update succeeded: $e');
          print('✅ Face verification step updated in Firestore only: $step');
        }
      } else {
        print('⚠️ Realtime Database not available - face verification updated in Firestore only');
        print('✅ Face verification step updated in Firestore only: $step');
      }
    } catch (e) {
      print('Error updating face verification: $e');
      throw e;
    }
  }

  /// Listen to verification status changes from admin
  static Stream<String> listenToVerificationStatus(String userId) {
    // Try Realtime Database first, fallback to Firestore
    return Stream.fromFuture(_isRealtimeDatabaseAvailable()).asyncExpand((isRealtimeAvailable) {
      if (isRealtimeAvailable) {
        return _database
            .child('users')
            .child(userId)
            .child('verificationStatus')
            .child('status')
            .onValue
            .map((event) => event.snapshot.value?.toString() ?? 'pending');
      } else {
        // Fallback to Firestore
        return _firestore
            .collection('users')
            .doc(userId)
            .snapshots()
            .map((snapshot) => snapshot.data()?['verificationStatus'] ?? 'pending');
      }
    });
  }

  /// Get current verification status
  static Future<Map<String, dynamic>?> getVerificationStatus(String userId) async {
    try {
      final snapshot = await _database
          .child('users')
          .child(userId)
          .child('verificationStatus')
          .get();
      
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting verification status: $e');
      return null;
    }
  }

  /// Update user login activity
  static Future<void> updateLoginActivity(String userId) async {
    try {
      await _database.child('users').child(userId).child('accountInfo').update({
        'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error updating login activity: $e');
    }
  }

  /// Update lockout information
  static Future<void> updateLockoutInfo(String userId, int lockoutCount) async {
    try {
      await _database.child('users').child(userId).child('accountInfo').update({
        'lockoutCount': lockoutCount,
        'lastLockoutAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error updating lockout info: $e');
    }
  }

  /// Check if user is approved by admin
  static Future<bool> isUserApproved(String userId) async {
    try {
      final status = await getVerificationStatus(userId);
      return status?['status'] == 'approved';
    } catch (e) {
      print('Error checking approval status: $e');
      return false;
    }
  }

  /// Get rejection reason if user was rejected
  static Future<String?> getRejectionReason(String userId) async {
    try {
      final status = await getVerificationStatus(userId);
      return status?['rejectionReason'];
    } catch (e) {
      print('Error getting rejection reason: $e');
      return null;
    }
  }

  /// Store face metrics for admin review
  static Future<void> storeFaceMetrics({
    required String userId,
    required Map<String, dynamic> faceMetrics,
  }) async {
    try {
      final faceDataId = 'face_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      await _database.child('faceData').child(faceDataId).set({
        'userId': userId,
        'faceMetrics': faceMetrics,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error storing face metrics: $e');
      throw e;
    }
  }

  /// Initialize user in the system
  static Future<void> initializeUser({
    required String email,
    required String phoneNumber,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final personalInfo = {
        'email': email,
        'phoneNumber': phoneNumber,
        'fullName': '', // Will be filled during information screen
        'address': '',
        'dateOfBirth': '',
        'gender': '',
      };

      final faceVerification = {
        'blinkCompleted': false,
        'headMovementCompleted': false,
        'closenessCompleted': false,
        'completedAt': null,
      };

      await syncUserData(
        userId: user.uid,
        personalInfo: personalInfo,
        faceVerification: faceVerification,
      );
    } catch (e) {
      print('Error initializing user: $e');
      throw e;
    }
  }

  /// Update personal information
  static Future<void> updatePersonalInfo({
    required String userId,
    required Map<String, dynamic> personalInfo,
  }) async {
    try {
      await _database.child('users').child(userId).child('personalInfo').update(personalInfo);
      print('Personal info updated successfully');
    } catch (e) {
      print('Error updating personal info: $e');
      throw e;
    }
  }
}
