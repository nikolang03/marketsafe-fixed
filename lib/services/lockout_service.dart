class LockoutService {
  static DateTime? _lockoutTime;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  static void setLockout() {
    _lockoutTime = DateTime.now();
  }

  static bool isLockedOut() {
    if (_lockoutTime == null) return false;

    final now = DateTime.now();
    final timeSinceLockout = now.difference(_lockoutTime!);

    if (timeSinceLockout > _lockoutDuration) {
      // Reset lockout after 5 minutes
      _lockoutTime = null;
      return false;
    }

    return true;
  }

  static Duration? getRemainingTime() {
    if (_lockoutTime == null) return null;

    final now = DateTime.now();
    final timeSinceLockout = now.difference(_lockoutTime!);

    if (timeSinceLockout > _lockoutDuration) {
      _lockoutTime = null;
      return null;
    }

    return _lockoutDuration - timeSinceLockout;
  }

  static void clearLockout() {
    _lockoutTime = null;
  }
}





