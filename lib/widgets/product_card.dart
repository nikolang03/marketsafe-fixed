import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/product_model.dart';
import '../screens/edit_product_screen.dart';
import '../screens/product_preview_screen.dart';
import '../screens/user_profile_view_screen.dart';
import '../screens/comments_screen.dart';
import '../services/product_service.dart';
import '../services/follow_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'image_swiper.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onRefresh;
  final double selectedMin;
  final double selectedMax;

  const ProductCard({
    super.key,
    required this.product,
    required this.onRefresh,
    required this.selectedMin,
    required this.selectedMax,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late Product _currentProduct;
  String? _currentUserId;
  bool _isLiking = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _getCurrentUserId();
    _debugSharedPreferences();
    _debugProductInfo();
    _checkFollowStatus();
  }

  // Debug method to check product info on widget init
  void _debugProductInfo() {
    print('🔍 ProductCard init - Product info:');
    print('  - Product ID: ${_currentProduct.id}');
    print('  - Product Title: ${_currentProduct.title}');
    print('  - Seller ID: ${_currentProduct.sellerId}');
    print('  - Seller Name: ${_currentProduct.sellerName}');
    print('  - Seller Profile Picture URL: ${_currentProduct.sellerProfilePictureUrl}');
    print('  - Profile Picture URL is null: ${_currentProduct.sellerProfilePictureUrl == null}');
    print('  - Profile Picture URL is empty: ${_currentProduct.sellerProfilePictureUrl?.isEmpty ?? true}');
    
    // Check if this is the current user's product
    _checkIfCurrentUserProduct();
  }

  // Check if this is the current user's product and debug their profile picture
  Future<void> _checkIfCurrentUserProduct() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id') ?? prefs.getString('signup_user_id');
    
    if (_currentProduct.sellerId == currentUserId) {
      print('🔍 This is current user\'s product - debugging profile picture:');
      print('  - Current user ID: $currentUserId');
      print('  - Profile photo URL from SharedPreferences: ${prefs.getString('profile_photo_url')}');
      print('  - Current user profile picture from SharedPreferences: ${prefs.getString('current_user_profile_picture')}');
      print('  - Signup user profile picture from SharedPreferences: ${prefs.getString('signup_user_profile_picture')}');
    }
  }

  // Debug method to check SharedPreferences on widget init
  Future<void> _debugSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    print('🔍 ProductCard init - All SharedPreferences:');
    final allKeys = prefs.getKeys();
    for (String key in allKeys) {
      print('  - $key: ${prefs.getString(key)}');
    }
  }

  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id');
    final signupUserId = prefs.getString('signup_user_id');
    final userId = currentUserId ?? signupUserId;
    
    print('🔍 ProductCard: Getting current user ID:');
    print('  - current_user_id: $currentUserId');
    print('  - signup_user_id: $signupUserId');
    print('  - Final userId: $userId');
    
    setState(() {
      _currentUserId = userId;
    });
    return userId;
  }

  Future<String> _getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserName = prefs.getString('current_user_name');
    final signupUserName = prefs.getString('signup_user_name');
    
    print('🔍 Getting username:');
    print('  - current_user_name: $currentUserName');
    print('  - signup_user_name: $signupUserName');
    
    // If we have a username in SharedPreferences, use it
    if (currentUserName != null || signupUserName != null) {
      final username = currentUserName ?? signupUserName ?? 'Anonymous';
      print('  - Final username from SharedPreferences: $username');
      return username;
    }
    
    // If no username in SharedPreferences, try to get it from Firestore
    final userId = prefs.getString('current_user_id') ?? prefs.getString('signup_user_id');
    if (userId != null) {
      print('  - No username in SharedPreferences, fetching from Firestore for user: $userId');
      try {
        final userData = await ProductService.getUserData(userId);
        if (userData != null && userData['username'] != null) {
          final username = userData['username'];
          print('  - Found username in Firestore: $username');
          // Store it in SharedPreferences for future use
          await prefs.setString('current_user_name', username);
          return username;
        }
      } catch (e) {
        print('  - Error fetching username from Firestore: $e');
      }
    }
    
    print('  - Final username: Anonymous (fallback)');
    return 'Anonymous';
  }

  // Follow functionality methods
  Future<void> _checkFollowStatus() async {
    if (_currentUserId == null || _currentUserId == _currentProduct.sellerId) return;
    
    try {
      final isFollowing = await FollowService.isFollowing(_currentProduct.sellerId);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    } catch (e) {
      print('❌ Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading || _currentUserId == null || _currentUserId == _currentProduct.sellerId) return;

    setState(() {
      _isFollowLoading = true;
    });

    try {
      bool success;
      if (_isFollowing) {
        success = await FollowService.unfollowUser(_currentProduct.sellerId);
        if (success) {
          setState(() {
            _isFollowing = false;
          });
          _showSuccessSnackBar('Unfollowed ${_currentProduct.sellerName}');
        }
      } else {
        success = await FollowService.followUser(_currentProduct.sellerId);
        if (success) {
          setState(() {
            _isFollowing = true;
          });
          _showSuccessSnackBar('Following ${_currentProduct.sellerName}');
        }
      }

      if (!success) {
        _showErrorSnackBar('Failed to ${_isFollowing ? 'unfollow' : 'follow'} user');
      }
    } catch (e) {
      print('❌ Error toggling follow: $e');
      _showErrorSnackBar('An error occurred');
    } finally {
      if (mounted) {
        setState(() {
          _isFollowLoading = false;
        });
      }
    }
  }

  void _navigateToUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileViewScreen(
          targetUserId: _currentProduct.sellerId,
          targetUsername: _currentProduct.sellerName,
        ),
      ),
    );
  }

  void _navigateToComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          productId: _currentProduct.id,
          productTitle: _currentProduct.title,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String> _getCurrentUserProfilePicture() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Priority 1: Check SharedPreferences for profile photo URL
    final profilePhotoUrl = prefs.getString('profile_photo_url');
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      return profilePhotoUrl;
    }
    
    // Priority 2: Check other SharedPreferences keys
    final currentUserProfilePicture = prefs.getString('current_user_profile_picture');
    final signupUserProfilePicture = prefs.getString('signup_user_profile_picture');
    
    if (currentUserProfilePicture != null && currentUserProfilePicture.isNotEmpty) {
      return currentUserProfilePicture;
    }
    
    if (signupUserProfilePicture != null && signupUserProfilePicture.isNotEmpty) {
      return signupUserProfilePicture;
    }
    
    // Priority 3: Fetch from Firestore
    final userId = prefs.getString('current_user_id') ?? prefs.getString('signup_user_id');
    if (userId != null) {
      try {
        final userData = await ProductService.getUserData(userId);
        if (userData != null && userData['profilePictureUrl'] != null) {
          final profilePicture = userData['profilePictureUrl'];
          // Store it in SharedPreferences for future use
          await prefs.setString('profile_photo_url', profilePicture);
          return profilePicture;
        }
      } catch (e) {
        // Silent fail - return empty string
      }
    }
    
    return '';
  }


  Future<void> _toggleLike() async {
    if (_currentUserId == null || _isLiking) return;
    
    setState(() {
      _isLiking = true;
    });

    try {
      final success = await ProductService.toggleLike(_currentProduct.id, _currentUserId!);
      if (success) {
        // Refresh the product data
        final updatedProduct = await ProductService.getProductById(_currentProduct.id);
        if (updatedProduct != null) {
          setState(() {
            _currentProduct = updatedProduct;
          });
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
    } finally {
      setState(() {
        _isLiking = false;
      });
    }
  }

  void _showCommentsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0000),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _CommentsDialog(
        product: _currentProduct,
        currentUserId: _currentUserId,
        getCurrentUserName: _getCurrentUserName,
        getCurrentUserProfilePicture: _getCurrentUserProfilePicture,
        onCommentAdded: (updatedProduct) {
          setState(() {
            _currentProduct = updatedProduct;
          });
        },
      ),
    );
  }

  void _showProductMenu(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text(
                'Edit Product',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _editProduct(context, product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Product',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteProduct(context, product);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _editProduct(BuildContext context, Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(product: product),
      ),
    ).then((_) {
      // Refresh products after editing
      widget.onRefresh();
    });
  }

  void _deleteProduct(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0000),
        title: const Text(
          'Delete Product',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${product.title}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDelete(product);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    try {
      final success = await ProductService.deleteProduct(product.id);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the product list
        widget.onRefresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete product'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Navigate to product preview screen
  void _navigateToProductPreview() async {
    // Get current user ID directly if not available
    String? userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      print('🔍 ProductCard: _currentUserId is null/empty, fetching directly...');
      userId = await _getCurrentUserId();
      print('🔍 ProductCard: Direct fetch result: $userId');
    }
    
    if (userId == null || userId.isEmpty) {
      print('❌ ProductCard: Current user ID is null or empty, cannot navigate to product preview');
      print('  - _currentUserId: $_currentUserId');
      print('  - Direct fetch result: $userId');
      return;
    }
    
    print('🔍 ProductCard: Navigating to product preview');
    print('  - Current User ID: $userId');
    print('  - Product ID: ${_currentProduct.id}');
    print('  - Seller ID: ${_currentProduct.sellerId}');
    
    // Convert Product to Map for ProductPreviewScreen
    final productMap = {
      'id': _currentProduct.id,
      'title': _currentProduct.title,
      'price': _currentProduct.price.toString(),
      'description': _currentProduct.description,
      'details': _currentProduct.description,
      'date': _formatProductDate(_currentProduct.createdAt),
      'userId': _currentProduct.sellerId,
      'sellerName': _currentProduct.sellerName,
      'imageUrls': _currentProduct.imageUrls,
      'videoUrl': _currentProduct.videoUrl,
      'videoThumbnailUrl': _currentProduct.videoThumbnailUrl,
      'mediaType': _currentProduct.mediaType,
    };
    
    print('  - Product Map: $productMap');
    
    print('🔍 ProductCard: About to navigate to ProductPreviewScreen');
    print('  - Passing currentUserId: $userId');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductPreviewScreen(
          product: productMap,
          currentUserId: userId!,
        ),
      ),
    );
  }

  // Format date for product display
  String _formatProductDate(DateTime? date) {
    if (date == null) return 'Unknown Date';
    
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[date.month - 1]} ${date.day} ${date.year}';
  }

  // Show video player dialog
  void _showVideoPlayer() {
    if (_currentProduct.videoUrl == null || _currentProduct.videoUrl!.isEmpty) {
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VideoPlayerDialog(
        videoUrl: _currentProduct.videoUrl!,
        productTitle: _currentProduct.title,
      ),
    );
  }

  // Build media display based on product type
  Widget _buildMediaDisplay() {
    // If it's a video product, show video thumbnail
    if (_currentProduct.mediaType == 'video' && 
        _currentProduct.videoThumbnailUrl != null && 
        _currentProduct.videoThumbnailUrl!.isNotEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _currentProduct.videoThumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.video_library, color: Colors.white54, size: 50),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),
            // Video play button overlay
            Center(
              child: GestureDetector(
                onTap: () => _showVideoPlayer(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            // Video badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'VIDEO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // For image products, use ImageSwiper
    return ImageSwiper(
      imageUrls: _currentProduct.imageUrls.isNotEmpty 
          ? _currentProduct.imageUrls 
          : (_currentProduct.imageUrl.isNotEmpty
              ? [_currentProduct.imageUrl]
              : []),
      height: 300,
      showDots: true,
      showCounter: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInPriceRange = _currentProduct.price >= widget.selectedMin && 
                          _currentProduct.price <= widget.selectedMax;
    
    print('🔍 ProductCard: ${_currentProduct.title} - Price: ${_currentProduct.price}, Range: ${widget.selectedMin}-${widget.selectedMax}, InRange: $isInPriceRange');
    
    if (!isInPriceRange) {
      print('❌ ProductCard: ${_currentProduct.title} filtered out due to price range');
      return const SizedBox.shrink();
    }
    
    return FutureBuilder<String?>(
      future: _getCurrentUserId(),
      builder: (context, snapshot) {
        final currentUserId = snapshot.data;
        final isOwner = currentUserId == _currentProduct.sellerId;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          color: const Color(0xFF1A0000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: GestureDetector(
                  onTap: isOwner ? null : _navigateToUserProfile,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                    backgroundImage: (_currentProduct.sellerProfilePictureUrl != null && 
                                    _currentProduct.sellerProfilePictureUrl!.isNotEmpty)
                        ? NetworkImage(_currentProduct.sellerProfilePictureUrl!)
                        : null,
                    child: (_currentProduct.sellerProfilePictureUrl == null || 
                           _currentProduct.sellerProfilePictureUrl!.isEmpty)
                        ? Text(
                            _currentProduct.sellerName.isNotEmpty 
                                ? _currentProduct.sellerName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                ),
                title: GestureDetector(
                  onTap: isOwner ? null : _navigateToUserProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentProduct.sellerName.isNotEmpty 
                            ? _currentProduct.sellerName 
                            : 'Unknown Seller',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (_currentProduct.sellerUsername != null && _currentProduct.sellerUsername!.isNotEmpty)
                        Text(
                          '@${_currentProduct.sellerUsername}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOwner) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                        ),
                        onPressed: () => _showProductMenu(context, _currentProduct),
                      ),
                    ] else ...[
                      // Follow Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? Colors.grey[800] : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(80, 32),
                        ),
                        onPressed: _isFollowLoading ? null : _toggleFollow,
                        child: _isFollowLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isFollowing ? 'Following' : 'Follow'),
                      ),
                      const SizedBox(width: 8),
                      // Comments Button
                      IconButton(
                        icon: const Icon(Icons.comment_outlined, color: Colors.white),
                        onPressed: _navigateToComments,
                        tooltip: 'View Comments',
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  _currentProduct.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  "₱${_currentProduct.price.toStringAsFixed(0)}",
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              // Use ImageSwiper for images and separate video widget
              _buildMediaDisplay(),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _currentProduct.likedBy.contains(_currentUserId) 
                            ? Icons.favorite 
                            : Icons.favorite_border,
                        color: _currentProduct.likedBy.contains(_currentUserId) 
                            ? Colors.red 
                            : Colors.white,
                      ),
                      onPressed: _isLiking ? null : _toggleLike,
                    ),
                    Text(
                      "${_currentProduct.likedBy.length}",
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.mode_comment_outlined, color: Colors.white),
                      onPressed: _showCommentsDialog,
                    ),
                    Text(
                      "${_currentProduct.comments.length}",
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: () => _navigateToProductPreview(),
                      child: const Text("MAKE OFFER"),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _DescriptionText(
                  text: _currentProduct.description,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _DescriptionText extends StatefulWidget {
  final String text;

  const _DescriptionText({required this.text});

  @override
  State<_DescriptionText> createState() => _DescriptionTextState();
}

class _DescriptionTextState extends State<_DescriptionText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: const TextStyle(color: Colors.white70),
          maxLines: _isExpanded ? null : 2,
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 100) // Only show "See more" if text is long enough
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? "See less" : "See more",
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentsDialog extends StatefulWidget {
  final Product product;
  final String? currentUserId;
  final Future<String> Function() getCurrentUserName;
  final Future<String> Function() getCurrentUserProfilePicture;
  final Function(Product) onCommentAdded;

  const _CommentsDialog({
    required this.product,
    required this.currentUserId,
    required this.getCurrentUserName,
    required this.getCurrentUserProfilePicture,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<_CommentsDialog> {
  final TextEditingController _commentController = TextEditingController();
  late Product _currentProduct;
  bool _isAddingComment = false;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || widget.currentUserId == null || _isAddingComment) return;

    setState(() {
      _isAddingComment = true;
    });

    try {
      final userName = await widget.getCurrentUserName();
      final userProfilePicture = await widget.getCurrentUserProfilePicture();
      
      
      final success = await ProductService.addComment(
        _currentProduct.id,
        widget.currentUserId!,
        userName,
        userProfilePicture,
        _commentController.text.trim(),
      );

      if (success) {
        _commentController.clear();
        // Refresh the product data
        final updatedProduct = await ProductService.getProductById(_currentProduct.id);
        if (updatedProduct != null) {
          setState(() {
            _currentProduct = updatedProduct;
          });
          widget.onCommentAdded(updatedProduct);
        }
      }
    } catch (e) {
      print('Error adding comment: $e');
    } finally {
      setState(() {
        _isAddingComment = false;
      });
    }
  }

  Future<void> _editComment(String commentId, String currentText) async {
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0000),
        title: const Text('Edit Comment', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: TextEditingController(text: currentText),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter your comment',
            hintStyle: TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, currentText),
            child: const Text('Save', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (newText != null && newText != currentText) {
      await ProductService.editComment(_currentProduct.id, commentId, newText);
      // Refresh the product data
      final updatedProduct = await ProductService.getProductById(_currentProduct.id);
      if (updatedProduct != null) {
        setState(() {
          _currentProduct = updatedProduct;
        });
        widget.onCommentAdded(updatedProduct);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0000),
        title: const Text('Delete Comment', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this comment?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProductService.deleteComment(_currentProduct.id, commentId);
      // Refresh the product data
      final updatedProduct = await ProductService.getProductById(_currentProduct.id);
      if (updatedProduct != null) {
        setState(() {
          _currentProduct = updatedProduct;
        });
        widget.onCommentAdded(updatedProduct);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A0000),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Comments list
              Expanded(
                child: _currentProduct.comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _currentProduct.comments.length,
                        itemBuilder: (context, index) {
                          final comment = _currentProduct.comments[index];
                          final isOwner = comment['userId'] == widget.currentUserId;
                          
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Profile picture
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.white24,
                                      backgroundImage: (comment['userProfilePicture'] != null && 
                                                      comment['userProfilePicture'].toString().isNotEmpty)
                                          ? NetworkImage(comment['userProfilePicture'])
                                          : null,
                                      child: (comment['userProfilePicture'] == null || 
                                             comment['userProfilePicture'].toString().isEmpty)
                                          ? Text(
                                              (comment['userName'] ?? 'A')[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    // Username
                                    Text(
                                      comment['userName'] ?? 'Anonymous',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isOwner)
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 16),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editComment(comment['id'], comment['text']);
                                          } else if (value == 'delete') {
                                            _deleteComment(comment['id']);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit', style: TextStyle(color: Colors.white)),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['text'],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(comment['createdAt']),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Add comment section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        maxLines: null,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isAddingComment ? null : _addComment,
                      icon: _isAddingComment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String productTitle;

  const _VideoPlayerDialog({
    required this.videoUrl,
    required this.productTitle,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      
      _controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.productTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Video player
            Expanded(
              child: _hasError
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'Error loading video',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : !_isInitialized
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        )
                      : GestureDetector(
                          onTap: () {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                            setState(() {});
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AspectRatio(
                                aspectRatio: _controller.value.aspectRatio,
                                child: VideoPlayer(_controller),
                              ),
                              // Play/Pause overlay
                              if (!_controller.value.isPlaying)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              // Progress bar
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: Column(
                                  children: [
                                    // Progress bar
                                    Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: LinearProgressIndicator(
                                        value: _controller.value.duration.inMilliseconds > 0
                                            ? _controller.value.position.inMilliseconds / 
                                              _controller.value.duration.inMilliseconds
                                            : 0.0,
                                        backgroundColor: Colors.transparent,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Duration
                                    Text(
                                      '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
