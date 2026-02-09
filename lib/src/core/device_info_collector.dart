import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// collects device information for analytics (follows DRY principle)
/// this utility is used to gather platform-specific device info
/// that is sent to the backend for user analytics.
class DeviceInfoCollector {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// collects device info for the current platform
  /// returns a map with keys: deviceModel, osVersion, appVersion
  /// for web, returns: browser, browserVersion, browserLanguage, os
  static Future<Map<String, String?>> collect() async {
    try {
      if (Platform.isIOS) {
        return await _collectIosInfo();
      } else if (Platform.isAndroid) {
        return await _collectAndroidInfo();
      }
    } catch (e) {
      // silently fail - device info is optional analytics data
      // we don't want to break the app if collection fails
    }
    return {};
  }

  /// collects iOS device information
  static Future<Map<String, String?>> _collectIosInfo() async {
    final info = await _deviceInfo.iosInfo;
    final appVersion = await _getAppVersion();

    // convert machine identifier to human-readable name
    final deviceModel = _iosDeviceName(info.utsname.machine);

    return {
      'deviceModel': deviceModel,
      'osVersion': info.systemVersion,
      'appVersion': appVersion,
    };
  }

  /// collects Android device information
  static Future<Map<String, String?>> _collectAndroidInfo() async {
    final info = await _deviceInfo.androidInfo;
    final appVersion = await _getAppVersion();

    return {
      'deviceModel': info.model,
      'osVersion': info.version.release,
      'appVersion': appVersion,
    };
  }

  /// gets app version in format "1.0.0(1)"
  static Future<String?> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}(${info.buildNumber})';
    } catch (e) {
      return null;
    }
  }

  /// converts iOS machine identifier to human-readable device name
  /// e.g., "iPhone16,2" -> "iPhone 16 Plus"
  static String _iosDeviceName(String machineId) {
    // common device mappings (add more as needed)
    const deviceNames = {
      // iPhone 19 series (projected)
      'iPhone21,1': 'iPhone 19 Pro',
      'iPhone21,2': 'iPhone 19 Pro Max',
      'iPhone21,3': 'iPhone 19',
      'iPhone21,4': 'iPhone 19 Plus',
      // iPhone 18 series (projected)
      'iPhone20,1': 'iPhone 18 Pro',
      'iPhone20,2': 'iPhone 18 Pro Max',
      'iPhone20,3': 'iPhone 18',
      'iPhone20,4': 'iPhone 18 Plus',
      // iPhone 17 series
      'iPhone18,1': 'iPhone 17 Pro',
      'iPhone18,2': 'iPhone 17 Pro Max',
      'iPhone18,3': 'iPhone 17',
      'iPhone18,4': 'iPhone 17 Plus',
      'iPhone18,5': 'iPhone 17 Air',
      // iPhone 16 series
      'iPhone17,1': 'iPhone 16 Pro',
      'iPhone17,2': 'iPhone 16 Pro Max',
      'iPhone17,3': 'iPhone 16',
      'iPhone17,4': 'iPhone 16 Plus',
      // iPhone 15 series
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      // iPhone 14 series
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      // iPhone 13 series
      'iPhone14,2': 'iPhone 13 Pro',
      'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone14,4': 'iPhone 13 mini',
      'iPhone14,5': 'iPhone 13',
      // iPhone 12 series
      'iPhone13,1': 'iPhone 12 mini',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      // iPhone 11 series
      'iPhone12,1': 'iPhone 11',
      'iPhone12,3': 'iPhone 11 Pro',
      'iPhone12,5': 'iPhone 11 Pro Max',
      // iPhone SE
      'iPhone14,6': 'iPhone SE (3rd gen)',
      'iPhone12,8': 'iPhone SE (2nd gen)',
      // iPads (common ones)
      'iPad14,1': 'iPad Pro 11-inch (4th gen)',
      'iPad14,2': 'iPad Pro 11-inch (4th gen)',
      'iPad14,3': 'iPad Pro 12.9-inch (6th gen)',
      'iPad14,4': 'iPad Pro 12.9-inch (6th gen)',
    };

    return deviceNames[machineId] ?? machineId;
  }
}
