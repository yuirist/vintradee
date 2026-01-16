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
import 'package:cached_network_image/cached_network_image.dart';

class EditListingScreen extends StatefulWidget {
  final String productId;

  const EditListingScreen({super.key, required this.productId});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
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
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isLoadingProduct = true;
  String? _sellerName;
  String? _sellerFaculty;
  String? _sellerStudentId;

  final List<String> _categories = ['Textbooks', 'Shoes', 'Electronics', 'Furniture', 'Clothing'];
  final List<String> _conditions = ['Excellent', 'Good', 'Fair', 'Poor'];
  final List<String> _dealMethods = ['Meet Up', 'Postage'];
  final List<String> _meetupLocations = [
    'Tunku Tun Aminah Library',
    'Kolej Kediaman Perwira',
    'FSKTM, Faculty of Computer and Technology',
    'Masjid Sultan Ibrahim UTHM',
  ];

  @override
  void initState() {
    super.initState();
    _loadProduct();
    _loadSellerName();
  }

  Future<void> _loadProduct() async {
    try {
      final product = await _firebaseService.getProductById(widget.productId);
      if (product != null) {
        // Also fetch deal method and location from Firestore
        final doc = await _firestore
            .collection(AppConstants.productsCollection)
            .doc(widget.productId)
            .get();
        
        final data = doc.data();
        
        // Normalize condition value to match dropdown items (capitalize first letter)
        String? normalizedCondition;
        final conditionString = product.condition.toString().split('.').last.toLowerCase();
        try {
          // Find the matching capitalized version
          normalizedCondition = _conditions.firstWhere(
            (c) => c.toLowerCase() == conditionString,
            orElse: () => _conditions.first,
          );
        } catch (e) {
          normalizedCondition = null; // Will default to null if not found
        }
        
        // Normalize category - ensure it exists in the list
        String? normalizedCategory = _categories.contains(product.category)
            ? product.category
            : null;
        
        // Normalize deal method - ensure it exists in the list
        String? normalizedDealMethod = data?['dealMethod'] != null
            ? (_dealMethods.contains(data!['dealMethod'] as String)
                ? data['dealMethod'] as String
                : null)
            : null;
        
        // Normalize location - ensure it exists in the list
        String? normalizedLocation = data?['meetupLocation'] != null
            ? (_meetupLocations.contains(data!['meetupLocation'] as String)
                ? data['meetupLocation'] as String
                : null)
            : null;
        
        setState(() {
          _productNameController.text = product.title;
          _priceController.text = product.price.toStringAsFixed(2);
          _descriptionController.text = product.description;
          _selectedCategory = normalizedCategory;
          _selectedCondition = normalizedCondition;
          _selectedDealMethod = normalizedDealMethod;
          _selectedLocation = normalizedLocation;
          _existingImageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
          _isLoadingProduct = false;
        });
      } else {
        setState(() {
          _isLoadingProduct = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product not found'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error loading product: $e');
      setState(() {
        _isLoadingProduct = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading product: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
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
          _existingImageUrl = null; // Clear existing URL when new image is selected
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

  Future<void> _handleUpdateListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null && _existingImageUrl == null) {
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

    if (_selectedDealMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a deal method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDealMethod == 'Meet Up' && (_selectedLocation == null || _selectedLocation!.isEmpty)) {
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
          content: Text('Please log in to update a listing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String imageUrl = _existingImageUrl ?? '';
      
      // Upload new image if one was selected
      if (_selectedImage != null) {
        debugPrint('🖼️ Starting image upload to Cloudinary...');
        imageUrl = await _cloudinaryService.uploadImage(_selectedImage!);
        debugPrint('✅ Image upload completed. URL: $imageUrl');
      }

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

      // Update product document in Firestore
      await _firestore
          .collection(AppConstants.productsCollection)
          .doc(widget.productId)
          .update({
        'title': _productNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'category': _selectedCategory!,
        'condition': condition.toString().split('.').last,
        'imageUrls': [imageUrl],
        'dealMethod': _selectedDealMethod,
        'meetupLocation': _selectedDealMethod == 'Meet Up' ? _selectedLocation : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating listing: $e'),
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
    if (_isLoadingProduct) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: Text(
            'Edit Listing',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          'Edit Listing',
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
                        : _existingImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(
                                  imageUrl: _existingImageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppTheme.secondaryGrey,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: AppTheme.secondaryGrey,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
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
                  value: _selectedCategory != null && _categories.contains(_selectedCategory)
                      ? _selectedCategory
                      : null,
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
                  value: _selectedCondition != null && _conditions.contains(_selectedCondition)
                      ? _selectedCondition
                      : null,
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
                  value: _selectedDealMethod != null && _dealMethods.contains(_selectedDealMethod)
                      ? _selectedDealMethod
                      : null,
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
                      _selectedDealMethod = newValue;
                      // Clear location if switching to Postage
                      if (newValue == 'Postage') {
                        _selectedLocation = null;
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a deal method';
                    }
                    return null;
                  },
                ),
                
                // Meet Up Location Dropdown (conditional)
                if (_selectedDealMethod == 'Meet Up') ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedLocation != null && _meetupLocations.contains(_selectedLocation)
                        ? _selectedLocation
                        : null,
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
                      if (_selectedDealMethod == 'Meet Up' && (value == null || value.isEmpty)) {
                        return 'Please select a meet up location';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 32),

                // Update Listing Button
                CustomButton(
                  text: 'Update Listing',
                  onPressed: _handleUpdateListing,
                  isLoading: _isLoading,
                  backgroundColor: const Color(0xFFDBC156), // Brand yellow
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

