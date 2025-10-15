import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String condition;
  final String category;
  final String sellerId;
  final String sellerName;
  final String? sellerUsername; // Seller's username
  final String? sellerProfilePictureUrl; // Seller's profile picture URL
  final String imageUrl; // Keep for backward compatibility
  final List<String> imageUrls; // New field for multiple images
  final String? videoUrl; // Video URL for video products
  final String? videoThumbnailUrl; // Thumbnail for video products
  final String mediaType; // 'image' or 'video'
  final DateTime createdAt;
  final String status; // active, sold, inactive
  final String? location;
  final int views;
  final bool isVerified;
  final List<String> likedBy; // List of user IDs who liked this product
  final List<Map<String, dynamic>> comments; // List of comments with user info
  
  // Moderation fields
  final String moderationStatus; // pending, approved, rejected
  final String? reviewedBy; // Admin user ID who reviewed
  final DateTime? reviewedAt; // When it was reviewed
  final String? rejectionReason; // Reason for rejection if rejected

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.condition,
    required this.category,
    required this.sellerId,
    required this.sellerName,
    this.sellerUsername,
    this.sellerProfilePictureUrl,
    required this.imageUrl,
    this.imageUrls = const [],
    this.videoUrl,
    this.videoThumbnailUrl,
    this.mediaType = 'image',
    required this.createdAt,
    this.status = 'active',
    this.location,
    this.views = 0,
    this.isVerified = false,
    this.likedBy = const [],
    this.comments = const [],
    this.moderationStatus = 'pending',
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  // Convert Product to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'condition': condition,
      'category': category,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerUsername': sellerUsername,
      'sellerProfilePictureUrl': sellerProfilePictureUrl,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'videoThumbnailUrl': videoThumbnailUrl,
      'mediaType': mediaType,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'location': location,
      'views': views,
      'isVerified': isVerified,
      'likedBy': likedBy,
      'comments': comments,
      'moderationStatus': moderationStatus,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'rejectionReason': rejectionReason,
    };
  }

  // Create Product from Firebase document
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      condition: map['condition'] ?? '',
      category: map['category'] ?? '',
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      sellerUsername: map['sellerUsername'],
      sellerProfilePictureUrl: map['sellerProfilePictureUrl'],
      imageUrl: map['imageUrl'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      videoUrl: map['videoUrl'],
      videoThumbnailUrl: map['videoThumbnailUrl'],
      mediaType: map['mediaType'] ?? 'image',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'active',
      location: map['location'],
      views: map['views'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      comments: List<Map<String, dynamic>>.from(map['comments'] ?? []),
      moderationStatus: map['moderationStatus'] ?? 'pending',
      reviewedBy: map['reviewedBy'],
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'],
    );
  }

  // Create Product from Firestore document
  factory Product.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product.fromMap(data);
  }

  // Copy with method for updates
  Product copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? condition,
    String? category,
    String? sellerId,
    String? sellerName,
    String? sellerUsername,
    String? sellerProfilePictureUrl,
    String? imageUrl,
    List<String>? imageUrls,
    String? videoUrl,
    String? videoThumbnailUrl,
    String? mediaType,
    DateTime? createdAt,
    String? status,
    String? location,
    int? views,
    bool? isVerified,
    List<String>? likedBy,
    List<Map<String, dynamic>>? comments,
    String? moderationStatus,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      condition: condition ?? this.condition,
      category: category ?? this.category,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerUsername: sellerUsername ?? this.sellerUsername,
      sellerProfilePictureUrl: sellerProfilePictureUrl ?? this.sellerProfilePictureUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      location: location ?? this.location,
      views: views ?? this.views,
      isVerified: isVerified ?? this.isVerified,
      likedBy: likedBy ?? this.likedBy,
      comments: comments ?? this.comments,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  @override
  String toString() {
    return 'Product{id: $id, title: $title, price: $price, category: $category, status: $status}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

