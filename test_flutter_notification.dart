import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Test function to create a notification using Flutter's format
Future<void> testCreateNotification() async {
  try {
    print('🧪 Testing Flutter notification creation...');
    
    final firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'marketsafe',
    );
    
    final notificationId = 'notification_${DateTime.now().millisecondsSinceEpoch}_flutter_test';
    final userId = 'user_1760401522367_cunanankonifers';
    
    final notification = {
      'id': notificationId,
      'userId': userId,
      'productId': 'test_product_flutter_123',
      'productTitle': 'Flutter Test Product',
      'type': 'product_status',
      'status': 'approved',
      'isRead': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'title': 'Flutter Test Approved! 🎉',
      'message': 'This notification was created using Flutter SDK format',
    };
    
    print('🧪 Creating notification: $notificationId');
    print('🧪 User ID: $userId');
    print('🧪 Database: marketsafe');
    
    await firestore
        .collection('notifications')
        .doc(notificationId)
        .set(notification);
    
    print('✅ Flutter notification created successfully!');
    
    // Now try to fetch it back
    print('🧪 Fetching notification back...');
    final doc = await firestore
        .collection('notifications')
        .doc(notificationId)
        .get();
    
    if (doc.exists) {
      print('✅ Notification found in database: ${doc.data()}');
    } else {
      print('❌ Notification not found in database');
    }
    
  } catch (e) {
    print('❌ Error creating Flutter notification: $e');
  }
}
