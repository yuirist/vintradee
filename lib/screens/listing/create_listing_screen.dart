import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/custom_button.dart';
import '../../services/firebase_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/product_model.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _firebaseService = FirebaseService();
  final _authService = AuthService();
  final _cloudinaryService = CloudinaryService();
  final _imagePicker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;
  
  String? _selectedCategory;
  String? _selectedCondition;
  String? _selectedDealMethod;
  String? _selectedLocation;
  File? _selectedImage;
  bool _isLoading = false;
  String? _sellerName;
  String? _sellerFaculty;
  String? _sellerStudentId;

  final List<String> _categories = ['Textbooks', 'Shoes', 'Electronics', 'Furniture', 'Clothing', 'Other'];
  final List<String> _conditions = ['Excellent', 'Good', 'Fair', 'Poor'];
  final List<String> _dealMethods = ['Meet Up']; // Only Meet Up option available
  final List<String> _meetupLocations = [
    'Tunku Tun Aminah Library',
    'Kolej Kediaman Perwira',
    'FSKTM, Faculty of Computer and Technology',
    'Masjid Sultan Ibrahim UTHM',
  ];

  @override
  void initState() {
    super.initState();
    _loadSellerName();
    // Auto-select 'Meet Up' as the only deal method option
    _selectedDealMethod = 'Meet Up';
  }

  Future<void> _loadSellerName() async {
    final user = _authService.currentUser;
    if (user != null) {
      final userData = await _firebaseService.getUserById(user.uid);
      if (userData != null) {
        setState(() {
          _sellerName = userData.displayName;
          _sellerFaculty = userData.faculty;
          _sellerStudentId = userData.studentId;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePostListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a condition'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Clean Data Entry: Ensure dealMethod is strictly set to 'Meet Up'
    _selectedDealMethod = 'Meet Up'; // Force to 'Meet Up' since it's the only option
    
    // Meet up location is always required
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a meet up location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create a listing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload image to Cloudinary
      debugPrint('🖼️ Starting image upload to Cloudinary...');
      final imageUrl = await _cloudinaryService.uploadImage(_selectedImage!);
      debugPrint('✅ Image upload completed. URL: $imageUrl');

      // Convert condition string to enum
      ProductCondition condition;
      switch (_selectedCondition!.toLowerCase()) {
        case 'excellent':
          condition = ProductCondition.excellent;
          break;
        case 'good':
          condition = ProductCondition.good;
          break;
        case 'fair':
          condition = ProductCondition.fair;
          break;
        case 'poor':
          condition = ProductCondition.poor;
          break;
        default:
          condition = ProductCondition.good;
      }

      // Create product model
      final product = ProductModel(
        id: '', // Will be set by Firestore
        sellerId: user.uid,
        title: _productNameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        category: _selectedCategory!,
        imageUrls: [imageUrl], // Cloudinary URL
        condition: condition,
        status: ProductStatus.available,
        createdAt: DateTime.now(),
      );

      // Explicit Product ID: Create a new document reference first
      final productDocRef = _firestore
          .collection(AppConstants.productsCollection)
          .doc();
      
      // Store the generated document ID
      final productId = productDocRef.id;

      // Complete Data Map: Ensure every new product has required fields from the start
      final productData = <String, dynamic>{
        ...product.toMap(),
        'productId': productId, // Store the generated ID as a field
        'status': 'available', // Explicit status field
        'category': _selectedCategory!, // Include category (supports 'Other')
        'sellerName': _sellerName ?? user.displayName ?? 'Seller',
        'faculty': _sellerFaculty ?? '',
        'studentId': _sellerStudentId ?? '',
        'dealMethod': 'Meet Up', // Clean Data Entry: Strictly set to 'Meet Up'
        'meetupLocation': _selectedLocation, // Always required since only Meet Up is available
        'createdAt': FieldValue.serverTimestamp(), // Server timestamp for consistency
        'timestamp': FieldValue.serverTimestamp(), // For Firestore indexing
      };

      // Save to Firestore using the explicit document reference
      await productDocRef.set(productData);
      
      debugPrint('✅ Product created with ID: $productId');

      // Update the image path with actual product ID (optional optimization)
      // For now, we'll keep the temp ID since it works

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating listing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          'Create Listing',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Upload Section
                Text(
                  'Product Image',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryGrey,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.lightGrey,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add image',
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                // Product Name
                CustomTextField(
                  label: 'Product Name',
                  hint: 'Enter product name',
                  prefixIcon: Icons.shopping_bag,
                  controller: _productNameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Price
                CustomTextField(
                  label: 'Price (RM)',
                  hint: '0.00',
                  prefixIcon: Icons.attach_money,
                  controller: _priceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter price';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid price';
                    }
                    if (double.parse(value) <= 0) {
                      return 'Price must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText: 'Select category',
                    filled: true,
                    fillColor: AppTheme.secondaryGrey,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryYellow, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.category, color: AppTheme.textSecondary),
                  ),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Condition Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCondition,
                  decoration: InputDecoration(
                    labelText: 'Condition',
                    hintText: 'Select condition',
                    filled: true,
                    fillColor: AppTheme.secondaryGrey,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryYellow, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.check_circle_outline, color: AppTheme.textSecondary),
                  ),
                  items: _conditions.map((String condition) {
                    return DropdownMenuItem<String>(
                      value: condition,
                      child: Text(
                        condition,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCondition = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select condition';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Description
                CustomTextField(
                  label: 'Description',
                  hint: 'Describe your product...',
                  prefixIcon: Icons.description,
                  controller: _descriptionController,
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Deal Method Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedDealMethod,
                  decoration: InputDecoration(
                    labelText: 'Deal Method',
                    hintText: 'Select deal method',
                    filled: true,
                    fillColor: AppTheme.secondaryGrey,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryYellow, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.local_shipping, color: AppTheme.textSecondary),
                  ),
                  items: _dealMethods.map((String method) {
                    return DropdownMenuItem<String>(
                      value: method,
                      child: Text(
                        method,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      // Clean Data Entry: Always set to 'Meet Up' (only option)
                      _selectedDealMethod = 'Meet Up';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a deal method';
                    }
                    return null;
                  },
                ),
                
                // Meet Up Location Dropdown (always shown since only Meet Up is available)
                ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    decoration: InputDecoration(
                      labelText: 'Meet Up Location',
                      hintText: 'Select meet up location',
                      filled: true,
                      fillColor: AppTheme.secondaryGrey,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryYellow, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.location_on, color: AppTheme.textSecondary),
                    ),
                    items: _meetupLocations.map((String location) {
                      return DropdownMenuItem<String>(
                        value: location,
                        child: Text(
                          location,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLocation = newValue;
                      });
                    },
                    validator: (value) {
                      // Meet up location is always required since only Meet Up is available
                      if (value == null || value.isEmpty) {
                        return 'Please select a meet up location';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 32),

                // Post Listing Button
                CustomButton(
                  text: 'Post Listing',
                  onPressed: _handlePostListing,
                  isLoading: _isLoading,
                  backgroundColor: const Color(0xFFFFE500), // Brand yellow
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

