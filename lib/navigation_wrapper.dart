import 'dart:io';
import 'package:capstone2/screens/message_list_screen.dart';
import 'package:capstone2/screens/post_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'screens/categories_screen.dart';
import 'screens/profile_screen.dart';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key, required CategoriesScreen child});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CategoriesScreen(), // Home
    Center(child: Text("Search Page", style: TextStyle(color: Colors.white))),
    Center(child: Text("Placeholder", style: TextStyle(color: Colors.white))), // Placeholder for Add
    const MessageListScreen(),
    const ProfileScreen(),
  ];

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailsScreen(image: File(pickedFile.path)),
        ),
      );
    }
  }

  void _onBottomIconTap(int index) {
    if (index == 2) {
      // "+" button → open gallery instead of switching page
      _pickImage(context);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF2B0000)],
            begin: Alignment.topRight,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _bottomIcon(Icons.home, 0),
            _bottomIcon(Icons.search, 1),
            _bottomIcon(Icons.add_box_outlined, 2),
            _bottomIcon(Icons.chat_bubble_outline, 3),
            _bottomIcon(Icons.person_outline, 4),
          ],
        ),
      ),
    );
  }

  Widget _bottomIcon(IconData icon, int index) {
    final bool isSelected = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _onBottomIconTap(index),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Icon(
            icon,
            size: isSelected ? 30 : 28,
            color: isSelected ? Colors.red : Colors.white,
          ),
        ),
      ),
    );
  }
}
