// Wantr app widget tests
import 'package:flutter_test/flutter_test.dart';
import 'package:wantr/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WantrApp());

    // Verify that the app title appears
    expect(find.text('Wantr'), findsOneWidget);
  });
}
