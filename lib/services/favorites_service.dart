import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a product to favorites
  Future<void> addToFavorites(String userId, String productId) async {
    try {
      // Validate inputs
      if (userId.isEmpty || productId.isEmpty) {
        throw Exception('UserId and productId must not be empty');
      }
      
      // Ensure productId is stored in document data for reliable retrieval
      await _firestore
          .collection(AppConstants.favoritesCollection)
          .doc('${userId}_$productId')
          .set({
        'userId': userId,
        'productId': productId.trim(), // Store trimmed productId in data
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('❤️ Added to favorites: $productId for user: $userId');
    } catch (e) {
      debugPrint('❌ Error adding to favorites: $e');
      throw Exception('Error adding to favorites: $e');
    }
  }

  // Remove a product from favorites
  Future<void> removeFromFavorites(String userId, String productId) async {
    try {
      await _firestore
          .collection(AppConstants.favoritesCollection)
          .doc('${userId}_$productId')
          .delete();
      debugPrint('💔 Removed from favorites: $productId for user: $userId');
    } catch (e) {
      throw Exception('Error removing from favorites: $e');
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String userId, String productId) async {
    final isFavorited = await isFavorite(userId, productId);
    if (isFavorited) {
      await removeFromFavorites(userId, productId);
    } else {
      await addToFavorites(userId, productId);
    }
  }

  // Check if a product is favorited by a user
  Future<bool> isFavorite(String userId, String productId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.favoritesCollection)
          .doc('${userId}_$productId')
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      return false;
    }
  }

  // Stream to check if a product is favorited (for real-time updates)
  Stream<bool> isFavoriteStream(String userId, String productId) {
    return _firestore
        .collection(AppConstants.favoritesCollection)
        .doc('${userId}_$productId')
        .snapshots()
        .map((doc) => doc.exists);
  }

  // Get all favorite product IDs for a user
  Stream<List<String>> getUserFavoriteProductIds(String userId) {
    return _firestore
        .collection(AppConstants.favoritesCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['productId'] as String?)
            .whereType<String>()
            .toList());
  }

  // Get all favorite product IDs for a user (stream)
  // Gets productId from document data field first, then falls back to document ID extraction
  Stream<List<String>> getUserFavoriteProductIdsStream(String userId) {
    return _firestore
        .collection(AppConstants.favoritesCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final productIds = <String>[];
      
      for (final doc in snapshot.docs) {
        try {
          // Method 1: Get productId from document data field (most reliable)
          final data = doc.data();
          final productIdFromData = data['productId'] as String?;
          
          if (productIdFromData != null && productIdFromData.isNotEmpty && productIdFromData.trim().isNotEmpty) {
            productIds.add(productIdFromData.trim());
            continue;
          }
          
          // Method 2: Extract productId from document ID format: ${userId}_${productId}
          final docId = doc.id;
          if (docId.isNotEmpty) {
            final prefix = '${userId}_';
            if (docId.startsWith(prefix)) {
              final extractedId = docId.substring(prefix.length);
              if (extractedId.isNotEmpty && extractedId.trim().isNotEmpty) {
                productIds.add(extractedId.trim());
                continue;
              }
            }
          }
          
          debugPrint('⚠️ Skipped invalid favorite document: ${doc.id}');
        } catch (e) {
          debugPrint('❌ Error processing favorite document ${doc.id}: $e');
        }
      }
      
      // Final validation: filter out any empty or invalid IDs
      final validProductIds = productIds
          .where((id) => id.isNotEmpty && id.trim().isNotEmpty)
          .toSet() // Remove duplicates
          .toList();
      
      debugPrint('📋 Found ${validProductIds.length} valid favorite product IDs for user: $userId');
      if (validProductIds.isEmpty && snapshot.docs.isNotEmpty) {
        debugPrint('⚠️ Warning: ${snapshot.docs.length} favorite documents found but no valid product IDs extracted');
      }
      
      return validProductIds;
    });
  }

  // Get all favorite products using whereIn query (more efficient)
  // Queries products collection by document ID (productId stored in favorites is the document ID)
  Stream<List<Map<String, dynamic>>> getUserFavoritesWithWhereIn(String userId) {
    return getUserFavoriteProductIdsStream(userId).asyncMap((productIds) async {
      if (productIds.isEmpty) {
        debugPrint('📋 No favorite product IDs, returning empty list');
        return <Map<String, dynamic>>[];
      }

      // Firebase whereIn has a limit of 10 items, so we need to batch if needed
      if (productIds.length > 10) {
        debugPrint('⚠️ More than 10 favorites, batching queries...');
        final List<Map<String, dynamic>> allProducts = [];
        
        // Process in batches of 10
        for (int i = 0; i < productIds.length; i += 10) {
          final batch = productIds.skip(i).take(10).toList();
          try {
            // Query by document ID (productId is the document ID in products collection)
            final snapshot = await _firestore
                .collection(AppConstants.productsCollection)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            
            final batchProducts = snapshot.docs
                .map((doc) => {
                      'id': doc.id,
                      ...doc.data(),
                    })
                .toList();
            
            allProducts.addAll(batchProducts);
          } catch (e) {
            debugPrint('❌ Error fetching batch: $e');
          }
        }
        
        debugPrint('✅ Returning ${allProducts.length} favorite products (batched)');
        return allProducts;
      } else {
        // Use whereIn for 10 or fewer items
        // Query by document ID (productId is the document ID in products collection)
        try {
          final snapshot = await _firestore
              .collection(AppConstants.productsCollection)
              .where(FieldPath.documentId, whereIn: productIds)
              .get();
          
          final products = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
          
          debugPrint('✅ Returning ${products.length} favorite products');
          return products;
        } catch (e) {
          debugPrint('❌ Error fetching favorites with whereIn: $e');
          return <Map<String, dynamic>>[];
        }
      }
    });
  }
}

