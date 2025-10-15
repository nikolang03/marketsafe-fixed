import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../widgets/image_swiper.dart';
import 'edit_product_screen.dart';

class ProductPreviewScreen extends StatefulWidget {
  final Product product;
  final VoidCallback? onProductUpdated;

  const ProductPreviewScreen({
    super.key,
    required this.product,
    this.onProductUpdated,
  });

  @override
  State<ProductPreviewScreen> createState() => _ProductPreviewScreenState();
}

class _ProductPreviewScreenState extends State<ProductPreviewScreen> {
  late Product _currentProduct;
  String? _currentUserId;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _getCurrentUserId();
  }

  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('current_user_id') ?? 
                   prefs.getString('signup_user_id');
    setState(() {
      _currentUserId = userId;
    });
    return userId;
  }

  bool get _isOwner => _currentUserId == _currentProduct.sellerId;

  Future<void> _editProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(product: _currentProduct),
      ),
    );
    
    if (result == true && widget.onProductUpdated != null) {
      widget.onProductUpdated!();
    }
  }

  Future<void> _deleteProduct() async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Delete Product',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this product? This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      setState(() {
        _isDeleting = true;
      });

      try {
        final success = await ProductService.deleteProduct(_currentProduct.id);
        
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate back and refresh
            Navigator.pop(context);
            if (widget.onProductUpdated != null) {
              widget.onProductUpdated!();
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete product'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5C0000),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Product Preview',
          style: TextStyle(color: Colors.white),
        ),
        actions: _isOwner ? [
          IconButton(
            onPressed: _isDeleting ? null : _editProduct,
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Product',
          ),
          IconButton(
            onPressed: _isDeleting ? null : _deleteProduct,
            icon: _isDeleting 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Product',
          ),
        ] : null,
      ),
      body: _isDeleting
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Images
                  if (_currentProduct.imageUrls.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: ImageSwiper(
                        imageUrls: _currentProduct.imageUrls,
                        height: 300,
                      ),
                    )
                  else
                    Container(
                      height: 300,
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 64,
                        ),
                      ),
                    ),
                  
                  // Product Details
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _currentProduct.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '₱${_currentProduct.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Category and Condition
                        Row(
                          children: [
                            _buildInfoChip(
                              Icons.category,
                              _currentProduct.category,
                              Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            _buildInfoChip(
                              Icons.verified,
                              _currentProduct.condition,
                              Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            _buildInfoChip(
                              Icons.visibility,
                              '${_currentProduct.views} views',
                              Colors.purple,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Description
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentProduct.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Seller Info
                        const Text(
                          'Seller Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: _currentProduct.sellerProfilePictureUrl != null
                                  ? NetworkImage(_currentProduct.sellerProfilePictureUrl!)
                                  : null,
                              child: _currentProduct.sellerProfilePictureUrl == null
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentProduct.sellerName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_currentProduct.sellerUsername != null)
                                    Text(
                                      '@${_currentProduct.sellerUsername}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Product Status
                        if (_currentProduct.status != 'active')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _currentProduct.status == 'sold' 
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _currentProduct.status == 'sold' 
                                    ? Colors.green
                                    : Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _currentProduct.status == 'sold' 
                                      ? Icons.check_circle
                                      : Icons.pause_circle,
                                  color: _currentProduct.status == 'sold' 
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Status: ${_currentProduct.status.toUpperCase()}',
                                  style: TextStyle(
                                    color: _currentProduct.status == 'sold' 
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 20),
                        
                        // Posted Date
                        Text(
                          'Posted on ${_formatDate(_currentProduct.createdAt)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
