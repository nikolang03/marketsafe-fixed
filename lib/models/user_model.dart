import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phoneNumber;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final int age;
  final String address;
  final DateTime birthday;
  final String gender;
  final String verificationStatus;
  final DateTime createdAt;
  final FaceVerificationData faceData;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.address,
    required this.birthday,
    required this.gender,
    required this.verificationStatus,
    required this.createdAt,
    required this.faceData,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      age: data['age'] ?? 0,
      address: data['address'] ?? '',
      birthday: (data['birthday'] as Timestamp).toDate(),
      gender: data['gender'] ?? '',
      verificationStatus: data['verificationStatus'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      faceData: FaceVerificationData.fromMap(data['faceData'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'address': address,
      'birthday': birthday,
      'gender': gender,
      'verificationStatus': verificationStatus,
      'createdAt': createdAt,
      'faceData': faceData.toMap(),
    };
  }
}

class FaceVerificationData {
  final bool blinkCompleted;
  final bool moveCloserCompleted;
  final bool headMovementCompleted;
  final DateTime? blinkCompletedAt;
  final DateTime? moveCloserCompletedAt;
  final DateTime? headMovementCompletedAt;
  final String? faceImageUrl;
  final Map<String, dynamic> faceMetrics;

  FaceVerificationData({
    required this.blinkCompleted,
    required this.moveCloserCompleted,
    required this.headMovementCompleted,
    this.blinkCompletedAt,
    this.moveCloserCompletedAt,
    this.headMovementCompletedAt,
    this.faceImageUrl,
    required this.faceMetrics,
  });

  factory FaceVerificationData.fromMap(Map<String, dynamic> data) {
    return FaceVerificationData(
      blinkCompleted: data['blinkCompleted'] ?? false,
      moveCloserCompleted: data['moveCloserCompleted'] ?? false,
      headMovementCompleted: data['headMovementCompleted'] ?? false,
      blinkCompletedAt: data['blinkCompletedAt'] != null
          ? (data['blinkCompletedAt'] as Timestamp).toDate()
          : null,
      moveCloserCompletedAt: data['moveCloserCompletedAt'] != null
          ? (data['moveCloserCompletedAt'] as Timestamp).toDate()
          : null,
      headMovementCompletedAt: data['headMovementCompletedAt'] != null
          ? (data['headMovementCompletedAt'] as Timestamp).toDate()
          : null,
      faceImageUrl: data['faceImageUrl'],
      faceMetrics: Map<String, dynamic>.from(data['faceMetrics'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blinkCompleted': blinkCompleted,
      'moveCloserCompleted': moveCloserCompleted,
      'headMovementCompleted': headMovementCompleted,
      'blinkCompletedAt': blinkCompletedAt,
      'moveCloserCompletedAt': moveCloserCompletedAt,
      'headMovementCompletedAt': headMovementCompletedAt,
      'faceImageUrl': faceImageUrl,
      'faceMetrics': faceMetrics,
    };
  }
}
