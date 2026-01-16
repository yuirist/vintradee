import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String sellerId;
  final String title;
  final String description;
  final double price;
  final String category;
  final List<String> imageUrls;
  final ProductCondition condition;
  final ProductStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? buyerId;
  final DateTime? soldAt;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrls,
    required this.condition,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.buyerId,
    this.soldAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'imageUrls': imageUrls,
      'condition': condition.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'timestamp': Timestamp.fromDate(createdAt), // For Firestore indexing
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'buyerId': buyerId,
      'soldAt': soldAt != null ? Timestamp.fromDate(soldAt!) : null,
    };
  }

  // Create from Firestore Map
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    // Handle both Timestamp and String formats for backward compatibility
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    // Handle timestamp field (for Firestore indexing) - fallback to createdAt if null
    DateTime? timestamp;
    if (map['timestamp'] != null) {
      timestamp = parseDateTime(map['timestamp']);
    } else if (map['createdAt'] != null) {
      // Fallback to createdAt if timestamp doesn't exist (for backward compatibility)
      timestamp = parseDateTime(map['createdAt']);
    } else {
      // If neither exists, use current time (null safety)
      timestamp = DateTime.now();
    }

    return ProductModel(
      id: map['id'] ?? '',
      sellerId: map['sellerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      condition: ProductCondition.values.firstWhere(
        (e) => e.toString().split('.').last == map['condition'],
        orElse: () => ProductCondition.good,
      ),
      status: ProductStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => ProductStatus.available,
      ),
      createdAt: timestamp, // Use timestamp for createdAt (null safety handled above)
      updatedAt: map['updatedAt'] != null ? parseDateTime(map['updatedAt']) : null,
      buyerId: map['buyerId'],
      soldAt: map['soldAt'] != null ? parseDateTime(map['soldAt']) : null,
    );
  }

  // Create a copy with updated fields
  ProductModel copyWith({
    String? id,
    String? sellerId,
    String? title,
    String? description,
    double? price,
    String? category,
    List<String>? imageUrls,
    ProductCondition? condition,
    ProductStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? buyerId,
    DateTime? soldAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      condition: condition ?? this.condition,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      buyerId: buyerId ?? this.buyerId,
      soldAt: soldAt ?? this.soldAt,
    );
  }
}

enum ProductCondition {
  excellent,
  good,
  fair,
  poor,
}

enum ProductStatus {
  available,
  pending,
  reserved,
  sold,
}

