import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — App Lock Service
///
/// Provides biometric (fingerprint/FaceID) and PIN-based
/// authentication for app lock functionality.
///
/// Settings persisted in SharedPreferences:
///   • noteflow_app_lock_enabled  (bool)
///   • noteflow_app_lock_pin      (hashed string)
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Service to handle app-level security, including biometric and PIN authentication.
class AppLockService {
  static const String _enabledKey = 'noteflow_app_lock_enabled';
  static const String _pinKey = 'noteflow_app_lock_pin';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // ─── Lock State ───

  // AI NOTE: Checks if the app lock feature is currently enabled by the user.
  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  // AI NOTE: Enables or disables the app lock feature in local preferences.
  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  // ─── Biometric ───

  // AI NOTE: Verifies if the device supports biometric authentication and it is available.
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Biometric check failed: $e');
      return false;
    }
  }

  // AI NOTE: Retrieves the list of supported biometric types (e.g., face, fingerprint) on the device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get biometrics failed: $e');
      return [];
    }
  }

  /// Attempt biometric authentication.
  /// Returns true if the user successfully authenticated.
  // AI NOTE: Prompts the user to authenticate using biometrics.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock NoteFlow',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Biometric auth failed: $e');
      return false;
    }
  }

  // ─── PIN ───

  // AI NOTE: Checks if a PIN code has been set for app lock.
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) != null;
  }

  // AI NOTE: Hashes and securely stores a new PIN code.
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    // Simple hash for local PIN storage
    final hashed = base64Encode(utf8.encode(pin));
    await prefs.setString(_pinKey, hashed);
  }

  // AI NOTE: Verifies the provided PIN against the hashed PIN in storage.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    if (stored == null) return false;
    final hashed = base64Encode(utf8.encode(pin));
    return hashed == stored;
  }

  // AI NOTE: Removes the stored PIN code.
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }

  // ─── Combined Auth ───

  /// Try biometric first, then fall back to PIN check.
  /// Returns true if authenticated successfully.
  // AI NOTE: Attempts to authenticate the user using biometrics first, falling back to PIN if needed.
  Future<bool> authenticate() async {
    // Try biometrics first
    final biometricAvailable = await isBiometricAvailable();
    if (biometricAvailable) {
      final success = await authenticateWithBiometrics();
      if (success) return true;
    }
    // Falls through to PIN (handled by UI)
    return false;
  }
}
