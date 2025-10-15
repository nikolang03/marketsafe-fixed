import 'package:flutter/material.dart';

class BadgeUpdateService {
  static final List<VoidCallback> _listeners = [];

  /// Add a listener to be notified when badge count should be updated
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners that badge count should be updated
  static void notifyBadgeUpdate() {
    print('🔔 Notifying badge update to ${_listeners.length} listeners');
    for (var listener in _listeners) {
      try {
        listener();
      } catch (e) {
        print('❌ Error notifying badge update: $e');
      }
    }
  }
}
