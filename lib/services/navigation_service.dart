import 'package:flutter/material.dart';
import '../widgets/loading_screen.dart';
import '../utils/page_transitions.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Navigate with loading screen
  static Future<T?> navigateWithLoading<T>(
    BuildContext context,
    Widget destination, {
    String? loadingMessage,
    Duration? loadingDuration,
    PageTransitionType transitionType = PageTransitionType.slideFromRight,
  }) async {
    // Show loading screen
    _showLoadingOverlay(context, loadingMessage ?? "Loading...");
    
    // Simulate loading time or wait for actual operation
    if (loadingDuration != null) {
      await Future.delayed(loadingDuration);
    }
    
    // Hide loading screen
    _hideLoadingOverlay(context);
    
    // Navigate to destination
    return _navigateWithTransition<T>(context, destination, transitionType);
  }

  // Navigate with network loading
  static Future<T?> navigateWithNetworkLoading<T>(
    BuildContext context,
    Widget destination, {
    required String loadingMessage,
    required Future<void> networkOperation,
    PageTransitionType transitionType = PageTransitionType.slideFromRight,
  }) async {
    // Show network loading screen
    _showNetworkLoadingOverlay(context, loadingMessage);
    
    try {
      // Perform network operation
      await networkOperation;
      
      // Hide loading screen
      _hideLoadingOverlay(context);
      
      // Navigate to destination
      return _navigateWithTransition<T>(context, destination, transitionType);
    } catch (e) {
      // Hide loading screen
      _hideLoadingOverlay(context);
      
      // Show error and retry option
      _showNetworkErrorDialog(context, e.toString(), () {
        navigateWithNetworkLoading<T>(
          context,
          destination,
          loadingMessage: loadingMessage,
          networkOperation: networkOperation,
          transitionType: transitionType,
        );
      });
      
      return null;
    }
  }

  // Navigate with transition
  static Future<T?> navigateWithTransition<T>(
    BuildContext context,
    Widget destination, {
    PageTransitionType transitionType = PageTransitionType.slideFromRight,
  }) {
    return _navigateWithTransition<T>(context, destination, transitionType);
  }

  // Replace with transition
  static Future<T?> replaceWithTransition<T>(
    BuildContext context,
    Widget destination, {
    PageTransitionType transitionType = PageTransitionType.slideFromRight,
  }) {
    return _replaceWithTransition<T>(context, destination, transitionType);
  }

  // Push and clear stack with transition
  static Future<T?> pushAndClearStackWithTransition<T>(
    BuildContext context,
    Widget destination, {
    PageTransitionType transitionType = PageTransitionType.fadeIn,
  }) {
    return _pushAndClearStackWithTransition<T>(context, destination, transitionType);
  }

  // Private methods
  static Future<T?> _navigateWithTransition<T>(
    BuildContext context,
    Widget destination,
    PageTransitionType transitionType,
  ) {
    Route<T> route = _getRouteForTransition<T>(destination, transitionType);
    return Navigator.push<T>(context, route);
  }

  static Future<T?> _replaceWithTransition<T>(
    BuildContext context,
    Widget destination,
    PageTransitionType transitionType,
  ) {
    Route<T> route = _getRouteForTransition<T>(destination, transitionType);
    return Navigator.pushReplacement<T, dynamic>(context, route);
  }

  static Future<T?> _pushAndClearStackWithTransition<T>(
    BuildContext context,
    Widget destination,
    PageTransitionType transitionType,
  ) {
    Route<T> route = _getRouteForTransition<T>(destination, transitionType);
    return Navigator.pushAndRemoveUntil<T>(
      context,
      route,
      (Route<dynamic> route) => false,
    );
  }

  static Route<T> _getRouteForTransition<T>(Widget destination, PageTransitionType transitionType) {
    switch (transitionType) {
      case PageTransitionType.slideFromRight:
        return PageTransitions.slideFromRight<T>(destination);
      case PageTransitionType.slideFromLeft:
        return PageTransitions.slideFromLeft<T>(destination);
      case PageTransitionType.slideFromBottom:
        return PageTransitions.slideFromBottom<T>(destination);
      case PageTransitionType.fadeIn:
        return PageTransitions.fadeIn<T>(destination);
      case PageTransitionType.scaleIn:
        return PageTransitions.scaleIn<T>(destination);
      case PageTransitionType.slideAndFade:
        return PageTransitions.slideAndFade<T>(destination);
      default:
        return PageTransitions.slideFromRight<T>(destination);
    }
  }

  static void _showLoadingOverlay(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingScreen(message: message),
    );
  }

  static void _showNetworkLoadingOverlay(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NetworkLoadingScreen(
        message: message,
        onRetry: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  static void _hideLoadingOverlay(BuildContext context) {
    Navigator.of(context).pop();
  }

  static void _showNetworkErrorDialog(BuildContext context, String error, VoidCallback onRetry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Connection Error",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Failed to load content: $error",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              "Retry",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

enum PageTransitionType {
  slideFromRight,
  slideFromLeft,
  slideFromBottom,
  fadeIn,
  scaleIn,
  slideAndFade,
}
