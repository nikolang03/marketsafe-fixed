import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/product_model.dart';
import 'notification_service.dart';

class ProductModerationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all products pending moderation
  static Future<List<Product>> getPendingProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('moderationStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting pending products: $e');
      return [];
    }
  }

  /// Get all products by moderation status
  static Future<List<Product>> getProductsByModerationStatus(String status) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('moderationStatus', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting products by status: $e');
      return [];
    }
  }

  /// Approve a product
  static Future<bool> approveProduct(String productId, {String? adminNote}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return false;
      }

      // Get product details before updating
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        print('Product not found: $productId');
        return false;
      }

      final productData = productDoc.data()!;
      final sellerId = productData['sellerId'] ?? '';
      final productTitle = productData['title'] ?? '';

      await _firestore.collection('products').doc(productId).update({
        'moderationStatus': 'approved',
        'reviewedBy': currentUser.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'adminNote': adminNote,
      });

      // Create notification for the seller
      if (sellerId.isNotEmpty) {
        await NotificationService.createProductNotification(
          userId: sellerId,
          productId: productId,
          productTitle: productTitle,
          status: 'approved',
        );
      }

      print('Product approved: $productId');
      return true;
    } catch (e) {
      print('Error approving product: $e');
      return false;
    }
  }

  /// Reject a product
  static Future<bool> rejectProduct(String productId, String rejectionReason, {String? adminNote}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return false;
      }

      // Get product details before updating
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        print('Product not found: $productId');
        return false;
      }

      final productData = productDoc.data()!;
      final sellerId = productData['sellerId'] ?? '';
      final productTitle = productData['title'] ?? '';

      await _firestore.collection('products').doc(productId).update({
        'moderationStatus': 'rejected',
        'reviewedBy': currentUser.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': rejectionReason,
        'adminNote': adminNote,
      });

      // Create notification for the seller
      if (sellerId.isNotEmpty) {
        await NotificationService.createProductNotification(
          userId: sellerId,
          productId: productId,
          productTitle: productTitle,
          status: 'rejected',
          rejectionReason: rejectionReason,
        );
      }

      print('Product rejected: $productId');
      return true;
    } catch (e) {
      print('Error rejecting product: $e');
      return false;
    }
  }

  /// Get product moderation statistics
  static Future<Map<String, int>> getModerationStats() async {
    try {
      final pendingQuery = await _firestore
          .collection('products')
          .where('moderationStatus', isEqualTo: 'pending')
          .get();

      final approvedQuery = await _firestore
          .collection('products')
          .where('moderationStatus', isEqualTo: 'approved')
          .get();

      final rejectedQuery = await _firestore
          .collection('products')
          .where('moderationStatus', isEqualTo: 'rejected')
          .get();

      return {
        'pending': pendingQuery.docs.length,
        'approved': approvedQuery.docs.length,
        'rejected': rejectedQuery.docs.length,
      };
    } catch (e) {
      print('Error getting moderation stats: $e');
      return {'pending': 0, 'approved': 0, 'rejected': 0};
    }
  }

  /// Get products by seller ID with moderation status
  static Future<List<Product>> getProductsBySeller(String sellerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error getting products by seller: $e');
      return [];
    }
  }

  /// Listen to moderation status changes for a specific product
  static Stream<Product?> listenToProductModerationStatus(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .map((doc) => doc.exists ? Product.fromDocument(doc) : null);
  }

  /// Listen to all pending products for admin dashboard
  static Stream<List<Product>> listenToPendingProducts() {
    return _firestore
        .collection('products')
        .where('moderationStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromDocument(doc))
            .toList());
  }

  /// Get moderation history for a product
  static Future<Map<String, dynamic>?> getProductModerationHistory(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'moderationStatus': data['moderationStatus'],
        'reviewedBy': data['reviewedBy'],
        'reviewedAt': data['reviewedAt'],
        'rejectionReason': data['rejectionReason'],
        'adminNote': data['adminNote'],
      };
    } catch (e) {
      print('Error getting moderation history: $e');
      return null;
    }
  }

  /// Bulk approve products
  static Future<bool> bulkApproveProducts(List<String> productIds, {String? adminNote}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return false;
      }

      final batch = _firestore.batch();
      
      // Get product details for notifications
      final List<Map<String, String>> notificationData = [];
      
      for (String productId in productIds) {
        final productDoc = await _firestore.collection('products').doc(productId).get();
        if (productDoc.exists) {
          final productData = productDoc.data()!;
          notificationData.add({
            'sellerId': productData['sellerId'] ?? '',
            'productTitle': productData['title'] ?? '',
            'productId': productId,
          });
        }
        
        final docRef = _firestore.collection('products').doc(productId);
        batch.update(docRef, {
          'moderationStatus': 'approved',
          'reviewedBy': currentUser.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'adminNote': adminNote,
        });
      }

      await batch.commit();
      
      // Create notifications for all approved products
      for (var data in notificationData) {
        if (data['sellerId']!.isNotEmpty) {
          await NotificationService.createProductNotification(
            userId: data['sellerId']!,
            productId: data['productId']!,
            productTitle: data['productTitle']!,
            status: 'approved',
          );
        }
      }
      
      print('Bulk approved ${productIds.length} products');
      return true;
    } catch (e) {
      print('Error bulk approving products: $e');
      return false;
    }
  }

  /// Bulk reject products
  static Future<bool> bulkRejectProducts(List<String> productIds, String rejectionReason, {String? adminNote}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return false;
      }

      final batch = _firestore.batch();
      
      // Get product details for notifications
      final List<Map<String, String>> notificationData = [];
      
      for (String productId in productIds) {
        final productDoc = await _firestore.collection('products').doc(productId).get();
        if (productDoc.exists) {
          final productData = productDoc.data()!;
          notificationData.add({
            'sellerId': productData['sellerId'] ?? '',
            'productTitle': productData['title'] ?? '',
            'productId': productId,
          });
        }
        
        final docRef = _firestore.collection('products').doc(productId);
        batch.update(docRef, {
          'moderationStatus': 'rejected',
          'reviewedBy': currentUser.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'rejectionReason': rejectionReason,
          'adminNote': adminNote,
        });
      }

      await batch.commit();
      
      // Create notifications for all rejected products
      for (var data in notificationData) {
        if (data['sellerId']!.isNotEmpty) {
          await NotificationService.createProductNotification(
            userId: data['sellerId']!,
            productId: data['productId']!,
            productTitle: data['productTitle']!,
            status: 'rejected',
            rejectionReason: rejectionReason,
            adminNote: adminNote,
          );
        }
      }
      
      print('Bulk rejected ${productIds.length} products');
      return true;
    } catch (e) {
      print('Error bulk rejecting products: $e');
      return false;
    }
  }

  /// Delete a product
  static Future<bool> deleteProduct(String productId, {String? adminNote}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return false;
      }

      // Get product details before deleting
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        print('Product not found: $productId');
        return false;
      }

      final productData = productDoc.data()!;
      final sellerId = productData['sellerId'] ?? '';
      final productTitle = productData['title'] ?? '';

      // Delete the product
      await _firestore.collection('products').doc(productId).delete();

      // Create notification for the seller
      if (sellerId.isNotEmpty) {
        await NotificationService.createProductNotification(
          userId: sellerId,
          productId: productId,
          productTitle: productTitle,
          status: 'deleted',
          adminNote: adminNote,
        );
      }

      print('Product deleted: $productId');
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  /// Bulk delete products
  static Future<bool> bulkDeleteProducts(List<String> productIds, {String? adminNote}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return false;
      }

      final batch = _firestore.batch();
      
      // Get product details for notifications
      final List<Map<String, String>> notificationData = [];
      
      for (String productId in productIds) {
        final productDoc = await _firestore.collection('products').doc(productId).get();
        if (productDoc.exists) {
          final productData = productDoc.data()!;
          notificationData.add({
            'sellerId': productData['sellerId'] ?? '',
            'productTitle': productData['title'] ?? '',
            'productId': productId,
          });
        }
        
        final docRef = _firestore.collection('products').doc(productId);
        batch.delete(docRef);
      }

      await batch.commit();
      
      // Create notifications for all deleted products
      for (var data in notificationData) {
        if (data['sellerId']!.isNotEmpty) {
          await NotificationService.createProductNotification(
            userId: data['sellerId']!,
            productId: data['productId']!,
            productTitle: data['productTitle']!,
            status: 'deleted',
            adminNote: adminNote,
          );
        }
      }
      
      print('Bulk deleted ${productIds.length} products');
      return true;
    } catch (e) {
      print('Error bulk deleting products: $e');
      return false;
    }
  }
}

