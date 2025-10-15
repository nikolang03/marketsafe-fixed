import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../widgets/image_swiper.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  
  String? _selectedCategory;
  String? _selectedCondition;
  List<File> _newImages = [];
  bool _isLoading = false;

  final List<String> _categories = [
    'Accessories',
    'Electronics', 
    'Furniture',
    'Men\'s Wear',
    'Women\'s Wear',
    'Vehicle',
  ];

  final List<String> _conditions = [
    'New',
    'Like New',
    'Good',
    'Fair',
    'Poor',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.product.title);
    _descriptionController = TextEditingController(text: widget.product.description);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _selectedCategory = widget.product.category;
    _selectedCondition = widget.product.condition;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _addMoreImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }



  Future<void> _updateProduct() async {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid price")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Updating product...');
      
      // Prepare update data
      final updateData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'category': _selectedCategory!,
        'condition': _selectedCondition!,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // If new images are selected, upload them
      if (_newImages.isNotEmpty) {
        print('📤 Uploading ${_newImages.length} new images...');
        final List<String> newImageUrls = [];
        for (int i = 0; i < _newImages.length; i++) {
          final imageUrl = await ProductService.uploadProductImage(_newImages[i], '${widget.product.id}_new_$i');
          newImageUrls.add(imageUrl);
          print('✅ New image ${i + 1} uploaded: $imageUrl');
        }
        
        // Combine existing images with new ones
        final allImageUrls = [...widget.product.imageUrls, ...newImageUrls];
        updateData['imageUrls'] = allImageUrls;
        updateData['imageUrl'] = allImageUrls.isNotEmpty ? allImageUrls.first : '';
        print('✅ All images updated: ${allImageUrls.length} total');
      }

      // Update product in database
      final success = await ProductService.updateProduct(widget.product.id, updateData);
      
      if (success) {
        print('✅ Product updated successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Product updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        throw Exception('Failed to update product');
      }
    } catch (e) {
      print('❌ Error updating product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update product: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E0000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E0000),
        elevation: 0,
        title: const Text(
          "EDIT PRODUCT",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateProduct,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "SAVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with swiper
            Stack(
                  children: [
                    // Show existing images or new images
                    SizedBox(
                      height: (_newImages.isNotEmpty && _newImages.length > 1) || 
                              (widget.product.imageUrls.isNotEmpty && widget.product.imageUrls.length > 1) 
                              ? 332 : 300, // Match ImageSwiper height + space for dots/counter
                      width: double.infinity,
                      child: _newImages.isNotEmpty
                          ? ImageSwiper(
                              imageUrls: _newImages.map((file) => file.path).toList(),
                              height: 300,
                              showDots: true,
                              showCounter: true,
                              enableCropping: false,
                            )
                          : widget.product.imageUrls.isNotEmpty
                              ? ImageSwiper(
                                  imageUrls: widget.product.imageUrls,
                                  height: 300,
                                  showDots: true,
                                  showCounter: true,
                                  enableCropping: false,
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.add_photo_alternate,
                                    color: Colors.white54,
                                    size: 50,
                                  ),
                                ),
                    ),
                    
                    // Add more images button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FloatingActionButton.small(
                        onPressed: _addMoreImages,
                        backgroundColor: Colors.black.withOpacity(0.6),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                    
                    // Remove image button (if new images exist)
                    if (_newImages.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: FloatingActionButton.small(
                          onPressed: () => _removeNewImage(0),
                          backgroundColor: Colors.red.withOpacity(0.8),
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                  ],
                ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                "Tap + to add more images",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Title field
            const Text(
              "Title",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter product title",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Price field
            const Text(
              "Price (₱)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter price",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category dropdown
            const Text(
              "Category",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A0000),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Condition dropdown
            const Text(
              "Condition",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCondition,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A0000),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: _conditions.map((String condition) {
                    return DropdownMenuItem<String>(
                      value: condition,
                      child: Text(condition),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCondition = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description field
            const Text(
              "Description",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Describe your product",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
