import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';

class ApprovalNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );
  
  // Cache to prevent running too frequently
  static final Map<String, DateTime> _lastRunTimes = {};

  /// Force check for approval/rejection notifications (bypasses rate limiting)
  static Future<void> forceCheckNotifications(String userId) async {
    print('🔄 Force checking notifications for user: $userId');
    
    // Check if notification creation is disabled for this user
    final isDisabled = await NotificationService.isNotificationCreationDisabled(userId);
    if (isDisabled) {
      print('🚫 Notification creation is disabled for user: $userId - skipping force check');
      return;
    }
    
    // Clear the rate limiting for this user
    _lastRunTimes.remove(userId);
    _lastRunTimes.remove('${userId}_rejection');
    
    // Run the checks with enhanced duplicate prevention
    await _checkAndCreateApprovalNotificationsWithDupes(userId);
    await _checkAndCreateRejectionNotificationsWithDupes(userId);
  }

  /// Check for approval notifications with enhanced duplicate prevention
  static Future<void> _checkAndCreateApprovalNotificationsWithDupes(String userId) async {
    try {
      print('🔍 Force checking for newly approved products for user: $userId');
      
      // Only check products approved in the last 7 days to avoid creating notifications for old products
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Get ALL existing notifications for this user to prevent any duplicates
      final allNotificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      
      final existingProductIds = allNotificationsQuery.docs
          .where((doc) => doc.data()['status'] == 'approved')
          .map((doc) => doc.data()['productId'] as String)
          .toSet();
      
      print('🔍 Found ${existingProductIds.length} existing approval notifications');
      print('🔍 Existing approval product IDs: $existingProductIds');
      
      // Get all approved products for this user
      final productsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: userId)
          .where('moderationStatus', isEqualTo: 'approved')
          .get();

      print('🔍 Found ${productsQuery.docs.length} approved products for user');
      
      int newNotificationsCreated = 0;
      
      for (var productDoc in productsQuery.docs) {
        final productData = productDoc.data();
        final productId = productDoc.id;
        final productTitle = productData['title'] ?? 'Untitled Product';
        final reviewedAt = productData['reviewedAt'] as Timestamp?;
        
        // Filter by date in code instead of query
        if (reviewedAt == null) {
          print('🔍 Product $productId has no reviewedAt timestamp, skipping');
          continue;
        }
        
        final reviewedDate = reviewedAt.toDate();
        if (reviewedDate.isBefore(weekAgo)) {
          print('🔍 Product $productId was approved too long ago (${reviewedDate}), skipping');
          continue;
        }
        
        print('🔍 Checking product: $productId, Title: $productTitle, Reviewed: $reviewedDate');

        // Check if product doesn't have a notification yet
        if (!existingProductIds.contains(productId)) {
          print('✅ Found approved product without notification: $productTitle');
          print('🔔 Creating approval notification for product: $productTitle');
          
          // Create the approval notification
          await NotificationService.createProductNotification(
            userId: userId,
            productId: productId,
            productTitle: productTitle,
            status: 'approved',
          );
          
          print('✅ Approval notification created for product: $productTitle');
          existingProductIds.add(productId); // Add to set to prevent duplicates in same run
          newNotificationsCreated++;
        } else {
          print('ℹ️ Approval notification already exists for product: $productTitle');
        }
      }
      
      print('✅ Force check completed. Created $newNotificationsCreated new approval notifications');
    } catch (e) {
      print('❌ Error in force approval notification check: $e');
    }
  }

  /// Check for rejection notifications with enhanced duplicate prevention
  static Future<void> _checkAndCreateRejectionNotificationsWithDupes(String userId) async {
    try {
      print('🔍 Force checking for newly rejected products for user: $userId');
      
      // Only check products rejected in the last 7 days to avoid creating notifications for old products
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Get ALL existing notifications for this user to prevent any duplicates
      final allNotificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      
      final existingProductIds = allNotificationsQuery.docs
          .where((doc) => doc.data()['status'] == 'rejected')
          .map((doc) => doc.data()['productId'] as String)
          .toSet();
      
      print('🔍 Found ${existingProductIds.length} existing rejection notifications');
      print('🔍 Existing rejection product IDs: $existingProductIds');
      
      // Get all rejected products for this user
      final productsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: userId)
          .where('moderationStatus', isEqualTo: 'rejected')
          .get();

      print('🔍 Found ${productsQuery.docs.length} rejected products for user');
      
      int newNotificationsCreated = 0;
      
      for (var productDoc in productsQuery.docs) {
        final productData = productDoc.data();
        final productId = productDoc.id;
        final productTitle = productData['title'] ?? 'Untitled Product';
        final rejectionReason = productData['rejectionReason'] ?? '';
        final reviewedAt = productData['reviewedAt'] as Timestamp?;
        
        // Filter by date in code instead of query
        if (reviewedAt == null) {
          print('🔍 Product $productId has no reviewedAt timestamp, skipping');
          continue;
        }
        
        final reviewedDate = reviewedAt.toDate();
        if (reviewedDate.isBefore(weekAgo)) {
          print('🔍 Product $productId was rejected too long ago (${reviewedDate}), skipping');
          continue;
        }
        
        print('🔍 Checking product: $productId, Title: $productTitle, Reviewed: $reviewedDate');

        // Check if product doesn't have a notification yet
        if (!existingProductIds.contains(productId)) {
          print('❌ Found rejected product without notification: $productTitle');
          print('🔔 Creating rejection notification for product: $productTitle');
          
          // Create the rejection notification
          await NotificationService.createProductNotification(
            userId: userId,
            productId: productId,
            productTitle: productTitle,
            status: 'rejected',
            rejectionReason: rejectionReason,
          );
          
          print('✅ Rejection notification created for product: $productTitle');
          existingProductIds.add(productId); // Add to set to prevent duplicates in same run
          newNotificationsCreated++;
        } else {
          print('ℹ️ Rejection notification already exists for product: $productTitle');
        }
      }
      
      print('✅ Force check completed. Created $newNotificationsCreated new rejection notifications');
    } catch (e) {
      print('❌ Error in force rejection notification check: $e');
    }
  }

  /// Check for newly approved products and create notifications
  static Future<void> checkAndCreateApprovalNotifications(String userId) async {
    try {
      // Check if notification creation is disabled for this user
      final isDisabled = await NotificationService.isNotificationCreationDisabled(userId);
      if (isDisabled) {
        print('🚫 Notification creation is disabled for user: $userId');
        return;
      }
      
      // Check if we've run this recently (within 30 seconds) to prevent spam
      final now = DateTime.now();
      final lastRun = _lastRunTimes[userId];
      if (lastRun != null && now.difference(lastRun).inSeconds < 30) {
        print('⏭️ Skipping approval notification check - ran recently (${now.difference(lastRun).inSeconds}s ago)');
        return;
      }
      
      _lastRunTimes[userId] = now;
      print('🔍 Checking for newly approved products for user: $userId');
      
      // Only check products approved in the last 7 days to avoid creating notifications for old products
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // First, get all existing notifications to avoid duplicates
      final existingNotificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();
      
      final existingProductIds = existingNotificationsQuery.docs
          .map((doc) => doc.data()['productId'] as String)
          .toSet();
      
      print('🔍 Found ${existingProductIds.length} existing approval notifications');
      
      // Get all approved products for this user (we'll filter by date in code)
      final productsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: userId)
          .where('moderationStatus', isEqualTo: 'approved')
          .get();

      print('🔍 Found ${productsQuery.docs.length} recently approved products for user');
      
      // Debug: Print all approved products found
      for (var doc in productsQuery.docs) {
        final data = doc.data();
        print('🔍 Approved product: ${doc.id} - ${data['title']} - reviewedAt: ${data['reviewedAt']}');
      }

      for (var productDoc in productsQuery.docs) {
        final productData = productDoc.data();
        final productId = productDoc.id;
        final productTitle = productData['title'] ?? 'Untitled Product';
        final reviewedAt = productData['reviewedAt'] as Timestamp?;
        
        // Filter by date in code instead of query
        if (reviewedAt == null) {
          print('🔍 Product $productId has no reviewedAt timestamp, skipping');
          continue;
        }
        
        final reviewedDate = reviewedAt.toDate();
        if (reviewedDate.isBefore(weekAgo)) {
          print('🔍 Product $productId was approved too long ago (${reviewedDate}), skipping');
          continue;
        }
        
        print('🔍 Recently approved product: $productId, Title: $productTitle, Reviewed: $reviewedDate');

        // Check if product doesn't have a notification yet
        if (!existingProductIds.contains(productId)) {
          print('✅ Found recently approved product without notification: $productTitle');
          print('🔔 Creating approval notification for product: $productTitle');
          
          // Create the approval notification
          await NotificationService.createProductNotification(
            userId: userId,
            productId: productId,
            productTitle: productTitle,
            status: 'approved',
          );
          
          print('✅ Approval notification created for product: $productTitle');
          
          // Add to existing set to avoid duplicates in this run
          existingProductIds.add(productId);
        } else {
          print('ℹ️ Approval notification already exists for product: $productTitle');
        }
      }
      
      print('✅ Finished checking for approval notifications');
    } catch (e) {
      print('❌ Error checking for approval notifications: $e');
    }
  }

  /// Check for newly rejected products and create notifications
  static Future<void> checkAndCreateRejectionNotifications(String userId) async {
    try {
      // Check if notification creation is disabled for this user
      final isDisabled = await NotificationService.isNotificationCreationDisabled(userId);
      if (isDisabled) {
        print('🚫 Notification creation is disabled for user: $userId');
        return;
      }
      
      // Check if we've run this recently (within 30 seconds) to prevent spam
      final now = DateTime.now();
      final lastRun = _lastRunTimes['${userId}_rejection'];
      if (lastRun != null && now.difference(lastRun).inSeconds < 30) {
        print('⏭️ Skipping rejection notification check - ran recently (${now.difference(lastRun).inSeconds}s ago)');
        return;
      }
      
      _lastRunTimes['${userId}_rejection'] = now;
      print('🔍 Checking for newly rejected products for user: $userId');
      
      // Only check products rejected in the last 7 days to avoid creating notifications for old products
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // First, get all existing notifications to avoid duplicates
      final existingNotificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'rejected')
          .get();
      
      final existingProductIds = existingNotificationsQuery.docs
          .map((doc) => doc.data()['productId'] as String)
          .toSet();
      
      print('🔍 Found ${existingProductIds.length} existing rejection notifications');
      
      // Get all rejected products for this user (we'll filter by date in code)
      final productsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: userId)
          .where('moderationStatus', isEqualTo: 'rejected')
          .get();

      print('🔍 Found ${productsQuery.docs.length} recently rejected products for user');
      
      // Debug: Print all rejected products found
      for (var doc in productsQuery.docs) {
        final data = doc.data();
        print('🔍 Rejected product: ${doc.id} - ${data['title']} - reviewedAt: ${data['reviewedAt']}');
      }

      for (var productDoc in productsQuery.docs) {
        final productData = productDoc.data();
        final productId = productDoc.id;
        final productTitle = productData['title'] ?? 'Untitled Product';
        final rejectionReason = productData['rejectionReason'] ?? '';
        final reviewedAt = productData['reviewedAt'] as Timestamp?;
        
        // Filter by date in code instead of query
        if (reviewedAt == null) {
          print('🔍 Product $productId has no reviewedAt timestamp, skipping');
          continue;
        }
        
        final reviewedDate = reviewedAt.toDate();
        if (reviewedDate.isBefore(weekAgo)) {
          print('🔍 Product $productId was rejected too long ago (${reviewedDate}), skipping');
          continue;
        }
        
        print('🔍 Recently rejected product: $productId, Title: $productTitle, Reviewed: $reviewedDate');

        // Check if product doesn't have a notification yet
        if (!existingProductIds.contains(productId)) {
          print('❌ Found recently rejected product without notification: $productTitle');
          print('🔔 Creating rejection notification for product: $productTitle');
          
          // Create the rejection notification
          await NotificationService.createProductNotification(
            userId: userId,
            productId: productId,
            productTitle: productTitle,
            status: 'rejected',
            rejectionReason: rejectionReason,
          );
          
          print('✅ Rejection notification created for product: $productTitle');
          
          // Add to existing set to avoid duplicates in this run
          existingProductIds.add(productId);
        } else {
          print('ℹ️ Rejection notification already exists for product: $productTitle');
        }
      }
      
      print('✅ Finished checking for rejection notifications');
    } catch (e) {
      print('❌ Error checking for rejection notifications: $e');
    }
  }

  /// Clean up duplicate notifications for a user
  static Future<void> cleanupDuplicateNotifications(String userId) async {
    try {
      print('🧹 Cleaning up duplicate notifications for user: $userId');
      
      // Get all notifications for this user
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      
      print('🧹 Found ${notificationsQuery.docs.length} total notifications for user');
      
      // Group notifications by productId and status
      final Map<String, List<QueryDocumentSnapshot>> groupedNotifications = {};
      
      for (var doc in notificationsQuery.docs) {
        final data = doc.data();
        final productId = data['productId'] as String?;
        final status = data['status'] as String?;
        
        if (productId != null && status != null) {
          final key = '${productId}_$status';
          groupedNotifications.putIfAbsent(key, () => []).add(doc);
        }
      }
      
      int duplicatesRemoved = 0;
      
      // Remove duplicates, keeping the most recent one
      for (var entry in groupedNotifications.entries) {
        final notifications = entry.value;
        if (notifications.length > 1) {
          print('🧹 Found ${notifications.length} duplicate notifications for ${entry.key}');
          
          // Sort by createdAt (most recent first)
          notifications.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          
          // Keep the first (most recent) and delete the rest
          for (int i = 1; i < notifications.length; i++) {
            await _firestore.collection('notifications').doc(notifications[i].id).delete();
            duplicatesRemoved++;
            print('🧹 Removed duplicate notification: ${notifications[i].id}');
          }
        }
      }
      
      print('✅ Cleanup completed. Removed $duplicatesRemoved duplicate notifications');
    } catch (e) {
      print('❌ Error cleaning up duplicate notifications: $e');
    }
  }

  /// Clean up duplicate notifications for a user (old method for compatibility)
  static Future<void> cleanupDuplicateNotificationsOld(String userId) async {
    try {
      print('🧹 Cleaning up duplicate notifications for user: $userId');
      
      // Get all notifications for this user
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      // Group notifications by productId and status
      final Map<String, List<QueryDocumentSnapshot>> groupedNotifications = {};
      
      for (var doc in notificationsQuery.docs) {
        final data = doc.data();
        final productId = data['productId'] as String;
        final status = data['status'] as String;
        final key = '${productId}_$status';
        
        if (!groupedNotifications.containsKey(key)) {
          groupedNotifications[key] = [];
        }
        groupedNotifications[key]!.add(doc);
      }
      
      // Remove duplicates, keeping only the most recent one
      for (var entry in groupedNotifications.entries) {
        final notifications = entry.value;
        if (notifications.length > 1) {
          print('🧹 Found ${notifications.length} duplicate notifications for ${entry.key}');
          
          // Sort by creation time (keep the most recent)
          notifications.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aTime = aData?['createdAt'] as Timestamp?;
            final bTime = bData?['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          
          // Delete all except the first (most recent) one
          for (int i = 1; i < notifications.length; i++) {
            await _firestore.collection('notifications').doc(notifications[i].id).delete();
            print('🗑️ Deleted duplicate notification: ${notifications[i].id}');
          }
        }
      }
      
      print('✅ Finished cleaning up duplicate notifications');
    } catch (e) {
      print('❌ Error cleaning up duplicate notifications: $e');
    }
  }
}
