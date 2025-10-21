import 'package:flutter/material.dart';
import '../services/product_offer_service.dart';
import '../services/message_service.dart';

class ProductOffersScreen extends StatefulWidget {
  final String productId;
  final String currentUserId;

  const ProductOffersScreen({
    Key? key,
    required this.productId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _ProductOffersScreenState createState() => _ProductOffersScreenState();
}

class _ProductOffersScreenState extends State<ProductOffersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF8B0000),
      appBar: AppBar(
        backgroundColor: Color(0xFF8B0000),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Product Offers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ProductOfferService.getProductOffers(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading offers: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final offers = snapshot.data ?? [];

          if (offers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox,
                    size: 64,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No offers yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Offers will appear here when users make them',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return _buildOfferCard(offer);
            },
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final offerAmount = offer['offerAmount'] ?? 0;
    final status = offer['status'] ?? 'pending';
    final message = offer['message'] ?? '';
    final buyerId = offer['buyerId'];

    Color statusColor;
    String statusText;
    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'Accepted';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejected';
        break;
      case 'withdrawn':
        statusColor = Colors.orange;
        statusText = 'Withdrawn';
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'Pending';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with amount and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PHP $offerAmount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Message if any
          if (message.isNotEmpty) ...[
            Text(
              message,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
          ],

          // Buyer info and actions
          Row(
            children: [
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: MessageService.getUserData(buyerId),
                  builder: (context, snapshot) {
                    final buyerData = snapshot.data ?? {'name': 'Unknown User'};
                    return Text(
                      'From: ${buyerData['name']}',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              if (status == 'pending' && offer['sellerId'] == widget.currentUserId) ...[
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _updateOfferStatus(offer['id'], 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _updateOfferStatus(offer['id'], 'rejected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Reject',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateOfferStatus(String offerId, String status) async {
    try {
      final success = await ProductOfferService.updateOfferStatus(
        offerId: offerId,
        status: status,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offer $status successfully'),
            backgroundColor: status == 'accepted' ? Colors.green : Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update offer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
