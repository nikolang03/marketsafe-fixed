import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Import your category screens here
import '../navigation_wrapper.dart';
import 'categories/accessories_screen.dart';
import 'categories/electronics_screen.dart';
import 'categories/furniture_screen.dart';
import 'categories/menswear_screen.dart';
import 'categories/vehicle_screen.dart';
import 'categories/womenswear_screen.dart';
import 'categories_screen.dart';

class PostDetailsScreen extends StatefulWidget {
  final File image;
  const PostDetailsScreen({super.key, required this.image});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  late File _image;
  String? _selectedCategory;
  String? _selectedCondition;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _image = widget.image;
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _uploadPost() {
    if (_selectedCategory == null ||
        _titleController.text.isEmpty ||
        _selectedCondition == null ||
        _priceController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    // Navigate to the selected category screen
    Widget destination;
    switch (_selectedCategory) {
      case "Accessories":
        destination = const AccessoriesScreen();
        break;
      case "Electronics":
        destination = const ElectronicsScreen();
        break;
      case "Furniture":
        destination = const FurnitureScreen();
        break;
      case "Men's Wear":
        destination = const MensWearScreen();
        break;
      case "Women's Wear":
        destination = const WomensWearScreen();
        break;
      case "Vehicle":
        destination = const VehiclesScreen();
        break;
      default:
        destination = const AccessoriesScreen(); // fallback
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF2B0000)],
            begin: Alignment.topRight,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Top bar with close + "List now"
            Container(
              color: const Color(0xFF4B0000),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context,
                        MaterialPageRoute(builder: (_) => NavigationWrapper(child: CategoriesScreen()))), // 👈 close
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                  GestureDetector(
                    onTap: _uploadPost, // 👈 upload
                    child: const Text(
                      "List now",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Image preview
            Container(
              height: 200,
              color: Colors.black,
              width: double.infinity,
              child: _image.path.isNotEmpty
                  ? Image.file(_image, fit: BoxFit.cover)
                  : const Icon(Icons.image, color: Colors.white54, size: 80),
            ),

            // Change photo button
            TextButton(
              onPressed: _changePhoto,
              child: const Text(
                "Change Photo",
                style: TextStyle(color: Colors.red),
              ),
            ),

            // Form fields
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      dropdownColor: Colors.black,
                      decoration: const InputDecoration(
                        labelText: "CATEGORY",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: "Accessories", child: Text("Accessories", style: TextStyle(color: Colors.white),)),
                        DropdownMenuItem(
                            value: "Electronics", child: Text("Electronics", style: TextStyle(color: Colors.white),)),
                        DropdownMenuItem(
                            value: "Furniture", child: Text("Furniture", style: TextStyle(color: Colors.white),)),
                        DropdownMenuItem(
                            value: "Men's Wear", child: Text("Men's Wear", style: TextStyle(color: Colors.white),)),
                        DropdownMenuItem(
                            value: "Women's Wear", child: Text("Women's Wear", style: TextStyle(color: Colors.white),)),
                        DropdownMenuItem(
                            value: "Vehicle", child: Text("Vehicle", style: TextStyle(color: Colors.white),)),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),

                    // Title
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "TITLE",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                      ),
                    ),

                    // Condition Dropdown
                    DropdownButtonFormField<String>(
                      dropdownColor: Colors.black,
                      decoration: const InputDecoration(
                        labelText: "CONDITION",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: "New", child: Text("New", style: TextStyle(color: Colors.white),)),
                        DropdownMenuItem(value: "Used", child: Text("Used", style: TextStyle(color: Colors.white),)),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCondition = value);
                      },
                    ),

                    // Price
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "PRICE",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                      ),
                    ),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "DESCRIPTION",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
