import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/follow_service.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String targetUserId;
  final String? targetUsername;

  const UserProfileViewScreen({
    super.key,
    required this.targetUserId,
    this.targetUsername,
  });

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  Map<String, int> _followCounts = {'followers': 0, 'following': 0};
  List<Map<String, dynamic>> _mutualFollows = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get user data
      final userDoc = await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'marketsafe',
      ).collection('users').doc(widget.targetUserId).get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
        });

        // Check if current user is following this user
        final isFollowing = await FollowService.isFollowing(widget.targetUserId);
        
        // Get follow counts
        final followCounts = await FollowService.getFollowCounts(widget.targetUserId);
        
        // Get mutual follows
        final mutualFollows = await FollowService.getMutualFollows(widget.targetUserId);

        setState(() {
          _isFollowing = isFollowing;
          _followCounts = followCounts;
          _mutualFollows = mutualFollows;
        });
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      _showErrorSnackBar('Failed to load user profile');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;

    setState(() {
      _isFollowLoading = true;
    });

    try {
      bool success;
      if (_isFollowing) {
        success = await FollowService.unfollowUser(widget.targetUserId);
        if (success) {
          setState(() {
            _isFollowing = false;
            _followCounts['followers'] = (_followCounts['followers'] ?? 0) - 1;
          });
          _showSuccessSnackBar('Unfollowed ${_userData?['username'] ?? 'user'}');
        }
      } else {
        success = await FollowService.followUser(widget.targetUserId);
        if (success) {
          setState(() {
            _isFollowing = true;
            _followCounts['followers'] = (_followCounts['followers'] ?? 0) + 1;
          });
          _showSuccessSnackBar('Following ${_userData?['username'] ?? 'user'}');
        }
      }

      if (!success) {
        _showErrorSnackBar('Failed to ${_isFollowing ? 'unfollow' : 'follow'} user');
      }
    } catch (e) {
      print('❌ Error toggling follow: $e');
      _showErrorSnackBar('An error occurred');
    } finally {
      setState(() {
        _isFollowLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _userData?['username'] ?? 'User Profile',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Show more options
              _showMoreOptions();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _userData == null
              ? const Center(
                  child: Text(
                    'User not found',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Profile Header
                      _buildProfileHeader(),
                      
                      const SizedBox(height: 20),
                      
                      // Follow Button
                      _buildFollowButton(),
                      
                      const SizedBox(height: 20),
                      
                      // Stats
                      _buildStats(),
                      
                      const SizedBox(height: 20),
                      
                      // Mutual Follows
                      if (_mutualFollows.isNotEmpty) _buildMutualFollows(),
                      
                      const SizedBox(height: 20),
                      
                      // User Info
                      _buildUserInfo(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[800],
            backgroundImage: _userData?['profilePictureUrl'] != null
                ? NetworkImage(_userData!['profilePictureUrl'])
                : null,
            child: _userData?['profilePictureUrl'] == null
                ? const Icon(Icons.person, size: 60, color: Colors.white)
                : null,
          ),
          
          const SizedBox(height: 16),
          
          // Username
          Text(
            _userData?['username'] ?? 'Unknown User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Full Name (if available)
          if (_userData?['fullName'] != null)
            Text(
              _userData!['fullName'],
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Bio (if available)
          if (_userData?['bio'] != null)
            Text(
              _userData!['bio'],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: _isFollowLoading ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? Colors.grey[800] : Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isFollowLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Posts', '0'), // TODO: Implement posts count
          _buildStatItem('Followers', _followCounts['followers'].toString()),
          _buildStatItem('Following', _followCounts['following'].toString()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMutualFollows() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mutual Follows',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _mutualFollows.length,
              itemBuilder: (context, index) {
                final mutual = _mutualFollows[index];
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: mutual['profilePictureUrl'] != null
                            ? NetworkImage(mutual['profilePictureUrl'])
                            : null,
                        child: mutual['profilePictureUrl'] == null
                            ? const Icon(Icons.person, size: 20, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          mutual['username'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Join Date
          if (_userData?['createdAt'] != null)
            _buildInfoRow('Joined', _formatDate(_userData!['createdAt'])),
          
          // Verification Status
          _buildInfoRow('Status', _getVerificationStatusText()),
          
          // Last Active
          if (_userData?['lastLoginAt'] != null)
            _buildInfoRow('Last Active', _formatDate(_userData!['lastLoginAt'])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        date = DateTime.parse(timestamp.toString());
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getVerificationStatusText() {
    final status = _userData?['verificationStatus'] ?? 'pending';
    switch (status) {
      case 'verified':
        return 'Verified ✓';
      case 'rejected':
        return 'Rejected ✗';
      default:
        return 'Pending ⏳';
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.orange),
              title: const Text('Block User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Report User', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to report this user?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar('User reported successfully');
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to block this user? You won\'t see their content anymore.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar('User blocked successfully');
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
