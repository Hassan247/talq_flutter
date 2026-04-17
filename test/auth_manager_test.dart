import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talq_flutter/src/core/auth_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final storage = <String, String>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final args = (call.arguments ?? <String, dynamic>{}) as Map;
          final key = args['key'] as String?;

          switch (call.method) {
            case 'read':
              return key == null ? null : storage[key];
            case 'write':
              final value = args['value'] as String?;
              if (key != null && value != null) {
                storage[key] = value;
              }
              return null;
            case 'delete':
              if (key != null) {
                storage.remove(key);
              }
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    storage.clear();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  group('AuthManager Tests', () {
    test('Platform detection returns valid string', () {
      final platform = AuthManager.getPlatform();
      expect(['ANDROID', 'IOS', 'WEB'], contains(platform));
    });

    test('getDeviceId returns a valid UUID/ID', () async {
      final deviceId = await AuthManager.getDeviceId();
      expect(deviceId, isNotNull);
      expect(deviceId.length, greaterThan(5));
    });
  });
}
