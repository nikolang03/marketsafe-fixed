import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );

  /// Get all conversations for a user
  static Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      print('💬 MessageService: Getting conversations for user: $userId');
      
      if (userId.isEmpty) {
        print('❌ getConversations: User ID is empty');
        return [];
      }
      
      // Clean up invalid conversations first
      await deleteInvalidConversations(userId);
      
      // Get conversations where user is either sender or receiver
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageAt', descending: true)
          .get();

      List<Map<String, dynamic>> conversations = [];
      
      for (var doc in conversationsSnapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        // Get the other participant's info
        String otherUserId;
        print('🔍 Participants in conversation: $participants');
        print('🔍 Current user ID: $userId');
        
        // Remove duplicates and filter out current user
        final otherParticipants = participants.where((id) => id != userId).toSet().toList();
        print('🔍 Other participants after filtering: $otherParticipants');
        
        if (otherParticipants.isNotEmpty) {
          otherUserId = otherParticipants.first;
        } else if (participants.contains(userId)) {
          // This is a self-conversation
          print('🔍 This is a self-conversation, using current user as other user');
          otherUserId = userId;
        } else {
          print('❌ No valid participants found, skipping conversation');
          continue;
        }
        
        print('🔍 Getting user data for otherUserId: $otherUserId');
        final otherUserData = await getUserData(otherUserId);
        print('🔍 Retrieved user data: $otherUserData');
        
        // Skip conversations with invalid user data (Unknown User with empty ID)
        if (otherUserData['id'].isEmpty || otherUserData['name'] == 'Unknown User') {
          print('❌ Skipping conversation with invalid user data: $otherUserData');
          continue;
        }
        
        conversations.add({
          'conversationId': doc.id,
          'otherUser': otherUserData,
          'lastMessage': data['lastMessage'] ?? '',
          'lastMessageAt': data['lastMessageAt'],
          'unreadCount': data['unreadCounts']?[userId] ?? 0,
        });
      }
      
      print('💬 Found ${conversations.length} conversations');
      return conversations;
    } catch (e) {
      print('❌ Error getting conversations: $e');
      return [];
    }
  }

  /// Get messages for a specific conversation
  static Stream<List<Map<String, dynamic>>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'senderId': data['senderId'],
          'text': data['text'],
          'timestamp': data['timestamp'],
          'isRead': data['isRead'] ?? false,
        };
      }).toList();
    });
  }

  /// Send a message
  static Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      print('💬 MessageService: Sending message in conversation: $conversationId');
      
      final messageData = {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Add message to conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData);

      // Update conversation metadata
      final otherParticipant = await _getOtherParticipant(conversationId, senderId);
      
      // If otherParticipant is empty (self-conversation), use senderId
      final targetParticipant = otherParticipant.isEmpty ? senderId : otherParticipant;
      print('🔍 Target participant for unread count: $targetParticipant');
      
      // Get current unread counts
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      final currentData = conversationDoc.data() ?? {};
      final unreadCounts = Map<String, int>.from(currentData['unreadCounts'] ?? {});
      unreadCounts[targetParticipant] = (unreadCounts[targetParticipant] ?? 0) + 1;
      
      print('🔍 Updated unread counts: $unreadCounts');
      
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
      });

      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Create or get existing conversation between two users
  static Future<String> getOrCreateConversation(String userId1, String userId2) async {
    try {
      print('💬 MessageService: Getting/creating conversation between $userId1 and $userId2');
      
      // Validate user IDs
      if (userId1.isEmpty || userId2.isEmpty) {
        throw Exception('User IDs cannot be empty: userId1=$userId1, userId2=$userId2');
      }
      
      // Check if conversation already exists
      final existingConversation = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId1)
          .get();

      for (var doc in existingConversation.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(userId2)) {
          print('✅ Found existing conversation: ${doc.id}');
          return doc.id;
        }
      }

      // Create new conversation
      final conversationData = {
        'participants': [userId1, userId2],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts': {
          userId1: 0,
          userId2: 0,
        },
      };

      final docRef = await _firestore
          .collection('conversations')
          .add(conversationData);

      print('✅ Created new conversation: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating conversation: $e');
      throw Exception('Failed to create conversation: $e');
    }
  }

  /// Mark messages as read
  static Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      print('💬 MessageService: Marking messages as read in conversation: $conversationId');
      
      // Get all unread messages (simpler query without complex where clauses)
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      // Filter and update messages that are not from the current user
      for (var doc in messagesSnapshot.docs) {
        final messageData = doc.data();
        final senderId = messageData['senderId'] as String?;
        
        if (senderId != null && senderId != userId) {
          await doc.reference.update({'isRead': true});
        }
      }

      // Reset unread count for the current user in the conversation document
      final conversationRef = _firestore.collection('conversations').doc(conversationId);
      final conversationDoc = await conversationRef.get();
      
      if (conversationDoc.exists) {
        final currentData = conversationDoc.data() ?? {};
        final unreadCounts = Map<String, int>.from(currentData['unreadCounts'] ?? {});
        unreadCounts[userId] = 0;
        
        await conversationRef.update({'unreadCounts': unreadCounts});
      }

      print('✅ Messages marked as read');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  /// Get user data by ID
  static Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      // Check if userId is valid
      if (userId.isEmpty) {
        print('❌ getUserData: User ID is empty');
        return {
          'id': '',
          'name': 'Unknown User',
          'email': '',
          'profilePictureUrl': '',
        };
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        print('🔍 User document found for $userId:');
        print('  - Username: ${data['username']}');
        print('  - First Name: ${data['firstName']}');
        print('  - Last Name: ${data['lastName']}');
        print('  - Full Name: ${data['fullName']}');
        print('  - Email: ${data['email']}');
        print('  - Profile Picture: ${data['profilePictureUrl']}');
        print('  - All fields: ${data.keys.toList()}');
        
        // Try different name fields
        String displayName = data['username'] ?? 
                           data['fullName'] ?? 
                           '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim() ??
                           'Unknown User';
        
        if (displayName.isEmpty) {
          displayName = 'Unknown User';
        }
        
        print('🔍 Final display name: $displayName');
        
        return {
          'id': userId,
          'name': displayName,
          'email': data['email'] ?? '',
          'profilePictureUrl': data['profilePictureUrl'] ?? '',
        };
      } else {
        print('❌ User document not found for $userId');
        return {
          'id': userId,
          'name': 'Unknown User',
          'email': '',
          'profilePictureUrl': '',
        };
      }
    } catch (e) {
      print('❌ Error getting user data: $e');
      return {
        'id': userId,
        'name': 'Unknown User',
        'email': '',
        'profilePictureUrl': '',
      };
    }
  }

  /// Get the other participant in a conversation
  static Future<String> _getOtherParticipant(String conversationId, String currentUserId) async {
    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        final participants = List<String>.from(conversationDoc.data()!['participants'] ?? []);
        try {
          return participants.firstWhere((id) => id != currentUserId);
        } catch (e) {
          print('❌ Error finding other participant in _getOtherParticipant: $e');
          // If no other participant found, it might be a self-conversation
          if (participants.length == 1 && participants.contains(currentUserId)) {
            print('🔍 This is a self-conversation in _getOtherParticipant, using current user');
            return currentUserId; // Use the same user for self-conversations
          }
          return '';
        }
      }
      return '';
    } catch (e) {
      print('❌ Error getting other participant: $e');
      return '';
    }
  }

  /// Get current user ID
  static Future<String?> getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('signup_user_id') ?? 
             prefs.getString('current_user_id');
    } catch (e) {
      print('❌ Error getting current user ID: $e');
      return null;
    }
  }

  /// Delete invalid conversations (conversations with Unknown User)
  static Future<void> deleteInvalidConversations(String userId) async {
    try {
      print('🧹 Cleaning up invalid conversations for user: $userId');
      
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .get();

      for (var doc in conversationsSnapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        // Find other participant
        final otherParticipants = participants.where((id) => id != userId).toSet().toList();
        String otherUserId;
        
        if (otherParticipants.isNotEmpty) {
          otherUserId = otherParticipants.first;
        } else if (participants.contains(userId)) {
          otherUserId = userId; // Self-conversation
        } else {
          continue; // Skip invalid conversation
        }
        
        // Check if other user data is valid
        final otherUserData = await getUserData(otherUserId);
        
        // If user data is invalid, delete the conversation
        if (otherUserData['id'].isEmpty || otherUserData['name'] == 'Unknown User') {
          print('🗑️ Deleting invalid conversation: ${doc.id}');
          
          // Delete all messages in this conversation
          final messagesSnapshot = await _firestore
              .collection('conversations')
              .doc(doc.id)
              .collection('messages')
              .get();
          
          for (var messageDoc in messagesSnapshot.docs) {
            await messageDoc.reference.delete();
          }
          
          // Delete the conversation document
          await doc.reference.delete();
        }
      }
      
      print('✅ Invalid conversations cleanup completed');
    } catch (e) {
      print('❌ Error cleaning up invalid conversations: $e');
    }
  }
}
