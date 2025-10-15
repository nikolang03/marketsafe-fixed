import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/product_service.dart';
import '../models/product_model.dart';

class ProductStatusScreen extends StatefulWidget {
  const ProductStatusScreen({super.key});

  @override
  State<ProductStatusScreen> createState() => _ProductStatusScreenState();
}

class _ProductStatusScreenState extends State<ProductStatusScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUserProducts();
  }

  Future<void> _loadUserProducts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final products = await ProductService.getUserProducts(user.uid);
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Product> get _filteredProducts {
    if (_selectedFilter == 'all') {
      return _products;
    }
    return _products.where((product) => product.moderationStatus == _selectedFilter).toList();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All', _products.length),
                  _buildFilterChip('pending', 'Pending', _products.where((p) => p.moderationStatus == 'pending').length),
                  _buildFilterChip('approved', 'Approved', _products.where((p) => p.moderationStatus == 'approved').length),
                  _buildFilterChip('rejected', 'Rejected', _products.where((p) => p.moderationStatus == 'rejected').length),
                ],
              ),
            ),
          ),
          
          // Products list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _buildProductCard(product);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, int count) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        selectedColor: Colors.red.withOpacity(0.2),
        checkmarkColor: Colors.red,
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    switch (_selectedFilter) {
      case 'pending':
        message = 'No products pending review';
        icon = Icons.hourglass_empty;
        break;
      case 'approved':
        message = 'No approved products';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        message = 'No rejected products';
        icon = Icons.cancel;
        break;
      default:
        message = 'No products found';
        icon = Icons.shopping_cart;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedFilter == 'all')
            ElevatedButton(
              onPressed: () {
                // Navigate to add product screen
                Navigator.pushNamed(context, '/add_product');
              },
              child: const Text('Add Your First Product'),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.category,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status indicator
                Column(
                  children: [
                    Icon(
                      _getStatusIcon(product.moderationStatus),
                      color: _getStatusColor(product.moderationStatus),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(product.moderationStatus),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(product.moderationStatus),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Product description
            Text(
              product.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 12),
            
            // Additional info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Created: ${_formatDate(product.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (product.moderationStatus == 'rejected' && product.rejectionReason != null)
                  TextButton(
                    onPressed: () {
                      _showRejectionReason(product.rejectionReason!);
                    },
                    child: const Text('View Rejection Reason'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectionReason(String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

