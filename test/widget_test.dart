import 'package:flutter_test/flutter_test.dart';
import 'package:untitled2/main.dart';

void main() {
  testWidgets('MyDocverterApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyDocverterApp());

    // Verify app title or home screen text is present.
    expect(find.text('My Docverter'), findsOneWidget);
  });
}
