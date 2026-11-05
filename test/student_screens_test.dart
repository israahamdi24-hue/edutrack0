import 'package:edutrack/features/student/models/student_course.dart';
import 'package:edutrack/features/student/models/student_dashboard_data.dart';
import 'package:edutrack/features/student/screens/student_courses_screen.dart';
import 'package:edutrack/features/student/screens/student_notifications_screen.dart';
import 'package:edutrack/features/student/screens/student_profile_screen.dart';
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
    className: 'DSI L3',
  );
  final repository = _FakeStudentDashboardService();

  testWidgets('lists enrolled courses and their sessions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentCoursesScreen(user: user, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Développement mobile'), findsOneWidget);
    expect(find.text('Enseignant : Mme Ben Salem'), findsOneWidget);
    await tester.tap(find.text('Développement mobile'));
    await tester.pumpAndSettle();
    expect(find.text('Séances du cours'), findsOneWidget);
    expect(find.textContaining('Salle B12'), findsOneWidget);
  });

  testWidgets('shows account fields and only allows editing the name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentProfileScreen(user: user, repository: repository),
        ),
      ),
    );

    expect(find.text('etudiant@example.com'), findsOneWidget);
    expect(find.text('DSI L3'), findsOneWidget);
    expect(find.text('Étudiant'), findsOneWidget);
    expect(
      find.text('L’adresse e-mail n’est pas modifiable ici.'),
      findsOneWidget,
    );
  });

  testWidgets('streams notifications and marks unread items as read', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentNotificationsScreen(user: user, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle séance'), findsOneWidget);
    await tester.tap(find.byTooltip('Marquer comme lu'));
    await tester.pumpAndSettle();
    expect(repository.lastMarkedNotification, 'notification-1');
  });
}

class _FakeStudentDashboardService implements StudentDataRepository {
  _FakeStudentDashboardService();

  final course = const StudentCourse(
    id: 'course-1',
    name: 'Développement mobile',
    teacherName: 'Mme Ben Salem',
    teacherUid: 'teacher-uid',
    description: 'Développement d’applications mobiles.',
  );

  String? lastMarkedNotification;

  @override
  Future<StudentDashboardData> load(AppUser user) async {
    return const StudentDashboardData(
      courseCount: 1,
      attendedCount: 0,
      lateCount: 0,
      absenceCount: 0,
      upcomingSessionCount: 0,
      upcomingSessions: [],
    );
  }

  @override
  Future<List<StudentCourse>> loadCourses(AppUser user) async => [course];

  @override
  Future<List<StudentSession>> loadSessions(
    Set<String> courseIds,
    List<StudentCourse> courses,
  ) async {
    return [
      StudentSession(
        id: 'session-1',
        courseName: course.name,
        teacherName: course.teacherName,
        startsAt: DateTime(2026, 11, 3, 10),
        endsAt: DateTime(2026, 11, 3, 12),
        room: 'Salle B12',
      ),
    ];
  }

  @override
  Future<List<StudentAttendanceRecord>> loadAttendance(AppUser user) async =>
      [];

  @override
  Stream<List<StudentNotification>> watchNotifications(String uid) {
    return Stream.value([
      StudentNotification(
        id: 'notification-1',
        title: 'Nouvelle séance',
        message: 'Une séance a été ajoutée à votre emploi du temps.',
        createdAt: DateTime(2026, 11, 2, 10),
        isRead: false,
      ),
    ]);
  }

  @override
  Future<void> markNotificationRead(String uid, String notificationId) async {
    lastMarkedNotification = notificationId;
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {}
}
