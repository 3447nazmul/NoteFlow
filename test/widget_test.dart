import 'package:flutter_test/flutter_test.dart';
import 'package:smart_notes_ai/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NoteFlowApp());
    // Verify app renders without crashing
    expect(find.text('NoteFlow'), findsOneWidget);
  });
}
