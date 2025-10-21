import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import 'video_upload_service.dart';
import 'notification_service.dart';
import 'network_service.dart';
import 'watermarking_service.dart';

class ProductService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new product with network retry
  static Future<String> createProduct({
    required String title,
    required String description,
    required double price,
    required String condition,
    required String category,
    required List<File> imageFiles,
  }) async {
    return await NetworkService.executeWithRetry(
      () async {
        print('🔄 ProductService: Creating new product...');
        
        // Get current user ID
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('current_user_id') ?? 
                      prefs.getString('signup_user_id') ?? '';
        
        if (userId.isEmpty) {
          throw Exception('User not authenticated');
        }

      // Get user data for seller name and profile picture
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      // Also check SharedPreferences for profile photo URL as fallback
      final prefsProfilePhotoUrl = prefs.getString('profile_photo_url');
      print('🔍 SharedPreferences profile photo URL: $prefsProfilePhotoUrl');
      
      // Get seller name with multiple fallback options
      String sellerName = 'Unknown Seller';
      if (userData != null) {
        if (userData['firstName'] != null && userData['lastName'] != null) {
          sellerName = '${userData['firstName']} ${userData['lastName']}';
        } else if (userData['fullName'] != null) {
          sellerName = userData['fullName'];
        } else if (userData['username'] != null) {
          sellerName = userData['username'];
        }
      }
      
      // Get seller username
      String? sellerUsername;
      if (userData != null) {
        sellerUsername = userData['username'];
      }
      
      // Get seller profile picture URL with fallback to SharedPreferences
      final sellerProfilePictureUrl = userData?['profilePictureUrl'] ?? prefsProfilePhotoUrl;
      
      print('🔍 Product creation - Seller info:');
      print('  - Seller ID: $userId');
      print('  - Seller Name: $sellerName');
      print('  - Seller Username: $sellerUsername');
      print('  - Profile Picture URL: $sellerProfilePictureUrl');
      print('  - User data keys: ${userData?.keys.toList()}');
      print('  - Full user data: $userData');

      // Generate unique product ID
      final productId = 'product_${DateTime.now().millisecondsSinceEpoch}_${userId}';
      
      // Upload multiple images to Firebase Storage with watermarking
      print('📤 Uploading ${imageFiles.length} product images with watermarking...');
      final List<String> imageUrls = [];
      for (int i = 0; i < imageFiles.length; i++) {
        try {
          final imageUrl = await uploadProductImage(
            imageFiles[i], 
            '${productId}_$i',
            username: sellerUsername,
          );
          imageUrls.add(imageUrl);
          print('✅ Image ${i + 1} uploaded with watermark: $imageUrl');
        } catch (e) {
          print('⚠️ Image ${i + 1} upload failed: $e');
          print('⚠️ Skipping failed image upload');
          // Don't add random placeholder - skip this image
          continue;
        }
      }

      // Create product object
      final product = Product(
        id: productId,
        title: title,
        description: description,
        price: price,
        condition: condition,
        category: category,
        sellerId: userId,
        sellerName: sellerName,
        sellerUsername: sellerUsername,
        sellerProfilePictureUrl: sellerProfilePictureUrl,
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '', // First image as primary
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
        status: 'active',
        views: 0,
        isVerified: false,
      );

      // Save product to Firestore
      print('💾 Saving product to database...');
      print('💾 Product ID: $productId');
      print('💾 Product data: ${product.toMap()}');
      
      try {
        await _firestore.collection('products').doc(productId).set(product.toMap());
        print('✅ Product saved to database successfully');
        
        // Verify the product was actually saved
        final verifyDoc = await _firestore.collection('products').doc(productId).get();
        print('🔍 Verification - Product exists after save: ${verifyDoc.exists}');
        if (verifyDoc.exists) {
          print('✅ Product verification successful');
        } else {
          print('❌ Product verification failed - product not found after save');
        }
      } catch (e) {
        print('❌ Error saving product to database: $e');
        throw Exception('Failed to save product to database: $e');
      }
      
      // Update category collection for easier filtering
      await _updateCategoryProducts(category, productId);
      
      // Wait a moment for Firestore to propagate the changes
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Create notification for pending status
      await NotificationService.createProductNotification(
        userId: userId,
        productId: productId,
        productTitle: title,
        status: 'pending',
      );
      
        print('✅ Product created successfully: $productId');
        
        // Don't trigger notification check during product creation
        // Notifications will be created when admin approves/rejects
        print('🔔 Skipping notification check during product creation');
        
        return productId;
      },
      maxRetries: 3,
      retryDelay: const Duration(seconds: 2),
    );
  }

  // Upload product image to Firebase Storage with watermarking
  static Future<String> uploadProductImage(File imageFile, String productId, {String? username}) async {
    try {
      print('📤 Uploading image to Firebase Storage...');
      
      // Validate image authenticity and add watermark
      Uint8List imageBytes;
      final fileBytes = await imageFile.readAsBytes();
      
      // Check if image is from internet
      final isFromInternet = await WatermarkingService.isImageFromInternet(fileBytes);
      if (isFromInternet) {
        throw Exception('Images from internet/web are not allowed. Please use images taken with your device camera.');
      }
      
      // Validate image authenticity
      final validationResult = await WatermarkingService.validateImageAuthenticity(
        imageBytes: fileBytes,
        username: username ?? 'unknown',
        userId: productId.split('_').last, // Extract userId from productId
      );
      
      if (!validationResult['isAuthentic'] && validationResult['warnings'].isNotEmpty) {
        print('⚠️ Image authenticity warnings: ${validationResult['warnings']}');
        // Continue with upload but log warnings
      }
      
      // Watermarking is now handled in the preview screen
      // Images are already watermarked when they reach this point
      imageBytes = fileBytes;
      print('📸 Using pre-watermarked image');
      
      final ref = _storage.ref().child('products').child('$productId.jpg');
      
      // Set metadata to help with upload
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'productId': productId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'watermarked': username != null ? 'true' : 'false',
          'username': username ?? 'unknown',
        },
      );
      
      // Upload watermarked image
      final uploadTask = ref.putData(imageBytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      // Don't throw exception for storage auth warnings, just log them
      if (e.toString().contains('FirebaseNoSignedInUserException') || 
          e.toString().contains('AppCheckProvider') ||
          e.toString().contains('Bad client request')) {
        print('⚠️ Storage authentication warning (upload may still succeed)');
        print('⚠️ This is a known issue with Firebase Storage authentication');
        print('⚠️ The upload might still work despite the warnings');
        
        // Try to get the download URL anyway
        try {
          final ref = _storage.ref().child('products').child('$productId.jpg');
          final downloadUrl = await ref.getDownloadURL();
          print('✅ Image URL retrieved despite auth warnings: $downloadUrl');
          return downloadUrl;
        } catch (e2) {
          print('❌ Could not retrieve image URL: $e2');
          // Don't use random placeholders - throw error instead
          throw Exception('Image upload failed and could not retrieve URL: $e2');
        }
      }
      throw Exception('Failed to upload image: $e');
    }
  }

  // Create a new video product
  static Future<String> createVideoProduct({
    required String title,
    required String description,
    required double price,
    required String condition,
    required String category,
    required String videoPath,
  }) async {
    try {
      print('🎥 ProductService: Creating new video product...');
      
      // Validate video file
      if (!VideoUploadService.validateVideo(videoPath)) {
        throw Exception('Invalid video file');
      }
      
      // Note: Firebase Storage authentication will be handled by the upload method
      
      // Get current user ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id') ?? 
                    prefs.getString('signup_user_id') ?? '';
      
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      // Get user data for seller name and profile picture
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      // Get seller name with multiple fallback options
      String sellerName = 'Unknown Seller';
      String sellerUsername = 'unknown';
      if (userData != null) {
        if (userData['firstName'] != null && userData['lastName'] != null) {
          sellerName = '${userData['firstName']} ${userData['lastName']}';
        } else if (userData['fullName'] != null) {
          sellerName = userData['fullName'];
        } else if (userData['username'] != null) {
          sellerName = userData['username'];
        }
        
        // Get username for watermarking
        if (userData['username'] != null) {
          sellerUsername = userData['username'];
        }
      }

      // Generate unique product ID (consistent with regular products)
      final productId = 'product_${DateTime.now().millisecondsSinceEpoch}_${userId}';
      
      print('🆔 Generated product ID: $productId');
      print('👤 Seller name: $sellerName');

      // Upload video and generate thumbnail with watermarking
      print('📤 Uploading video and generating watermarked thumbnail...');
      final videoData = await VideoUploadService.uploadVideoWithThumbnail(
        videoPath: videoPath,
        userId: userId,
        productId: productId,
        username: sellerUsername,
      );

      // Create product document
      final product = Product(
        id: productId,
        title: title,
        description: description,
        price: price,
        condition: condition,
        category: category,
        sellerId: userId,
        sellerName: sellerName,
        sellerUsername: userData?['username'],
        sellerProfilePictureUrl: userData?['profilePictureUrl'],
        imageUrl: videoData['thumbnailUrl'] ?? '', // Use thumbnail as main image
        imageUrls: [videoData['thumbnailUrl'] ?? ''], // Use thumbnail in imageUrls
        videoUrl: videoData['videoUrl'],
        videoThumbnailUrl: videoData['thumbnailUrl'],
        mediaType: 'video',
        createdAt: DateTime.now(),
        status: 'active',
        views: 0,
        isVerified: false,
        likedBy: [],
        comments: [],
        moderationStatus: 'pending',
      );

      // Save to Firestore
      await _firestore.collection('products').doc(productId).set(product.toMap());
      
      // Update category products list
      await _updateCategoryProducts(category, productId);
      
      // Wait a moment for Firestore to propagate the changes
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Create notification for pending status
      await NotificationService.createProductNotification(
        userId: userId,
        productId: productId,
        productTitle: title,
        status: 'pending',
      );
      
      print('✅ Video product created successfully: $productId');
      return productId;

    } catch (e) {
      print('❌ Error creating video product: $e');
      throw Exception('Failed to create video product: $e');
    }
  }

  // Update category products list
  static Future<void> _updateCategoryProducts(String category, String productId) async {
    try {
      final categoryDoc = _firestore.collection('categories').doc(category.toLowerCase());
      await categoryDoc.set({
        'name': category,
        'productIds': FieldValue.arrayUnion([productId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Warning: Could not update category products: $e');
      // Don't fail the entire process for this
    }
  }

  // Get products by category
  static Future<List<Product>> getProductsByCategory(String category) async {
    try {
      print('🔍 ProductService: Fetching products for category: $category');
      
      // Use a simpler query that doesn't require complex indexes
      final querySnapshot = await _firestore
          .collection('products')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'active')
          .where('moderationStatus', isEqualTo: 'approved')
          .get();

      // Sort in memory instead of using orderBy
      final products = querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ Found ${products.length} products in $category');
      return products;
    } catch (e) {
      print('❌ Error fetching products by category: $e');
      
      // Fallback: try to get all products and filter in memory
      try {
        print('🔄 Trying fallback method...');
        final allProducts = await getAllProducts();
        final filteredProducts = allProducts
            .where((product) => product.category == category)
            .toList();
        print('✅ Fallback found ${filteredProducts.length} products in $category');
        return filteredProducts;
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  // Get all products
  static Future<List<Product>> getAllProducts() async {
    try {
      print('🔍 ProductService: Fetching all approved products...');
      
      final querySnapshot = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'active')
          .where('moderationStatus', isEqualTo: 'approved')
          .get();

      // Sort in memory instead of using orderBy
      final products = querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ Found ${products.length} approved products');
      return products;
    } catch (e) {
      print('❌ Error fetching all products: $e');
      
      // Fallback: try to get all products without status filter
      try {
        print('🔄 Trying fallback method for all products...');
        final querySnapshot = await _firestore.collection('products').get();
        final allProducts = querySnapshot.docs
            .map((doc) => Product.fromDocument(doc))
            .where((product) => product.status == 'active')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        print('✅ Fallback found ${allProducts.length} total products');
        return allProducts;
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  // Update existing products with seller profile picture URLs (migration function)
  static Future<void> updateProductsWithProfilePictures() async {
    try {
      print('🔄 ProductService: Updating products with profile pictures...');
      final querySnapshot = await _firestore.collection('products').get();
      
      int updatedCount = 0;
      for (final doc in querySnapshot.docs) {
        final product = Product.fromDocument(doc);
        
        // Skip if product already has profile picture URL
        if (product.sellerProfilePictureUrl != null && product.sellerProfilePictureUrl!.isNotEmpty) {
          continue;
        }
        
        // Get seller's profile picture from user document
        final userDoc = await _firestore.collection('users').doc(product.sellerId).get();
        final userData = userDoc.data();
        final profilePictureUrl = userData?['profilePictureUrl'];
        
        print('🔍 Migration - Checking product ${product.id}:');
        print('  - Seller ID: ${product.sellerId}');
        print('  - User data keys: ${userData?.keys.toList()}');
        print('  - Profile picture URL: $profilePictureUrl');
        
        if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
          // Update the product with the profile picture URL
          await _firestore.collection('products').doc(product.id).update({
            'sellerProfilePictureUrl': profilePictureUrl,
          });
          updatedCount++;
          print('✅ Updated product ${product.id} with profile picture');
        }
      }
      
      print('✅ Migration complete: Updated $updatedCount products with profile pictures');
    } catch (e) {
      print('❌ Error updating products with profile pictures: $e');
    }
  }

  // Sync current user's profile picture from SharedPreferences to Firestore and all interactions
  static Future<void> syncCurrentUserProfilePicture() async {
    try {
      print('🔄 ProductService: Syncing current user profile picture and username...');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id') ?? prefs.getString('signup_user_id');
      final profilePhotoUrl = prefs.getString('profile_photo_url');
      
      if (userId != null) {
        print('🔍 Syncing profile data for user: $userId');
        print('🔍 Profile picture URL: $profilePhotoUrl');
        
        // Get user data to get username
        final userData = await getUserData(userId);
        final username = userData?['username'];
        
        // Update user document with profile picture URL
        if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
          await _firestore.collection('users').doc(userId).update({
            'profilePictureUrl': profilePhotoUrl,
            'profilePhotoUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Sync profile picture and username to all user's products
        await _syncProfileDataToProducts(userId, profilePhotoUrl, username);
        
        // Sync profile picture and username to all user's comments
        await _syncProfileDataToComments(userId, profilePhotoUrl, username);
        
        print('✅ Successfully synced profile data to all interactions');
      } else {
        print('❌ No user ID found in SharedPreferences');
        print('  - User ID: $userId');
      }
    } catch (e) {
      print('❌ Error syncing current user profile data: $e');
    }
  }

  // Sync profile data to all user's products
  static Future<void> _syncProfileDataToProducts(String userId, String? profilePhotoUrl, String? username) async {
    try {
      print('🔄 Syncing profile data to user\'s products...');
      
      // Get all products by this user
      final productsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: userId)
          .get();
      
      print('📦 Found ${productsQuery.docs.length} products to update');
      
      // Update each product with the new profile data
      for (final doc in productsQuery.docs) {
        final updateData = <String, dynamic>{};
        if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
          updateData['sellerProfilePictureUrl'] = profilePhotoUrl;
        }
        if (username != null && username.isNotEmpty) {
          updateData['sellerUsername'] = username;
        }
        
        if (updateData.isNotEmpty) {
          await doc.reference.update(updateData);
          print('✅ Updated product: ${doc.id}');
        }
      }
      
      print('✅ Profile data synced to all user products');
    } catch (e) {
      print('❌ Error syncing profile data to products: $e');
    }
  }

  // Sync profile picture to all user's comments
  static Future<void> _syncProfileDataToComments(String userId, String? profilePhotoUrl, String? username) async {
    try {
      print('🔄 Syncing profile data to user\'s comments...');
      
      // Get all products
      final productsQuery = await _firestore.collection('products').get();
      
      int updatedComments = 0;
      
      // Check each product for comments by this user
      for (final productDoc in productsQuery.docs) {
        final productData = productDoc.data();
        final comments = List<Map<String, dynamic>>.from(productData['comments'] ?? []);
        
        bool hasUpdates = false;
        
        // Update comments by this user
        for (int i = 0; i < comments.length; i++) {
          if (comments[i]['userId'] == userId) {
            if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
              comments[i]['userProfilePicture'] = profilePhotoUrl;
            }
            if (username != null && username.isNotEmpty) {
              comments[i]['userName'] = username;
            }
            hasUpdates = true;
            updatedComments++;
          }
        }
        
        // Update the product if there were comment changes
        if (hasUpdates) {
          await productDoc.reference.update({'comments': comments});
          print('✅ Updated comments in product: ${productDoc.id}');
        }
      }
      
      print('✅ Profile data synced to $updatedComments comments');
    } catch (e) {
      print('❌ Error syncing profile data to comments: $e');
    }
  }

  // Get product by ID
  static Future<Product?> getProductById(String productId) async {
    try {
      print('🔍 ProductService: Fetching product: $productId');
      
      final doc = await _firestore.collection('products').doc(productId).get();
      
      if (doc.exists) {
        final product = Product.fromDocument(doc);
        print('✅ Product found: ${product.title}');
        return product;
      } else {
        print('❌ Product not found: $productId');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching product by ID: $e');
      return null;
    }
  }

  // Get user's products
  static Future<List<Product>> getUserProducts(String userId) async {
    try {
      print('🔍 ProductService: Fetching products for user: $userId');
      
      final querySnapshot = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: userId)
          .get();

      // Sort in memory instead of using orderBy
      final products = querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ Found ${products.length} products for user $userId');
      return products;
    } catch (e) {
      print('❌ Error fetching user products: $e');
      
      // Fallback: try to get all products and filter in memory
      try {
        print('🔄 Trying fallback method for user products...');
        final allProducts = await getAllProducts();
        final userProducts = allProducts
            .where((product) => product.sellerId == userId)
            .toList();
        print('✅ Fallback found ${userProducts.length} products for user $userId');
        return userProducts;
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  // Update product
  static Future<bool> updateProduct(String productId, Map<String, dynamic> updates) async {
    try {
      print('🔄 ProductService: Updating product: $productId');
      
      await _firestore.collection('products').doc(productId).update(updates);
      
      print('✅ Product updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating product: $e');
      return false;
    }
  }

  // Delete product
  static Future<bool> deleteProduct(String productId) async {
    try {
      print('🔄 ProductService: Deleting product: $productId');
      
      // Update status to inactive instead of deleting
      await _firestore.collection('products').doc(productId).update({
        'status': 'inactive',
        'deletedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Product deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting product: $e');
      return false;
    }
  }

  // Increment product views
  static Future<void> incrementViews(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('⚠️ Warning: Could not increment views: $e');
    }
  }

  // Search products
  static Future<List<Product>> searchProducts(String query) async {
    try {
      print('🔍 ProductService: Searching products for: $query');
      
      final querySnapshot = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'active')
          .get();

      final allProducts = querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList();

      // Filter products by search query (case-insensitive)
      final filteredProducts = allProducts.where((product) {
        final searchQuery = query.toLowerCase();
        return product.title.toLowerCase().contains(searchQuery) ||
               product.description.toLowerCase().contains(searchQuery) ||
               product.category.toLowerCase().contains(searchQuery);
      }).toList();

      print('✅ Found ${filteredProducts.length} products matching "$query"');
      return filteredProducts;
    } catch (e) {
      print('❌ Error searching products: $e');
      return [];
    }
  }

  // Get categories with product counts
  static Future<Map<String, int>> getCategoryCounts() async {
    try {
      print('🔍 ProductService: Getting category counts...');
      
      final categories = ['Accessories', 'Electronics', 'Furniture', 'Men\'s Wear', 'Women\'s Wear', 'Vehicle'];
      final Map<String, int> counts = {};

      for (final category in categories) {
        final querySnapshot = await _firestore
            .collection('products')
            .where('category', isEqualTo: category)
            .where('status', isEqualTo: 'active')
            .get();
        
        counts[category] = querySnapshot.docs.length;
      }

      print('✅ Category counts: $counts');
      return counts;
    } catch (e) {
      print('❌ Error getting category counts: $e');
      return {};
    }
  }

  // Like/Unlike a product
  static Future<bool> toggleLike(String productId, String userId) async {
    try {
      print('🔍 ProductService: Toggling like for product: $productId by user: $userId');
      
      final docRef = _firestore.collection('products').doc(productId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('❌ Product not found: $productId');
        return false;
      }
      
      final product = Product.fromDocument(doc);
      final likedBy = List<String>.from(product.likedBy);
      
      if (likedBy.contains(userId)) {
        // Unlike: remove user from likedBy list
        likedBy.remove(userId);
        print('💔 User $userId unliked product $productId');
      } else {
        // Like: add user to likedBy list
        likedBy.add(userId);
        print('❤️ User $userId liked product $productId');
      }
      
      await docRef.update({'likedBy': likedBy});
      print('✅ Like status updated successfully');
      return true;
    } catch (e) {
      print('❌ Error toggling like: $e');
      return false;
    }
  }

  // Add a comment to a product
  static Future<bool> addComment(String productId, String userId, String userName, String userProfilePicture, String commentText) async {
    try {
      print('🔍 ProductService: Adding comment to product: $productId by user: $userId');
      
      final docRef = _firestore.collection('products').doc(productId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('❌ Product not found: $productId');
        return false;
      }
      
      final product = Product.fromDocument(doc);
      final comments = List<Map<String, dynamic>>.from(product.comments);
      
      final newComment = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': userId,
        'userName': userName,
        'userProfilePicture': userProfilePicture,
        'text': commentText,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      
      comments.add(newComment);
      
      await docRef.update({'comments': comments});
      print('✅ Comment added successfully');
      return true;
    } catch (e) {
      print('❌ Error adding comment: $e');
      return false;
    }
  }

  // Edit a comment
  static Future<bool> editComment(String productId, String commentId, String newText) async {
    try {
      print('🔍 ProductService: Editing comment: $commentId in product: $productId');
      
      final docRef = _firestore.collection('products').doc(productId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('❌ Product not found: $productId');
        return false;
      }
      
      final product = Product.fromDocument(doc);
      final comments = List<Map<String, dynamic>>.from(product.comments);
      
      final commentIndex = comments.indexWhere((comment) => comment['id'] == commentId);
      if (commentIndex == -1) {
        print('❌ Comment not found: $commentId');
        return false;
      }
      
      comments[commentIndex]['text'] = newText;
      comments[commentIndex]['editedAt'] = DateTime.now().toIso8601String();
      
      await docRef.update({'comments': comments});
      print('✅ Comment edited successfully');
      return true;
    } catch (e) {
      print('❌ Error editing comment: $e');
      return false;
    }
  }

  // Delete a comment
  static Future<bool> deleteComment(String productId, String commentId) async {
    try {
      print('🔍 ProductService: Deleting comment: $commentId from product: $productId');
      
      final docRef = _firestore.collection('products').doc(productId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('❌ Product not found: $productId');
        return false;
      }
      
      final product = Product.fromDocument(doc);
      final comments = List<Map<String, dynamic>>.from(product.comments);
      
      comments.removeWhere((comment) => comment['id'] == commentId);
      
      await docRef.update({'comments': comments});
      print('✅ Comment deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting comment: $e');
      return false;
    }
  }

  // Get user data by ID (for getting username and profile picture)
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      print('🔍 ProductService: Getting user data for: $userId');
      print('🔍 Using Firestore instance: ${_firestore.app.name}');
      print('🔍 Database ID: ${_firestore.databaseId}');
      
      final doc = await _firestore.collection('users').doc(userId).get();
      print('🔍 Document exists: ${doc.exists}');
      print('🔍 Document ID: ${doc.id}');
      
      if (doc.exists) {
        final userData = doc.data();
        print('✅ Found user data: ${userData?['username']}');
        print('🔍 Profile picture URL: ${userData?['profilePictureUrl']}');
        print('🔍 All user data fields: ${userData?.keys.toList()}');
        return userData;
      } else {
        print('❌ User not found: $userId');
        print('🔍 Document path: users/$userId');
        return null;
      }
    } catch (e) {
      print('❌ Error getting user data: $e');
      print('❌ Error type: ${e.runtimeType}');
      return null;
    }
  }

  // Get products by moderation status (for admin use)
  static Future<List<Product>> getProductsByModerationStatus(String status) async {
    try {
      print('🔍 ProductService: Fetching products with moderation status: $status');
      
      final querySnapshot = await _firestore
          .collection('products')
          .where('moderationStatus', isEqualTo: status)
          .get();

      final products = querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ Found ${products.length} products with status: $status');
      return products;
    } catch (e) {
      print('❌ Error fetching products by moderation status: $e');
      return [];
    }
  }

  // Get all products for admin (including all moderation statuses)
  static Future<List<Product>> getAllProductsForAdmin() async {
    try {
      print('🔍 ProductService: Fetching all products for admin...');
      
      final querySnapshot = await _firestore
          .collection('products')
          .get();

      final products = querySnapshot.docs
          .map((doc) => Product.fromDocument(doc))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ Found ${products.length} total products for admin');
      return products;
    } catch (e) {
      print('❌ Error fetching all products for admin: $e');
      return [];
    }
  }

}
