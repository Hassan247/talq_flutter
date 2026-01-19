import 'package:flutter_test/flutter_test.dart';
import 'package:livechat_sdk/src/core/auth_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthManager Tests', () {
    test('Platform detection returns valid string', () {
      final platform = AuthManager.getPlatform();
      expect(['ANDROID', 'IOS', 'WEB'], contains(platform));
    });

    test('getDeviceId returns a valid UUID/ID', () async {
      // Note: We are using a real (but test-binded) storage here
      // In a real CI environment, you'd mock FlutterSecureStorage
      final deviceId = await AuthManager.getDeviceId();
      expect(deviceId, isNotNull);
      expect(deviceId.length, greaterThan(5));
    });
  });
}
