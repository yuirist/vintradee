import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product_model.dart';
import '../../services/favorites_service.dart';
import '../../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import '../marketplace/product_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FavoritesService _favoritesService = FavoritesService();
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch favorite products using individual document gets
  // Uses productId (extracted from favorites document ID) to fetch product documents
  Stream<List<ProductModel>> _fetchFavoriteProducts(List<String> productIds) {
    // Filter out empty or invalid product IDs before fetching
    final validProductIds = productIds
        .where((id) => id.isNotEmpty && id.trim().isNotEmpty)
        .toList();
    
    if (validProductIds.isEmpty) {
      debugPrint('⚠️ No valid product IDs to fetch');
      return Stream.value([]);
    }
    
    debugPrint('📋 Fetching ${validProductIds.length} favorite products...');
    
    return Stream.fromFuture(
      Future.wait(
        validProductIds.map((productId) async {
          try {
            final trimmedId = productId.trim();
            
            // Add Validation: Check before calling .doc()
            if (trimmedId.isEmpty) {
              debugPrint('⚠️ Skipping empty product ID after trimming');
              return null;
            }
            
            // Change Fetch Logic: Use Firestore Document ID (snapshot.id) instead of productData['id']
            // Stop looking for productData['id'] - use doc.id (Firestore Document ID) exclusively
            debugPrint('📦 Fetching product with Document ID: $trimmedId');
            final doc = await _firestore
                .collection(AppConstants.productsCollection)
                .doc(trimmedId) // Use productId as document ID
                .get();
            
            if (doc.exists && doc.data() != null) {
              try {
                final productData = Map<String, dynamic>.from(doc.data()!);
                
                // Ignore empty 'id' field: Remove any empty 'id' field from productData
                // This ensures we always use doc.id instead of an empty string from the database
                if (productData.containsKey('id') && (productData['id'] == null || productData['id'] == '')) {
                  productData.remove('id'); // Remove empty 'id' field
                  debugPrint('  ℹ️ Removed empty "id" field from productData, will use doc.id: ${doc.id}');
                }
                
                // Map Document ID: Use Firestore Document ID (doc.id) as the unique identifier
                // Spread productData (without empty 'id'), then override with doc.id
                final mappedProduct = ProductModel.fromMap({
                  ...productData, // Spread all product data (empty 'id' already removed)
                  'id': doc.id, // Override/Set with Firestore Document ID (ensures ID is never empty)
                });
                
                // Validation: Check that Document ID was successfully mapped
                if (mappedProduct.id.isEmpty) {
                  debugPrint('⚠️ WARNING: Mapped product has empty ID for document ${doc.id}');
                  debugPrint('   Product title: ${mappedProduct.title}');
                  debugPrint('   Document ID: ${doc.id}');
                  debugPrint('   This should not happen - using doc.id as fallback');
                  
                  // Fallback: Create a copy with explicit ID if fromMap() failed
                  final fallbackProduct = ProductModel(
                    id: doc.id, // Use Document ID directly
                    sellerId: mappedProduct.sellerId,
                    title: mappedProduct.title,
                    description: mappedProduct.description,
                    price: mappedProduct.price,
                    category: mappedProduct.category,
                    imageUrls: mappedProduct.imageUrls,
                    condition: mappedProduct.condition,
                    status: mappedProduct.status,
                    createdAt: mappedProduct.createdAt,
                    updatedAt: mappedProduct.updatedAt,
                    buyerId: mappedProduct.buyerId,
                    soldAt: mappedProduct.soldAt,
                  );
                  debugPrint('✅ Created fallback product with explicit ID: ${fallbackProduct.id}');
                  return fallbackProduct;
                }
                
                debugPrint('✅ Successfully mapped product: ${mappedProduct.title} (ID: ${mappedProduct.id}, matches doc.id: ${mappedProduct.id == doc.id})');
                
                // Display: Return product to be displayed in UI
                // Ignore empty 'id' field in database - we use doc.id instead
                // Show every item the user has liked, even if the id field in data is empty
                return mappedProduct;
              } catch (e) {
                debugPrint('❌ Error parsing product ${doc.id}: $e');
                return null;
              }
            } else {
              debugPrint('⚠️ Product document $trimmedId does not exist');
              return null;
            }
          } catch (e) {
            debugPrint('❌ Error fetching product $productId: $e');
            return null;
          }
        }),
      ).then((products) {
        final validProducts = products.whereType<ProductModel>().toList();
        debugPrint('✅ Successfully fetched ${validProducts.length} favorite products');
        return validProducts;
      }).catchError((error) {
        debugPrint('❌ Error in _fetchFavoriteProducts: $error');
        return <ProductModel>[];
      }),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'Listed ${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return 'Listed ${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return 'Listed ${difference.inMinutes}m ago';
    } else {
      return 'Listed just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: Text(
            'Favorites',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Please log in to view favorites'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          'Favorites',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<String>>(
        // Stage 1: Stream the favorite product IDs in real-time
        // This StreamBuilder listens to the favorites collection and updates automatically
        // when favorites are added/removed, regardless of purchase status
        // Uses Firestore Document ID (doc.id) from products collection, not an id field
        stream: _favoritesService.getUserFavoriteProductIdsStream(currentUserId),
        builder: (context, favoriteIdsSnapshot) {
          if (favoriteIdsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryYellow),
              ),
            );
          }

          if (favoriteIdsSnapshot.hasError) {
            debugPrint('❌ Error loading favorite IDs: ${favoriteIdsSnapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading favorites',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final favoriteIds = favoriteIdsSnapshot.data ?? [];
          debugPrint('📋 FavoritesScreen: Found ${favoriteIds.length} favorite IDs');

          // Handle empty state immediately to avoid Firebase whereIn error
          if (favoriteIds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your wishlist is empty. Start exploring!',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Stage 2: Fetch product details using individual document gets
          return StreamBuilder<List<ProductModel>>(
            stream: _fetchFavoriteProducts(favoriteIds),
            builder: (context, productsSnapshot) {
              if (productsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryYellow),
                  ),
                );
              }

              if (productsSnapshot.hasError) {
                debugPrint('❌ Error loading favorite products: ${productsSnapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading favorite products',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${productsSnapshot.error}',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final favorites = productsSnapshot.data ?? [];
              debugPrint('📋 FavoritesScreen: Displaying ${favorites.length} favorite products');

              if (favorites.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your wishlist is empty. Start exploring!',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Filter out any products with invalid IDs before displaying
              final validFavorites = favorites
                  .where((product) => product.id.isNotEmpty && product.id.trim().isNotEmpty)
                  .toList();
              
              if (validFavorites.isEmpty && favorites.isNotEmpty) {
                // If we have favorites but all have invalid IDs, show error
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: Invalid product data',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: validFavorites.length,
                itemBuilder: (context, index) {
                  final product = validFavorites[index];
                  // Additional validation before building card
                  if (product.id.isEmpty || product.id.trim().isEmpty) {
                    debugPrint('⚠️ Skipping product with invalid ID at index $index');
                    return const SizedBox.shrink();
                  }
                  return _buildProductCard(product);
                },
              );
            },
          );
        },
      ),
    );
  }

  // Use the same product card widget as Dashboard for consistency
  Widget _buildProductCard(ProductModel product) {
    // Fix: Validate product ID before using it
    // Products collection uses Firestore Document ID (doc.id), not an id field
    if (product.id.isEmpty || product.id.trim().isEmpty) {
      debugPrint('⚠️ Invalid product ID in _buildProductCard: "${product.id}"');
      return const SizedBox.shrink();
    }
    
    final productId = product.id.trim();
    
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection(AppConstants.productsCollection)
          .doc(productId) // Use Firestore Document ID
          .snapshots(),
      builder: (context, productSnapshot) {
        String sellerName = 'Seller';
        if (productSnapshot.hasData && productSnapshot.data!.exists) {
          final data = productSnapshot.data!.data() as Map<String, dynamic>?;
          sellerName = data?['sellerName'] ?? 'Seller';
        }
        
        // Fallback to user lookup if sellerName not in product doc
        return FutureBuilder<String?>(
          future: sellerName == 'Seller'
              ? _firebaseService.getUserById(product.sellerId).then((user) => user?.displayName)
              : Future.value(sellerName),
          builder: (context, sellerSnapshot) {
            final finalSellerName = sellerSnapshot.data ?? sellerName;
        
            return GestureDetector(
              onTap: () {
                // Validate product ID before navigation
                if (product.id.isEmpty || product.id.trim().isEmpty) {
                  debugPrint('⚠️ Cannot navigate: Invalid product ID');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(productId: product.id.trim()),
                  ),
                );
              },
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image with Price Tag
                    Expanded(
                      flex: 3,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: product.imageUrls.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: product.imageUrls.first,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: AppTheme.secondaryGrey,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppTheme.primaryYellow,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: AppTheme.secondaryGrey,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: AppTheme.secondaryGrey,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                          ),
                          // Price Tag (Yellow) - matching Dashboard style
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBC156), // Brand yellow
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'RM ${product.price.toStringAsFixed(0)}',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.black,
                                ),
                              ),
                            ),
                          ),
                          // Remove from Favorites Button
                          // Since we're on the Favorites page, all items are favorited
                          // This button specifically removes the item
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 24,
                              ),
                              onPressed: () async {
                                final currentUserId = _auth.currentUser?.uid;
                                if (currentUserId == null) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please log in to manage favorites'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                
                                // Fix Path Error: Validate product ID before removing
                                // Products collection uses Firestore Document ID (doc.id), not an id field
                                if (product.id.isEmpty || product.id.trim().isEmpty) {
                                  debugPrint('⚠️ Cannot remove: Invalid product ID');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Invalid product ID'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                
                                final productId = product.id.trim();
                                
                                try {
                                  // Remove from favorites collection
                                  // The document ID format is: ${userId}_${productId}
                                  await _firestore
                                      .collection(AppConstants.favoritesCollection)
                                      .doc('${currentUserId}_$productId')
                                      .delete();
                                  
                                  // Show success message
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Item removed from favorites'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                  
                                  // Data Refresh: The StreamBuilder will automatically update
                                  // because it's listening to the favorites collection
                                  debugPrint('✅ Removed favorite: $productId');
                                } catch (e) {
                                  debugPrint('❌ Error removing favorite: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error removing item: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.5),
                                padding: const EdgeInsets.all(6),
                                minimumSize: const Size(32, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Product Info - matching Dashboard style
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              product.title,
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Time Listed
                            Text(
                              _formatTimeAgo(product.createdAt),
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            // Seller Info
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: AppTheme.secondaryGrey,
                                  child: Icon(
                                    Icons.person,
                                    size: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    finalSellerName,
                                    style: GoogleFonts.roboto(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
