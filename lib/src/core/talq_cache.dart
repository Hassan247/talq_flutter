import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lightweight on-disk cache for non-sensitive SDK state so cold opens render
/// last-good content instantly instead of flashing empty cards.
///
/// We piggy-back on `flutter_secure_storage` (already a SDK dependency) so we
/// don't add a new transitive dependency on `shared_preferences`. The data
/// stored here is small (a few KB at most) and treating it as "secure" is a
/// harmless upgrade — workspace branding, FAQs and last-known room metadata
/// are not sensitive but encrypting them costs nothing.
class TalqCache {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _workspaceKey = 'talq_cache_workspace_v1';
  static const _agentAvatarsKey = 'talq_cache_agent_avatars_v1';
  static const _roomsKey = 'talq_cache_rooms_v1';
  static const _faqsKey = 'talq_cache_faqs_v1';
  static const _widgetConfigKey = 'talq_cache_widget_config_v1';

  static Future<void> _writeJson(String key, Object? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: key);
        return;
      }
      await _storage.write(key: key, value: jsonEncode(value));
    } catch (e) {
      debugPrint('[TalqCache] failed to write $key: $e');
    }
  }

  static Future<dynamic> _readJson(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('[TalqCache] failed to read $key: $e');
      return null;
    }
  }

  // Workspace ---------------------------------------------------------------
  static Future<void> saveWorkspace(
    Map<String, dynamic> workspaceJson, {
    List<String>? agentAvatars,
  }) async {
    await _writeJson(_workspaceKey, workspaceJson);
    if (agentAvatars != null) {
      await _writeJson(_agentAvatarsKey, agentAvatars);
    }
  }

  static Future<Map<String, dynamic>?> getWorkspace() async {
    final v = await _readJson(_workspaceKey);
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static Future<List<String>> getAgentAvatars() async {
    final v = await _readJson(_agentAvatarsKey);
    if (v is List) return v.whereType<String>().toList();
    return const [];
  }

  // Rooms -------------------------------------------------------------------
  static Future<void> saveRooms(List<Map<String, dynamic>> rooms) async {
    await _writeJson(_roomsKey, rooms);
  }

  static Future<List<Map<String, dynamic>>> getRooms() async {
    final v = await _readJson(_roomsKey);
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  // FAQs --------------------------------------------------------------------
  static Future<void> saveFaqs(List<Map<String, dynamic>> faqs) async {
    await _writeJson(_faqsKey, faqs);
  }

  static Future<List<Map<String, dynamic>>> getFaqs() async {
    final v = await _readJson(_faqsKey);
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  // Widget config -----------------------------------------------------------
  static Future<void> saveWidgetConfig(Map<String, dynamic> json) =>
      _writeJson(_widgetConfigKey, json);

  static Future<Map<String, dynamic>?> getWidgetConfig() async {
    final v = await _readJson(_widgetConfigKey);
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Wipes all cached SDK state — used when the visitor identity is reset.
  static Future<void> clear() async {
    for (final key in [
      _workspaceKey,
      _agentAvatarsKey,
      _roomsKey,
      _faqsKey,
      _widgetConfigKey,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
    }
  }
}
