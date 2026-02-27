import 'package:flutter_test/flutter_test.dart';
import 'package:talq_sdk_example/main.dart';

void main() {
  testWidgets('Shows configuration guidance when dart defines are missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TalqExampleApp());

    expect(find.text('Talq SDK Example'), findsOneWidget);
    expect(
      find.textContaining('Missing required --dart-define values.'),
      findsOneWidget,
    );
  });
}
