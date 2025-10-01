import 'package:flutter/material.dart';
import 'conversation_screen.dart';

class MessageListScreen extends StatefulWidget {
  const MessageListScreen({super.key});

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  // Single user message state
  bool isUnread = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C0000),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Icon(Icons.menu, color: Colors.white),
                  Text(
                    "message",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Icon(Icons.notifications_none, color: Colors.white),
                ],
              ),
            ),

            // Search bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
              ),
            ),

            // Only 1 User
            ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () async {
                // Go to conversation
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConversationScreen(
                      userName: "FULL NAME",
                      userAddress: "ADDRESS",
                    ),
                  ),
                );

                // After returning, mark as read
                setState(() {
                  isUnread = false;
                });
              },
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                radius: 22,
              ),
              title: Text(
                "FULL NAME",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                isUnread
                    ? "this is the view of unread messages"
                    : "this is the view of read messages",
                style: TextStyle(
                  color: isUnread ? Colors.white : Colors.grey.shade400,
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: const Text(
                "12:30",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
