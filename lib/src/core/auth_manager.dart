import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class AuthManager {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'livechat_visitor_token';
  static const _deviceIdKey = 'livechat_device_id';

  /// Returns the current visitor token or null if not authenticated
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Saves the visitor token securely
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Clears the current session and token
  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Completely resets the visitor identity (clears token and device ID)
  static Future<void> resetSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _deviceIdKey);
  }

  /// Gets or generates a unique device ID
  static Future<String> getDeviceId() async {
    String? deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId != null) return deviceId;

    deviceId = await _calculateDeviceId();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  static Future<String> _calculateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Marshmallow and above
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? const Uuid().v4();
      }
    } catch (e) {
      // Fallback to random UUID if hardware ID fails
      return const Uuid().v4();
    }
    return const Uuid().v4();
  }

  /// Returns the platform string for the backend
  static String getPlatform() {
    if (Platform.isIOS) return 'IOS';
    if (Platform.isAndroid) return 'ANDROID';
    return 'WEB';
  }
}
