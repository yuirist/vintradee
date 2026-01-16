import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../core/constants/app_constants.dart';
import 'dart:io';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ========== User Operations ==========
  
  // Create or update user document
  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error creating/updating user: $e');
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error getting user: $e');
    }
  }

  // Stream user data
  Stream<UserModel?> streamUser(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);
  }

  // ========== Product Operations ==========
  
  // Create product
  Future<String> createProduct(ProductModel product) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.productsCollection)
          .add(product.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error creating product: $e');
    }
  }

  // Create product with seller name
  Future<String> createProductWithSellerName(ProductModel product, String sellerName) async {
    try {
      final productData = <String, dynamic>{
        ...product.toMap(),
        'sellerName': sellerName,
      };
      final docRef = await _firestore
          .collection(AppConstants.productsCollection)
          .add(productData);
      return docRef.id;
    } catch (e) {
      throw Exception('Error creating product: $e');
    }
  }

  // Update product
  Future<void> updateProduct(ProductModel product) async {
    try {
      await _firestore
          .collection(AppConstants.productsCollection)
          .doc(product.id)
          .update(product.toMap());
    } catch (e) {
      throw Exception('Error updating product: $e');
    }
  }

  // Get product by ID
  Future<ProductModel?> getProductById(String productId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.productsCollection)
          .doc(productId)
          .get();
      
      if (doc.exists) {
        return ProductModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Error getting product: $e');
    }
  }

  // Stream all products
  Stream<List<ProductModel>> streamAllProducts() {
    return _firestore
        .collection(AppConstants.productsCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Handle null timestamp
              if (data['timestamp'] == null) {
                data['timestamp'] = FieldValue.serverTimestamp();
              }
              return ProductModel.fromMap({...data, 'id': doc.id});
            })
            .toList());
  }

  // Stream user's products - filters by sellerId AND orders by timestamp
  Stream<List<ProductModel>> streamUserProducts(String userId) {
    return _firestore
        .collection(AppConstants.productsCollection)
        .where('sellerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Handle null timestamp
              if (data['timestamp'] == null) {
                data['timestamp'] = FieldValue.serverTimestamp();
              }
              return ProductModel.fromMap({...data, 'id': doc.id});
            })
            .toList());
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore
          .collection(AppConstants.productsCollection)
          .doc(productId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting product: $e');
    }
  }

  // ========== Storage Operations ==========
  
  // Upload profile image
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      final ref = _storage
          .ref()
          .child(AppConstants.profileImagesPath)
          .child('$userId.jpg');
      
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Error uploading profile image: $e');
    }
  }

  // Upload product image
  Future<String> uploadProductImage(String productId, File imageFile, int index) async {
    try {
      final ref = _storage
          .ref()
          .child(AppConstants.productImagesPath)
          .child(productId)
          .child('image_$index.jpg');
      
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Error uploading product image: $e');
    }
  }

  // Delete product images
  Future<void> deleteProductImages(String productId, List<String> imageUrls) async {
    try {
      for (final url in imageUrls) {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      }
    } catch (e) {
      throw Exception('Error deleting product images: $e');
    }
  }
}



