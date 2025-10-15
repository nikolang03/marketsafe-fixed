import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/loading_screen.dart';

class NetworkService {
  static Timer? _connectionTimer;
  static bool _isConnected = true;
  static final List<VoidCallback> _connectionListeners = [];
  static final List<VoidCallback> _disconnectionListeners = [];

  // Check internet connectivity
  static Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Start monitoring network connectivity
  static void startMonitoring() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final isConnected = await checkConnectivity();
      if (isConnected != _isConnected) {
        _isConnected = isConnected;
        if (isConnected) {
          _notifyConnectionRestored();
        } else {
          _notifyConnectionLost();
        }
      }
    });
  }

  // Stop monitoring network connectivity
  static void stopMonitoring() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

  // Add connection listener
  static void addConnectionListener(VoidCallback listener) {
    _connectionListeners.add(listener);
  }

  // Remove connection listener
  static void removeConnectionListener(VoidCallback listener) {
    _connectionListeners.remove(listener);
  }

  // Add disconnection listener
  static void addDisconnectionListener(VoidCallback listener) {
    _disconnectionListeners.add(listener);
  }

  // Remove disconnection listener
  static void removeDisconnectionListener(VoidCallback listener) {
    _disconnectionListeners.remove(listener);
  }

  // Notify connection restored
  static void _notifyConnectionRestored() {
    for (var listener in _connectionListeners) {
      listener();
    }
  }

  // Notify connection lost
  static void _notifyConnectionLost() {
    for (var listener in _disconnectionListeners) {
      listener();
    }
  }

  // Execute with network retry
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    String? loadingMessage,
    BuildContext? context,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        // Check connectivity before attempting
        if (!await checkConnectivity()) {
          throw Exception('No internet connection');
        }
        
        // Show loading if context provided
        if (context != null && loadingMessage != null) {
          _showLoadingOverlay(context, loadingMessage);
        }
        
        // Execute operation
        final result = await operation();
        
        // Hide loading if shown
        if (context != null && loadingMessage != null) {
          _hideLoadingOverlay(context);
        }
        
        return result;
      } catch (e) {
        attempts++;
        
        // Hide loading if shown
        if (context != null && loadingMessage != null) {
          _hideLoadingOverlay(context);
        }
        
        if (attempts >= maxRetries) {
          rethrow;
        }
        
        // Wait before retry
        await Future.delayed(retryDelay);
      }
    }
    
    throw Exception('Max retries exceeded');
  }

  // Execute with network loading screen
  static Future<T> executeWithNetworkLoading<T>(
    BuildContext context,
    Future<T> Function() operation, {
    required String loadingMessage,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    return executeWithRetry(
      operation,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
      loadingMessage: loadingMessage,
      context: context,
    );
  }

  // Show network error dialog
  static void showNetworkErrorDialog(
    BuildContext context,
    String error, {
    VoidCallback? onRetry,
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              "Connection Error",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Unable to connect to the server:",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Please check your internet connection and try again.",
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (onCancel != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel();
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onRetry != null) onRetry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  "Retry",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show loading overlay
  static void _showLoadingOverlay(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingScreen(message: message),
    );
  }

  // Hide loading overlay
  static void _hideLoadingOverlay(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Get current connection status
  static bool get isConnected => _isConnected;

  // Dispose resources
  static void dispose() {
    stopMonitoring();
    _connectionListeners.clear();
    _disconnectionListeners.clear();
  }
}
