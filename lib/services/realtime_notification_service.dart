import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'approval_notification_service.dart';

class RealtimeNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );

  /// Trigger notification check for a specific user when admin approves/rejects a product
  static Future<void> triggerNotificationCheck(String userId, String productId, String status) async {
    try {
      print('🔔 Triggering real-time notification check for user: $userId, product: $productId, status: $status');
      
      // Force check for notifications for this user
      await ApprovalNotificationService.forceCheckNotifications(userId);
      
      print('✅ Real-time notification check completed for user: $userId');
    } catch (e) {
      print('❌ Error triggering real-time notification check: $e');
    }
  }

  /// Check for notifications for a specific user (can be called from anywhere in the app)
  static Future<void> checkUserNotifications(String userId) async {
    try {
      print('🔔 Checking notifications for user: $userId');
      
      // Clean up duplicates first
      await ApprovalNotificationService.cleanupDuplicateNotifications(userId);
      
      // Check for new notifications
      await ApprovalNotificationService.forceCheckNotifications(userId);
      
      print('✅ Notification check completed for user: $userId');
    } catch (e) {
      print('❌ Error checking notifications for user: $e');
    }
  }

  /// Force check for notifications when admin approves/rejects products
  static Future<void> forceCheckForUser(String userId) async {
    try {
      print('🔔 Force checking notifications for user: $userId');
      
      // Clean up duplicates first
      await ApprovalNotificationService.cleanupDuplicateNotifications(userId);
      
      // Force check for new notifications
      await ApprovalNotificationService.forceCheckNotifications(userId);
      
      print('✅ Force check completed for user: $userId');
    } catch (e) {
      print('❌ Error force checking notifications for user: $e');
    }
  }

  /// Listen for product status changes and trigger notifications
  static StreamSubscription<QuerySnapshot>? listenForProductChanges() {
    print('🔔 Setting up product change listener for real-time notifications');
    
    return _firestore
        .collection('products')
        .where('moderationStatus', whereIn: ['approved', 'rejected'])
        .snapshots()
        .listen(
          (QuerySnapshot snapshot) {
            print('🔔 Product status change detected: ${snapshot.docs.length} products');
            
            for (var doc in snapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final productId = doc.id;
              final sellerId = data['sellerId'] as String?;
              final status = data['moderationStatus'] as String?;
              final reviewedAt = data['reviewedAt'] as Timestamp?;
              
              if (sellerId != null && status != null && reviewedAt != null) {
                // Check if this is a recent change (within last 5 minutes)
                final reviewTime = reviewedAt.toDate();
                final now = DateTime.now();
                final timeDiff = now.difference(reviewTime).inMinutes;
                
                if (timeDiff <= 5) { // Only process recent changes
                  print('🔔 Recent product status change: $productId -> $status for user: $sellerId');
                  
                  // Trigger notification check for the seller
                  triggerNotificationCheck(sellerId, productId, status);
                }
              }
            }
          },
          onError: (error) {
            print('❌ Product change listener error: $error');
          },
        );
  }
}
