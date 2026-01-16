import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ProductModel> _products = [];
  List<ProductModel> _userProducts = [];
  bool _isLoading = false;
  String? _error;

  List<ProductModel> get products => _products;
  List<ProductModel> get userProducts => _userProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all products
  void loadProducts() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _firebaseService.streamAllProducts().listen(
      (products) {
        _products = products.where((p) => p.status != ProductStatus.sold).toList();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Load user's products
  void loadUserProducts() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firebaseService.streamUserProducts(userId).listen(
      (products) {
        _userProducts = products;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Create product
  Future<String?> createProduct(ProductModel product) async {
    try {
      _isLoading = true;
      notifyListeners();

      final productId = await _firebaseService.createProduct(product);
      // Reload products to include the new one
      loadProducts();
      _isLoading = false;
      notifyListeners();
      return productId;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Update product
  Future<bool> updateProduct(ProductModel product) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firebaseService.updateProduct(product);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Get product from either list
  ProductModel? _getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      try {
        return _userProducts.firstWhere((p) => p.id == productId);
      } catch (e2) {
        return null;
      }
    }
  }

  // Mark product as pending
  Future<bool> markAsPending(String productId, String buyerId) async {
    try {
      final product = _getProductById(productId);
      if (product == null) return false;

      final updatedProduct = product.copyWith(
        status: ProductStatus.pending,
        buyerId: buyerId,
        updatedAt: DateTime.now(),
      );
      return await updateProduct(updatedProduct);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Mark product as sold
  Future<bool> markAsSold(String productId, String buyerId) async {
    try {
      final product = _getProductById(productId);
      if (product == null) return false;

      final updatedProduct = product.copyWith(
        status: ProductStatus.sold,
        buyerId: buyerId,
        soldAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await updateProduct(updatedProduct);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Mark product as available (cancel pending)
  Future<bool> markAsAvailable(String productId) async {
    try {
      final product = _getProductById(productId);
      if (product == null) return false;

      final updatedProduct = product.copyWith(
        status: ProductStatus.available,
        buyerId: null,
        updatedAt: DateTime.now(),
      );
      return await updateProduct(updatedProduct);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Get product by ID
  ProductModel? getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      try {
        return _userProducts.firstWhere((p) => p.id == productId);
      } catch (e2) {
        return null;
      }
    }
  }
}

