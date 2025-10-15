import 'screens/message_list_screen.dart';
import 'screens/post_details_screen.dart';
import 'screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'screens/categories_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'services/badge_update_service.dart';
import 'services/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> 
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _unreadNotificationCount = 0;
  String? _currentUserId;
  late PageController _pageController;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  
  // Animation controllers
  late AnimationController _fabAnimationController;
  late AnimationController _badgeAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _badgeBounceAnimation;

  @override
  void initState() {
    super.initState();
    print('🔍 NavigationWrapper: Initialized');
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Initialize animation controllers
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _badgeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Initialize animations
    _fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _badgeBounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _badgeAnimationController,
      curve: Curves.bounceOut,
    ));
    
    _loadUserData();
    _loadNotificationCount();
    _setupRealTimeListener();
    
    // Listen for badge updates from other screens
    BadgeUpdateService.addListener(_onBadgeUpdate);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _pageController.dispose();
    _fabAnimationController.dispose();
    _badgeAnimationController.dispose();
    BadgeUpdateService.removeListener(_onBadgeUpdate);
    super.dispose();
  }

  /// Called when badge count should be updated
  void _onBadgeUpdate() {
    print('🔔 Badge update requested from other screen');
    _loadNotificationCount();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('signup_user_id') ?? 
                     prefs.getString('current_user_id') ?? '';
    print('👤 NavigationWrapper user ID: $_currentUserId');
    
    // Set up real-time listener after getting user ID
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      _setupRealTimeListener();
    }
  }

  Future<void> _loadNotificationCount() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      print('🔔 Loading notification count for user: $_currentUserId');
      final count = await NotificationService.getUnreadCount(_currentUserId!);
      print('📊 Unread notification count: $count');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
        
        // Animate badge if there are new notifications
        if (count > 0) {
          _badgeAnimationController.forward().then((_) {
            _badgeAnimationController.reverse();
          });
        }
      }
    } else {
      print('❌ No current user ID for notification count');
    }
  }

  /// Manually refresh notification count (can be called from other screens)
  Future<void> refreshNotificationCount() async {
    print('🔄 Manually refreshing notification count...');
    await _loadNotificationCount();
  }

  void _setupRealTimeListener() {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      print('🔔 Setting up real-time listener for user: $_currentUserId');
      
      // Use the same Firestore instance as the notifications
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'marketsafe',
      );
      
      _notificationSubscription = firestore
          .collection('notifications')
          .where('userId', isEqualTo: _currentUserId)
          .snapshots()
          .listen((snapshot) {
        // Count unread notifications
        final unreadCount = snapshot.docs
            .where((doc) => (doc.data()['isRead'] ?? false) == false)
            .length;
        
        print('📊 Real-time unread count: $unreadCount');
        print('📊 Total notifications: ${snapshot.docs.length}');
        
        if (mounted) {
          setState(() {
            _unreadNotificationCount = unreadCount;
          });
        }
      }, onError: (error) {
        print('❌ NavigationWrapper real-time listener error: $error');
      });
    }
  }

  Widget _getPage(int index) {
    print('🔍 NavigationWrapper: Getting page at index $index');
    switch (index) {
      case 0:
        return const CategoriesScreen();
      case 1:
        print('🔍 Creating NotificationsScreen for index 1...');
        return NotificationsScreen();
      case 2:
        // Add button - entertaining design
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color(0xFF1a1a1a), Color(0xFF2B0000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Animated floating elements
              Positioned(
                top: 100,
                left: 50,
                child: _buildFloatingElement(Icons.shopping_cart, 0),
              ),
              Positioned(
                top: 200,
                right: 60,
                child: _buildFloatingElement(Icons.star, 1),
              ),
              Positioned(
                top: 300,
                left: 80,
                child: _buildFloatingElement(Icons.favorite, 2),
              ),
              Positioned(
                top: 150,
                right: 100,
                child: _buildFloatingElement(Icons.diamond, 3),
              ),
              Positioned(
                top: 400,
                left: 30,
                child: _buildFloatingElement(Icons.rocket_launch, 4),
              ),
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated icon
                    TweenAnimationBuilder<double>(
                      duration: const Duration(seconds: 2),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.red, Color(0xFFCC0000)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(60),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    // Animated text
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1500),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Column(
                              children: [
                                const Text(
                                  'Ready to Sell?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap the + button below\nto add your product',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Animated dots
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (index) {
                                    return TweenAnimationBuilder<double>(
                                      duration: Duration(milliseconds: 600 + (index * 200)),
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      builder: (context, value, child) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.3 + (0.7 * value)),
                                            shape: BoxShape.circle,
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 3:
        return const MessageListScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const CategoriesScreen();
    }
  }

  void _navigateToPost() {
    NavigationService.navigateWithLoading(
      context,
      const PostDetailsScreen(),
      loadingMessage: "Preparing product creation...",
      loadingDuration: const Duration(milliseconds: 600),
      transitionType: PageTransitionType.slideFromBottom,
    );
  }

  void _onBottomIconTap(int index) {
    if (index == 2) {
      // "+" button → navigate to PostDetailsScreen with animation
      _fabAnimationController.forward().then((_) {
        _fabAnimationController.reverse();
        _navigateToPost();
      });
    } else {
      // Animate page transition
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      
      // Refresh notification count when navigating to notifications
      if (index == 1) {
        _loadNotificationCount();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 NavigationWrapper: Building with selectedIndex: $_selectedIndex');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF1a1a1a), Color(0xFF2B0000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.7, 1.0],
          ),
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: [
            _getPage(0),
            _getPage(1),
            _getPage(2),
            _getPage(3),
            _getPage(4),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a1a1a), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, ''),
                _buildNavItem(1, Icons.notifications_rounded, ''),
                _buildFloatingActionButton(),
                _buildNavItem(3, Icons.chat_bubble_rounded, ''),
                _buildNavItem(4, Icons.person_rounded, ''),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final isNotificationTab = index == 1;
    
    return GestureDetector(
      onTap: () => _onBottomIconTap(index),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected ? Colors.red : Colors.white70,
                size: 24,
              ),
            ),
            if (isNotificationTab && _unreadNotificationCount > 0)
              Positioned(
                right: -8,
                top: -8,
                child: _buildNotificationBadge(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return GestureDetector(
      onTap: () => _onBottomIconTap(2),
      child: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Color(0xFFCC0000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingElement(IconData icon, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(seconds: 3 + (index * 2)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: 0.3 + (0.4 * value),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.red.withOpacity(0.6),
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationBadge() {
    if (_unreadNotificationCount <= 0) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _badgeBounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _badgeBounceAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.red, Color(0xFFCC0000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Text(
              _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

}
