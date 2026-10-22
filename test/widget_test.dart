
import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack/main.dart';

void main() {
  testWidgets('EduTrack application starts', (WidgetTester tester) async {
    await tester.pumpWidget(const EduTrackApp());

    expect(find.text('EduTrack'), findsWidgets);
  });
}
