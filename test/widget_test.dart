import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/main.dart';

void main() {
  testWidgets('home screen presents the play action', (tester) async {
    await tester.pumpWidget(const StrikerApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ONE TAP.\nALL GLORY.'), findsOneWidget);
    expect(find.text('LET’S PLAY  →'), findsOneWidget);
    await tester.tap(find.text('LET’S PLAY  →'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ONE TAP.\nALL GLORY.'), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);
  });
}
