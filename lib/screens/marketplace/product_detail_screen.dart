import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/chat_service.dart';
import '../../services/favorites_service.dart';
import '../../services/payment_service.dart';
import '../../services/stripe_payment_service.dart';
import '../../services/email_service.dart';
import '../../screens/chat/chat_screen.dart';
import '../../core/widgets/custom_button.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FavoritesService _favoritesService = FavoritesService();
  final PaymentService _paymentService = PaymentService();
  final StripePaymentService _stripeService = StripePaymentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  ProductModel? _product;
  bool _isLoading = true;
  String? _sellerName;
  bool _isSeller = false;
  String? _dealMethod;
  String? _meetupLocation;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final product = await _firebaseService.getProductById(widget.productId);
    if (product != null) {
      // Also fetch deal method and location from Firestore
      try {
        final doc = await _firestore
            .collection(AppConstants.productsCollection)
            .doc(widget.productId)
            .get();
        
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _product = product;
            _isSeller = _auth.currentUser?.uid == product.sellerId;
            _dealMethod = data?['dealMethod'] as String?;
            _meetupLocation = data?['meetupLocation'] as String?;
          });
        } else {
          setState(() {
            _product = product;
            _isSeller = _auth.currentUser?.uid == product.sellerId;
          });
        }
      } catch (e) {
        debugPrint('Error loading deal method/location: $e');
        setState(() {
          _product = product;
          _isSeller = _auth.currentUser?.uid == product.sellerId;
        });
      }
      _loadSellerInfo();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadSellerInfo() async {
    if (_product != null) {
      final seller = await _firebaseService.getUserById(_product!.sellerId);
      if (seller != null) {
        setState(() {
          _sellerName = seller.displayName;
        });
      }
    }
  }

  Future<void> _handleBuyNow() async {
    if (_product == null) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      _showError('Please log in to continue');
      return;
    }

    if (_isSeller) {
      _showError('You cannot buy your own product');
      return;
    }

    if (_product!.status == ProductStatus.sold) {
      _showError('This product is already sold');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Purchase',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to buy "${_product!.title}" for RM ${_product!.price.toStringAsFixed(2)}?',
          style: GoogleFonts.roboto(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDBC156), // Brand yellow
              foregroundColor: AppTheme.black,
            ),
            child: Text(
              'Pay Now',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDBC156)),
          ),
        ),
      );
    }

    try {
      // Initialize Stripe Payment Sheet (Test Mode with FPX)
      bool paymentSuccess = false;
      
      try {
        // Use test payment function with FPX for Malaysian users
        paymentSuccess = await _stripeService.makeTestPayment(
          _product!.price,
          'myr',
        );
      } catch (e) {
        debugPrint('❌ Payment failed: $e');
        paymentSuccess = false;
      }

      if (!paymentSuccess) {
        // Close loading dialog
        if (mounted) Navigator.pop(context);
        if (mounted) {
          _showError('Payment was canceled');
        }
        return;
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Update product status to 'sold' in Firestore
      await _firebaseService.updateProduct(
        _product!.copyWith(
          status: ProductStatus.sold,
          buyerId: currentUserId,
          soldAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Get buyer and seller info for email
      final buyer = _auth.currentUser;
      final buyerEmail = buyer?.email;
      final buyerName = buyer?.displayName ?? 'Buyer';
      
      // Get seller info
      String? sellerName;
      String? sellerEmail;
      try {
        final sellerDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(_product!.sellerId)
            .get();
        if (sellerDoc.exists) {
          final sellerData = sellerDoc.data();
          sellerName = sellerData?['displayName'] as String?;
          sellerEmail = sellerData?['email'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching seller info: $e');
      }

      // Get meetup location from product data
      String? meetupLocation;
      try {
        final productDoc = await _firestore
            .collection(AppConstants.productsCollection)
            .doc(_product!.id)
            .get();
        if (productDoc.exists) {
          final productData = productDoc.data();
          meetupLocation = productData?['meetupLocation'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching meetup location: $e');
      }

      // Complete post-purchase workflow
      await _paymentService.completePurchase(
        buyerId: currentUserId,
        sellerId: _product!.sellerId,
        productId: _product!.id,
        amount: _product!.price,
        productTitle: _product!.title,
        buyerEmail: buyerEmail,
        buyerName: buyerName,
        sellerEmail: sellerEmail,
        sellerName: sellerName,
        meetupLocation: meetupLocation,
      );

      // Send receipt email to buyer (triggered on Stripe payment success)
      if (buyerEmail != null && buyerEmail.isNotEmpty) {
        try {
          final emailService = EmailService();
          final formattedPrice = 'RM ${_product!.price.toStringAsFixed(2)}';
          final emailSent = await emailService.sendReceiptEmail(
            recipientEmail: buyerEmail,
            itemName: _product!.title,
            price: formattedPrice,
          );
          if (emailSent) {
            debugPrint('✅ Receipt email sent successfully to $buyerEmail');
          } else {
            debugPrint('⚠️ Failed to send receipt email to $buyerEmail');
          }
        } catch (e) {
          debugPrint('⚠️ Error sending receipt email: $e');
          // Don't block the success flow if email fails
        }
      }

      // Show success animation
      if (mounted) {
        _showSuccessAnimation(context);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showError('Failed to complete purchase: $e');
      }
    }
  }

  void _showSuccessAnimation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Checkmark Animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Successful!',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your purchase has been confirmed.\nA receipt has been sent to your email.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Done',
                onPressed: () {
                  Navigator.pop(context); // Close success dialog
                  Navigator.pop(context); // Close product detail screen
                },
                backgroundColor: const Color(0xFFDBC156),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleChat() async {
    if (_product == null) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      _showError('Please log in to continue');
      return;
    }

    // Prevent seller from chatting with themselves
    if (currentUserId == _product!.sellerId) {
      _showError('You cannot chat with yourself');
      return;
    }

    try {
      // Create or get chat room with participants array
      final chatService = ChatService();
      final chatRoomId = await chatService.createOrGetChatRoom(
        sellerId: _product!.sellerId,
        buyerId: currentUserId,
        productId: _product!.id,
        productTitle: _product!.title,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatRoomId: chatRoomId,
              productId: _product!.id,
              sellerId: _product!.sellerId,
              sellerName: _sellerName ?? 'Seller',
              productTitle: _product!.title,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error creating chat room: $e');
      }
    }
  }


  Future<void> _handleMarkAsSold() async {
    if (_product == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Sold'),
        content: const Text('Are you sure you want to mark this item as sold?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark as Sold'),
          ),
        ],
      ),
    );

    if (confirmed == true && _product?.buyerId != null) {
      final success = await context.read<ProductProvider>().markAsSold(
            _product!.id,
            _product!.buyerId!,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as sold')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleMarkAsAvailable() async {
    if (_product == null) return;

    final success = await context.read<ProductProvider>().markAsAvailable(
          _product!.id,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item marked as available')),
      );
      _loadProduct();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryYellow),
          ),
        ),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('Product not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_product != null)
            StreamBuilder<bool>(
              stream: _auth.currentUser != null && _product!.id.trim().isNotEmpty
                  ? _favoritesService.isFavoriteStream(
                      _auth.currentUser!.uid,
                      _product!.id.trim(),
                    )
                  : Stream.value(false),
              builder: (context, snapshot) {
                final isFavorited = snapshot.data ?? false;
                return IconButton(
                  icon: Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: isFavorited ? Colors.red : AppTheme.textPrimary,
                    size: 28,
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
                    if (_product!.id.isEmpty || _product!.id.trim().isEmpty) {
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
                        _product!.id.trim(),
                      );
                      
                      // Show feedback message
                      if (mounted) {
                        final wasFavorited = await _favoritesService.isFavorite(
                          currentUserId,
                          _product!.id.trim(),
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
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Images
            if (_product!.imageUrls.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: _product!.imageUrls.length,
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(0),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: _product!.imageUrls[index],
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
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGrey,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.image_not_supported,
                  size: 64,
                  color: AppTheme.textSecondary,
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _product!.title,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'RM ${_product!.price.toStringAsFixed(2)}',
                        style: GoogleFonts.roboto(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryYellow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category and Condition
                  Row(
                    children: [
                      _buildInfoChip('Category', _product!.category),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        'Condition',
                        _product!.condition.toString().split('.').last,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_product!.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(_product!.status),
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(_product!.status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Description',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _product!.description,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Deal Method and Location
                  if (_dealMethod != null) ...[
                    Row(
                      children: [
                        Icon(
                          _dealMethod == 'Meet Up' ? Icons.handshake : Icons.local_shipping,
                          color: const Color(0xFFDBC156),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Deal Method: ',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _dealMethod!,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: const Color(0xFFDBC156),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_dealMethod == 'Meet Up' && _meetupLocation != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: const Color(0xFFDBC156),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Meet Up Location: ',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDBC156),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          _meetupLocation!,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: const Color(0xFFDBC156),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  // Seller Info
                  Text(
                    'Seller',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection(AppConstants.usersCollection)
                        .doc(_product!.sellerId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFDBC156),
                              ),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.primaryYellow,
                            child: Icon(Icons.person, color: AppTheme.black),
                          ),
                          title: Text(
                            _sellerName ?? 'Seller',
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        );
                      }

                      final sellerData = snapshot.data!.data() as Map<String, dynamic>?;
                      final sellerName = sellerData?['displayName'] ?? _sellerName ?? 'Seller';
                      final sellerPhotoUrl = sellerData?['photoUrl'] as String?;
                      final sellerRating = (sellerData?['rating'] as num?)?.toDouble() ?? 4.5;
                      // Try both createdAt and created_at fields
                      final sellerCreatedAt = sellerData?['createdAt'] ?? sellerData?['created_at'];

                      return GestureDetector(
                        onTap: () {
                          // TODO: Navigate to seller's public profile page
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => SellerProfileScreen(sellerId: _product!.sellerId),
                          //   ),
                          // );
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.primaryYellow,
                            backgroundImage: sellerPhotoUrl != null && sellerPhotoUrl.isNotEmpty
                                ? CachedNetworkImageProvider(sellerPhotoUrl) as ImageProvider
                                : null,
                            child: sellerPhotoUrl == null || sellerPhotoUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: AppTheme.black,
                                    size: 30,
                                  )
                                : null,
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sellerName,
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getTenureText(sellerCreatedAt),
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: _buildRatingStars(sellerRating),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isSeller
          ? _buildSellerActions()
          : _buildBuyerActions(),
    );
  }

  String _getTenureText(dynamic createdAt) {
    if (createdAt == null) {
      return 'Member since 2024';
    }
    
    DateTime creationTime;
    if (createdAt is Timestamp) {
      creationTime = createdAt.toDate();
    } else if (createdAt is String) {
      try {
        creationTime = DateTime.parse(createdAt);
      } catch (e) {
        return 'Member since 2024';
      }
    } else {
      return 'Member since 2024';
    }
    
    return 'Member since ${creationTime.year}';
  }

  List<Widget> _buildRatingStars(double rating) {
    final stars = <Widget>[];
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;

    // Add full stars
    for (int i = 0; i < fullStars; i++) {
      stars.add(
        Icon(
          Icons.star,
          color: const Color(0xFFDBC156),
          size: 16,
        ),
      );
    }

    // Add half star if needed
    if (hasHalfStar) {
      stars.add(
        Icon(
          Icons.star_half,
          color: const Color(0xFFDBC156),
          size: 16,
        ),
      );
    }

    // Add empty stars to make 5 total
    final emptyStars = 5 - stars.length;
    for (int i = 0; i < emptyStars; i++) {
      stars.add(
        Icon(
          Icons.star_border,
          color: const Color(0xFFDBC156),
          size: 16,
        ),
      );
    }

    return stars;
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondaryGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: ${value.toUpperCase()}',
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBuyerActions() {
    if (_product!.status == ProductStatus.sold) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: CustomButton(
          text: 'Sold Out',
          onPressed: null,
          backgroundColor: AppTheme.textSecondary,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _handleChat,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppTheme.lightGrey, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Chat',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: CustomButton(
              text: _product!.status == ProductStatus.sold
                  ? 'Sold Out'
                  : 'Pay Now',
              onPressed: _product!.status == ProductStatus.sold
                  ? null
                  : _handleBuyNow,
              backgroundColor: const Color(0xFFDBC156), // Brand yellow
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerActions() {
    if (_product!.status == ProductStatus.sold) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: CustomButton(
          text: 'Sold',
          onPressed: null,
          backgroundColor: AppTheme.textSecondary,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_product!.status == ProductStatus.pending)
            CustomButton(
              text: 'Mark as Sold',
              onPressed: _handleMarkAsSold,
              backgroundColor: AppTheme.accentGreen,
            )
          else if (_product!.status == ProductStatus.available)
            CustomButton(
              text: 'Mark as Sold',
              onPressed: _handleMarkAsSold,
              backgroundColor: AppTheme.accentGreen,
            ),
          if (_product!.status == ProductStatus.pending) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _handleMarkAsAvailable,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                side: const BorderSide(color: AppTheme.lightGrey, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Mark as Available',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(ProductStatus status) {
    switch (status) {
      case ProductStatus.available:
        return AppTheme.accentGreen;
      case ProductStatus.pending:
        return Colors.orange;
      case ProductStatus.reserved:
        return Colors.blue;
      case ProductStatus.sold:
        return AppTheme.textSecondary;
    }
  }

  String _getStatusText(ProductStatus status) {
    switch (status) {
      case ProductStatus.available:
        return 'Available';
      case ProductStatus.pending:
        return 'Pending';
      case ProductStatus.reserved:
        return 'Reserved';
      case ProductStatus.sold:
        return 'Sold';
    }
  }
}
