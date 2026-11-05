import 'package:edutrack/features/student/models/student_dashboard_data.dart';
import 'package:edutrack/features/student/screens/student_dashboard_screen.dart';
import 'package:edutrack/features/student/services/student_dashboard_service.dart';
import 'package:edutrack/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AppUser(
    uid: 'student-uid',
    email: 'etudiant@example.com',
    displayName: 'Nadia Ben Ali',
    role: AppRole.student,
  );

  testWidgets('shows dashboard data loaded for the signed-in student', (
    tester,
  ) async {
    var navigatedTo = -1;
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentDashboardScreen(
              user: user,
              repository: _FakeDashboardRepository(_sampleData()),
              onNavigate: (index) => navigatedTo = index,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Nadia !'), findsOneWidget);
    expect(find.text('Cours suivis'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Absences enregistrées'), findsOneWidget);
    expect(find.text('Développement mobile'), findsOneWidget);

    await tester.ensureVisible(find.text('Mes présences'));
    await tester.tap(find.text('Mes présences'));
    expect(navigatedTo, 2);
  });

  testWidgets('shows a retryable error instead of demo data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentDashboardScreen(
            user: user,
            repository: _FakeDashboardRepository(
              StateError('Firestore indisponible'),
            ),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Firestore indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('92%'), findsNothing);
  });
}

StudentDashboardData _sampleData() {
  return StudentDashboardData(
    courseCount: 2,
    attendedCount: 2,
    lateCount: 1,
    absenceCount: 1,
    upcomingSessionCount: 1,
    upcomingSessions: [
      StudentSession(
        id: 'session-1',
        courseName: 'Développement mobile',
        teacherName: 'Mme Ben Salem',
        startsAt: DateTime(2026, 11, 3, 10),
        endsAt: DateTime(2026, 11, 3, 12),
        room: 'Salle B12',
      ),
    ],
  );
}

class _FakeDashboardRepository implements StudentDashboardRepository {
  _FakeDashboardRepository(this.result);

  final Object result;

  @override
  Future<StudentDashboardData> load(AppUser user) {
    if (result is StudentDashboardData) {
      return Future.value(result as StudentDashboardData);
    }
    return Future.error(result);
  }
}
