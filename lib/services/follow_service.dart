import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FollowService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'marketsafe',
  );

  /// Follow a user
  static Future<bool> followUser(String targetUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? 
                           prefs.getString('signup_user_id') ?? '';
      
      if (currentUserId.isEmpty) {
        print('❌ No current user ID found');
        return false;
      }

      if (currentUserId == targetUserId) {
        print('❌ Cannot follow yourself');
        return false;
      }

      // Add to current user's following list
      await _firestore.collection('users').doc(currentUserId).update({
        'following': FieldValue.arrayUnion([targetUserId]),
        'followingCount': FieldValue.increment(1),
        'lastFollowedAt': FieldValue.serverTimestamp(),
      });

      // Add to target user's followers list
      await _firestore.collection('users').doc(targetUserId).update({
        'followers': FieldValue.arrayUnion([currentUserId]),
        'followersCount': FieldValue.increment(1),
        'lastFollowedAt': FieldValue.serverTimestamp(),
      });

      // Create follow relationship document
      await _firestore.collection('follows').add({
        'followerId': currentUserId,
        'followingId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      print('✅ Successfully followed user: $targetUserId');
      return true;
    } catch (e) {
      print('❌ Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  static Future<bool> unfollowUser(String targetUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? 
                           prefs.getString('signup_user_id') ?? '';
      
      if (currentUserId.isEmpty) {
        print('❌ No current user ID found');
        return false;
      }

      // Remove from current user's following list
      await _firestore.collection('users').doc(currentUserId).update({
        'following': FieldValue.arrayRemove([targetUserId]),
        'followingCount': FieldValue.increment(-1),
      });

      // Remove from target user's followers list
      await _firestore.collection('users').doc(targetUserId).update({
        'followers': FieldValue.arrayRemove([currentUserId]),
        'followersCount': FieldValue.increment(-1),
      });

      // Update follow relationship document
      await _firestore.collection('follows')
          .where('followerId', isEqualTo: currentUserId)
          .where('followingId', isEqualTo: targetUserId)
          .get()
          .then((querySnapshot) {
        for (var doc in querySnapshot.docs) {
          doc.reference.update({
            'status': 'inactive',
            'unfollowedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ Successfully unfollowed user: $targetUserId');
      return true;
    } catch (e) {
      print('❌ Error unfollowing user: $e');
      return false;
    }
  }

  /// Check if current user is following target user
  static Future<bool> isFollowing(String targetUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? 
                           prefs.getString('signup_user_id') ?? '';
      
      if (currentUserId.isEmpty) return false;

      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final following = userData['following'] as List<dynamic>? ?? [];
      
      return following.contains(targetUserId);
    } catch (e) {
      print('❌ Error checking follow status: $e');
      return false;
    }
  }

  /// Get user's followers list
  static Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final followers = userData['followers'] as List<dynamic>? ?? [];
      
      List<Map<String, dynamic>> followersList = [];
      
      for (String followerId in followers) {
        final followerDoc = await _firestore.collection('users').doc(followerId).get();
        if (followerDoc.exists) {
          final followerData = followerDoc.data()!;
          followersList.add({
            'userId': followerId,
            'username': followerData['username'] ?? 'Unknown User',
            'profilePictureUrl': followerData['profilePictureUrl'] ?? '',
            'followedAt': followerData['lastFollowedAt'],
          });
        }
      }
      
      return followersList;
    } catch (e) {
      print('❌ Error getting followers: $e');
      return [];
    }
  }

  /// Get user's following list
  static Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final following = userData['following'] as List<dynamic>? ?? [];
      
      List<Map<String, dynamic>> followingList = [];
      
      for (String followingId in following) {
        final followingDoc = await _firestore.collection('users').doc(followingId).get();
        if (followingDoc.exists) {
          final followingData = followingDoc.data()!;
          followingList.add({
            'userId': followingId,
            'username': followingData['username'] ?? 'Unknown User',
            'profilePictureUrl': followingData['profilePictureUrl'] ?? '',
            'followedAt': followingData['lastFollowedAt'],
          });
        }
      }
      
      return followingList;
    } catch (e) {
      print('❌ Error getting following: $e');
      return [];
    }
  }

  /// Get follow counts for a user
  static Future<Map<String, int>> getFollowCounts(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'followers': 0, 'following': 0};
      }

      final userData = userDoc.data()!;
      return {
        'followers': userData['followersCount'] ?? 0,
        'following': userData['followingCount'] ?? 0,
      };
    } catch (e) {
      print('❌ Error getting follow counts: $e');
      return {'followers': 0, 'following': 0};
    }
  }

  /// Get mutual follows between current user and target user
  static Future<List<Map<String, dynamic>>> getMutualFollows(String targetUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? 
                           prefs.getString('signup_user_id') ?? '';
      
      if (currentUserId.isEmpty) return [];

      // Get current user's following
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserData = currentUserDoc.data()!;
      final currentUserFollowing = currentUserData['following'] as List<dynamic>? ?? [];

      // Get target user's following
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      final targetUserData = targetUserDoc.data()!;
      final targetUserFollowing = targetUserData['following'] as List<dynamic>? ?? [];

      // Find mutual follows
      final mutualIds = currentUserFollowing.where((id) => targetUserFollowing.contains(id)).toList();
      
      List<Map<String, dynamic>> mutualFollows = [];
      
      for (String mutualId in mutualIds) {
        final mutualDoc = await _firestore.collection('users').doc(mutualId).get();
        if (mutualDoc.exists) {
          final mutualData = mutualDoc.data()!;
          mutualFollows.add({
            'userId': mutualId,
            'username': mutualData['username'] ?? 'Unknown User',
            'profilePictureUrl': mutualData['profilePictureUrl'] ?? '',
          });
        }
      }
      
      return mutualFollows;
    } catch (e) {
      print('❌ Error getting mutual follows: $e');
      return [];
    }
  }
}

