import 'package:flutter_test/flutter_test.dart';
import 'package:livechat_sdk_example/main.dart';

void main() {
  testWidgets('Shows configuration guidance when dart defines are missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LivechatExampleApp());

    expect(find.text('Livechat SDK Example'), findsOneWidget);
    expect(
      find.textContaining('Missing required --dart-define values.'),
      findsOneWidget,
    );
  });
}
