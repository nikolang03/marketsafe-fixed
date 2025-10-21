class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isRead,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}

class Conversation {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final Map<String, dynamic> otherUser;

  Conversation({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.otherUser,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['conversationId'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageAt: map['lastMessageAt']?.toDate() ?? DateTime.now(),
      unreadCount: map['unreadCount'] ?? 0,
      otherUser: map['otherUser'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'unreadCount': unreadCount,
      'otherUser': otherUser,
    };
  }
}










