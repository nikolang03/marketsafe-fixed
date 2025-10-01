import 'package:flutter/material.dart';


class MensWearScreen extends StatefulWidget {
  const MensWearScreen({super.key});

  @override
  State<MensWearScreen> createState() => _MensWearScreenState();
}

class _MensWearScreenState extends State<MensWearScreen> {
  int likeCount = 0;
  int commentCount = 0;
  bool isLiked = false;

  // For comments
  final List<String> _comments = [
    "Nice item!",
    "I want this!",
    "Is it still available?",
  ];
  final TextEditingController _commentController = TextEditingController();

  // For price filter
  double minPrice = 0;
  double maxPrice = 10000;
  double selectedMin = 0;
  double selectedMax = 10000;

  // Example item price
  double itemPrice = 2500; // <-- base price

  void _toggleLike() {
    setState(() {
      if (isLiked) {
        likeCount--;
        isLiked = false;
      } else {
        likeCount++;
        isLiked = true;
      }
    });
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0000),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void _addComment() {
              final text = _commentController.text.trim();
              if (text.isNotEmpty) {
                setModalState(() {
                  _comments.add(text);
                  commentCount++;
                  _commentController.clear();
                });
              }
            }

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Comments",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _comments.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: const Text("username",
                            style: TextStyle(color: Colors.white)),
                        subtitle: Text(_comments[index],
                            style: const TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 8,
                      right: 8,
                      top: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Add a comment...",
                              hintStyle: TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white24,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius:
                                BorderRadius.all(Radius.circular(20)),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 10),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _addComment,
                          icon: const Icon(Icons.send, color: Colors.white),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterDialog() {
    final TextEditingController minController = TextEditingController();
    final TextEditingController maxController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0000),
          title: const Text(
            "Filter by Price",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Min Price",   // 👈 indicator only
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white24,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Max Price",   // 👈 indicator only
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white24,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  selectedMin = double.tryParse(minController.text) ?? 1;
                  selectedMax = double.tryParse(maxController.text) ?? 30000;

                  // Clamp range
                  if (selectedMin < 1) selectedMin = 1;
                  if (selectedMax > 30000) selectedMax = 30000;
                  if (selectedMin > selectedMax) {
                    selectedMin = 1;
                    selectedMax = 30000;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text("Apply", style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Apply filter check
    bool isVisible =
        itemPrice >= selectedMin && itemPrice <= selectedMax;

    return Scaffold(
      backgroundColor: const Color(0xFF2E0000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E0000),
        elevation: 0,
        title: const Text(
          "MEN'S WEAR",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/logo.png"), // your logo
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),

      body: isVisible
          ? ListView.builder(
        itemCount: 1,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            color: const Color(0xFF1A0000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: const Text(
                    "username",
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(60, 30),
                    ),
                    onPressed: () {},
                    child: const Text("Follow"),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    "TITLE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    "₱$itemPrice",
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: size.height * 0.3,
                  color: Colors.grey[400],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text("$likeCount",
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.mode_comment_outlined,
                            color: Colors.white),
                        onPressed: () => _showComments(context),
                      ),
                      Text("$commentCount",
                          style: const TextStyle(color: Colors.white)),
                      const Spacer(),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        onPressed: () {},
                        child: const Text("MAKE OFFER"),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.bookmark_border,
                            color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    "username description",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      )
          : const Center(
        child: Text(
          "No items in this price range",
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
