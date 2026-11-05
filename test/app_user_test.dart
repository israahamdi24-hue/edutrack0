import 'package:edutrack/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRole', () {
    test('loads roles stored in Firestore', () {
      expect(AppRole.fromValue('student'), AppRole.student);
      expect(AppRole.fromValue('teacher'), AppRole.teacher);
      expect(AppRole.fromValue('admin'), AppRole.admin);
    });

    test('rejects unknown roles instead of granting a default role', () {
      expect(() => AppRole.fromValue('unknown'), throwsFormatException);
    });
  });
}
