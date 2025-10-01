import 'package:flutter/material.dart';
import 'categories/accessories_screen.dart';
import 'categories/electronics_screen.dart';
import 'categories/furniture_screen.dart';
import 'categories/menswear_screen.dart';
import 'categories/womenswear_screen.dart';
import 'categories/vehicle_screen.dart';


class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _selectedIndex = 0; // 👈 track active bottom nav button

  final List<Map<String, String>> categories = [
    {"title": "ACCESSORIES", "image": "assets/logo.png"},
    {"title": "ELECTRONICS", "image": "assets/logo.png"},
    {"title": "FURNITURE", "image": "assets/logo.png"},
    {"title": "MEN'S WEAR", "image": "assets/logo.png"},
    {"title": "WOMEN'S WEAR", "image": "assets/logo.png"},
    {"title": "VEHICLE", "image": "assets/logo.png"},
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color(0xFF2B0000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
      child: SafeArea(
        child: Column(
          children: [
            // 🔝 Top Bar
            Container(
              color: const Color(0xFF5C0000),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset("assets/logo.png", height: 30),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        // TODO: Navigate to notifications later
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.notifications_none,
                            color: Colors.white, size: 25),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 📌 Banner
            Container(
              width: double.infinity,
              height: 120,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/logo.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 📌 Categories List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      switch (categories[index]["title"]) {
                        case "ACCESSORIES":
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AccessoriesScreen())
                          );
                          break;
                        case "ELECTRONICS":
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ElectronicsScreen()));
                          break;
                        case "FURNITURE":
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FurnitureScreen()));
                          break;
                        case "MEN'S WEAR":
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MensWearScreen()));
                          break;
                        case "WOMEN'S WEAR":
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WomensWearScreen()));
                          break;
                        case "VEHICLE":
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const VehiclesScreen()));
                          break;
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              categories[index]["image"]!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              categories[index]["title"]!,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
        ),
    );
    // 🔽 Bottom Nav
  }
  }
