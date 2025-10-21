import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_service.dart';

class ProductOfferService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a product offer and send notification to seller
  static Future<bool> createOffer({
    required String productId,
    required String buyerId,
    required int offerAmount,
    String? message,
  }) async {
    try {
      // Get product details
      final productDoc = await _firestore
          .collection('products')
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final productData = productDoc.data()!;
      final sellerId = productData['userId'];
      final productTitle = productData['title'] ?? 'Unknown Product';

      // Create offer document
      final offerData = {
        'productId': productId,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'offerAmount': offerAmount,
        'message': message ?? '',
        'status': 'pending', // pending, accepted, rejected, withdrawn
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('offers')
          .add(offerData);

      // Send message to seller
      final conversationId = await MessageService.getOrCreateConversation(
        buyerId,
        sellerId,
      );

      final offerMessage = message != null 
          ? 'You got an offer for "$productTitle" - PHP $offerAmount\n\nMessage: $message'
          : 'You got an offer for "$productTitle" - PHP $offerAmount';

      await MessageService.sendMessage(
        conversationId: conversationId,
        senderId: buyerId,
        text: offerMessage,
      );

      return true;
    } catch (e) {
      print('Error creating offer: $e');
      return false;
    }
  }

  /// Get all offers for a specific product
  static Stream<List<Map<String, dynamic>>> getProductOffers(String productId) {
    return _firestore
        .collection('offers')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  /// Get all offers made by a user
  static Stream<List<Map<String, dynamic>>> getUserOffers(String userId) {
    return _firestore
        .collection('offers')
        .where('buyerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  /// Get all offers received by a user (for their products)
  static Stream<List<Map<String, dynamic>>> getReceivedOffers(String userId) {
    return _firestore
        .collection('offers')
        .where('sellerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList());
  }

  /// Update offer status (accept, reject, withdraw)
  static Future<bool> updateOfferStatus({
    required String offerId,
    required String status, // accepted, rejected, withdrawn
    String? message,
  }) async {
    try {
      await _firestore
          .collection('offers')
          .doc(offerId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (message != null) 'responseMessage': message,
      });

      // If offer is accepted, mark other offers for the same product as rejected
      if (status == 'accepted') {
        final offerDoc = await _firestore
            .collection('offers')
            .doc(offerId)
            .get();
        
        if (offerDoc.exists) {
          final offerData = offerDoc.data()!;
          final productId = offerData['productId'];
          
          // Reject all other pending offers for this product
          final otherOffersQuery = await _firestore
              .collection('offers')
              .where('productId', isEqualTo: productId)
              .where('status', isEqualTo: 'pending')
              .get();

          for (var doc in otherOffersQuery.docs) {
            if (doc.id != offerId) {
              await doc.reference.update({
                'status': 'rejected',
                'updatedAt': FieldValue.serverTimestamp(),
                'rejectionReason': 'Another offer was accepted',
              });
            }
          }
        }
      }

      return true;
    } catch (e) {
      print('Error updating offer status: $e');
      return false;
    }
  }

  /// Get offer details with user information
  static Future<Map<String, dynamic>?> getOfferDetails(String offerId) async {
    try {
      final offerDoc = await _firestore
          .collection('offers')
          .doc(offerId)
          .get();

      if (!offerDoc.exists) {
        return null;
      }

      final offerData = offerDoc.data()!;
      
      // Get buyer information
      final buyerData = await MessageService.getUserData(offerData['buyerId']);
      
      // Get seller information
      final sellerData = await MessageService.getUserData(offerData['sellerId']);
      
      // Get product information
      final productDoc = await _firestore
          .collection('products')
          .doc(offerData['productId'])
          .get();
      
      final productData = productDoc.exists ? productDoc.data()! : {};

      return {
        'id': offerId,
        ...offerData,
        'buyer': buyerData,
        'seller': sellerData,
        'product': productData,
      };
    } catch (e) {
      print('Error getting offer details: $e');
      return null;
    }
  }
}
