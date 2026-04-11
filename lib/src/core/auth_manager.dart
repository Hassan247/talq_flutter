import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class AuthManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const _tokenKey = 'talq_visitor_token';
  static const _deviceIdKey = 'talq_device_id_v2';
  static const _primaryColorKey = 'talq_primary_color';

  /// Returns the current visitor token or null if not authenticated
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Saves the visitor token securely
  static Future<void> saveToken(String token) async {
    if (token.trim().isEmpty) return;
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Clears the current session and token
  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Completely resets the visitor identity (clears token and generates new device ID)
  static Future<void> resetSession() async {
    await _storage.delete(key: _tokenKey);
    final newDeviceId = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: newDeviceId);
  }

  /// Gets or generates a unique device ID
  static Future<String> getDeviceId() async {
    String? deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId != null && deviceId.isNotEmpty) {
      return deviceId;
    }

    deviceId = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  /// Returns the platform string for the backend
  static String getPlatform() {
    if (kIsWeb) return 'WEB';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'IOS';
    if (defaultTargetPlatform == TargetPlatform.android) return 'ANDROID';
    return 'WEB';
  }

  /// Caches the workspace primary color hex for instant theme loading
  static Future<void> savePrimaryColor(String hex) async {
    await _storage.write(key: _primaryColorKey, value: hex);
  }

  /// Returns the cached primary color hex or null
  static Future<String?> getPrimaryColor() async {
    return await _storage.read(key: _primaryColorKey);
  }
}
