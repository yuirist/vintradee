import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../models/product_model.dart';
import '../../services/firebase_service.dart';
import '../../services/favorites_service.dart';
import '../../core/constants/app_constants.dart';
import '../marketplace/product_detail_screen.dart';
import '../listing/create_listing_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedCategoryIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = ['ALL', 'Textbooks', 'Shoes', 'Electronics', 'Furniture', 'Clothing', 'Other'];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final FavoritesService _favoritesService = FavoritesService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Stream<List<ProductModel>> _getProductsStream() {
    Stream<QuerySnapshot> queryStream;
    
    if (_selectedCategoryIndex == 0) {
      // Show all products - fetch without any filters to ensure everyone's products appear
      // We'll sort client-side to handle null timestamps
      queryStream = _firestore
          .collection(AppConstants.productsCollection)
          .snapshots();
    } else {
      // Filter by category only - no status filter
      final category = _categories[_selectedCategoryIndex];
      queryStream = _firestore
          .collection(AppConstants.productsCollection)
          .where('category', isEqualTo: category)
          .snapshots();
    }
    
    return queryStream.map((snapshot) {
      debugPrint('📦 Dashboard: Fetched ${snapshot.docs.length} products from Firestore');
      
      final products = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) {
                debugPrint('⚠️ Warning: Document ${doc.id} has null data');
                return null;
              }
              
              // Handle null timestamp - use createdAt or current time as fallback
              if (!data.containsKey('timestamp') || data['timestamp'] == null) {
                debugPrint('⚠️ Product ${doc.id} has null timestamp, using fallback');
                // If timestamp is null, use createdAt or current time
                if (data.containsKey('createdAt') && data['createdAt'] != null) {
                  data['timestamp'] = data['createdAt'];
                } else {
                  // Fallback to current time if neither exists
                  data['timestamp'] = Timestamp.now();
                }
              }
              
              return ProductModel.fromMap({...data, 'id': doc.id});
            } catch (e) {
              debugPrint('❌ Error parsing product ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ProductModel>()
          .toList();
      
      debugPrint('✅ Dashboard: Successfully parsed ${products.length} products');
      
      // Filter by search query if search bar is not empty
      final searchQuery = _searchController.text.trim().toLowerCase();
      final filteredProducts = searchQuery.isEmpty
          ? products
          : products.where((product) {
              return product.title.toLowerCase().contains(searchQuery);
            }).toList();
      
      // Sort by timestamp descending (latest UTHM deals first) - client-side
      filteredProducts.sort((a, b) {
        // Sort by createdAt (which should match timestamp after processing)
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        return bTime.compareTo(aTime); // Descending order (newest first)
      });
      
      return filteredProducts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Logo
            _buildHeader(),
            
            // Search Bar
            _buildSearchBar(),
            
            // Category Filters
            _buildCategoryFilters(),
            
            // Product Grid
            Expanded(
              child: _buildProductGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateListingScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFFDBC156), // Brand yellow
        foregroundColor: AppTheme.black,
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'assets/images/vintrade_logo.jpg',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to yellow container if logo not found
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.store,
                  color: AppTheme.black,
                  size: 24,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // App Name
          Text(
            'VinTrade',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.secondaryGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              // Trigger rebuild to filter products
            });
          },
          decoration: InputDecoration(
            hintText: 'Search textbooks, furniture...',
            hintStyle: GoogleFonts.roboto(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppTheme.textSecondary,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        // Trigger rebuild
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedCategoryIndex;
          final category = _categories[index];
          final isOtherCategory = category == 'Other';
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: isOtherCategory
                  ? Icon(
                      Icons.grid_view,
                      size: 18,
                      color: isSelected ? AppTheme.white : AppTheme.textPrimary,
                    )
                  : null,
              label: Text(
                category,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.white : AppTheme.textPrimary,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryIndex = index;
                });
              },
              backgroundColor: AppTheme.secondaryGrey,
              selectedColor: AppTheme.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    return StreamBuilder<List<ProductModel>>(
      stream: _getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryYellow),
            ),
          );
        }

        if (snapshot.hasError) {
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
                  'Error loading products',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final products = snapshot.data ?? [];
        
        debugPrint('📊 Dashboard GridView: Displaying ${products.length} products');

        if (products.isEmpty) {
          debugPrint('⚠️ Dashboard: No products to display');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No products available',
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
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  Widget _buildProductCard(ProductModel product) {
    // Try to get sellerName from product document first, then fallback to user lookup
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection(AppConstants.productsCollection)
          .doc(product.id)
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(productId: product.id),
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
                      // Price Tag (Yellow)
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
                      // SOLD Overlay
                      if (product.status == ProductStatus.sold)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'SOLD',
                                  style: GoogleFonts.roboto(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Favorite Heart Button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: StreamBuilder<bool>(
                          stream: _auth.currentUser != null && product.id.trim().isNotEmpty
                              ? _favoritesService.isFavoriteStream(
                                  _auth.currentUser!.uid,
                                  product.id.trim(),
                                )
                              : Stream.value(false),
                          builder: (context, favoriteSnapshot) {
                            final isFavorited = favoriteSnapshot.data ?? false;
                            return IconButton(
                              icon: Icon(
                                isFavorited ? Icons.favorite : Icons.favorite_border,
                                color: isFavorited ? Colors.red : AppTheme.white,
                                size: 24,
                              ),
                              onPressed: () async {
                                final currentUserId = _auth.currentUser?.uid;
                                if (currentUserId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please log in to add favorites'),
                                    ),
                                  );
                                  return;
                                }
                                
                                // Validate product ID before favoriting
                                if (product.id.isEmpty || product.id.trim().isEmpty) {
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
                                
                                try {
                                  // Use trimmed product ID for consistency
                                  await _favoritesService.toggleFavorite(
                                    currentUserId,
                                    product.id.trim(),
                                  );
                                  
                                  // Show feedback message
                                  if (mounted) {
                                    final wasFavorited = await _favoritesService.isFavorite(
                                      currentUserId,
                                      product.id.trim(),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          wasFavorited 
                                            ? 'Added to favorites' 
                                            : 'Removed from favorites',
                                        ),
                                        backgroundColor: wasFavorited ? Colors.green : Colors.grey,
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('❌ Error toggling favorite: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
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
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Product Info
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
