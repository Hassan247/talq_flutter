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
  static const _tokenKey = 'livechat_visitor_token';
  static const _deviceIdKey = 'livechat_device_id_v2';

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
}
