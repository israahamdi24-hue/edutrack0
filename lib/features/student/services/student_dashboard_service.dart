import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/app_user.dart';
import '../models/student_dashboard_data.dart';
import '../models/student_course.dart';

abstract interface class StudentDashboardRepository {
  Future<StudentDashboardData> load(AppUser user);
}

abstract interface class StudentDataRepository
    implements StudentDashboardRepository {
  Future<List<StudentCourse>> loadCourses(AppUser user);
  Future<List<StudentSession>> loadSessions(
    Set<String> courseIds,
    List<StudentCourse> courses,
  );
  Future<List<StudentAttendanceRecord>> loadAttendance(AppUser user);
  Stream<List<StudentNotification>> watchNotifications(String uid);
  Future<void> updateDisplayName(String uid, String displayName);
  Future<void> markNotificationRead(String uid, String notificationId);
}

class StudentDashboardService implements StudentDataRepository {
  StudentDashboardService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<StudentDashboardData> load(AppUser user) async {
    final courses = await loadCourses(user);
    final courseIds = courses.map((course) => course.id).toSet();
    final sessions = await loadSessions(courseIds, courses);
    final attendance = await loadAttendance(user);

    var attendedCount = 0;
    var lateCount = 0;
    var absenceCount = 0;
    for (final record in attendance) {
      switch (record.status) {
        case 'present':
          attendedCount++;
        case 'late':
          lateCount++;
        case 'absent':
          absenceCount++;
        default:
          throw FormatException(
            'Statut de présence invalide dans le document ${record.id}.',
          );
      }
    }

    final now = DateTime.now();
    final upcomingSessions =
        sessions.where((session) => session.startsAt.isAfter(now)).toList()
          ..sort((left, right) => left.startsAt.compareTo(right.startsAt));

    return StudentDashboardData(
      courseCount: courses.length,
      attendedCount: attendedCount,
      lateCount: lateCount,
      absenceCount: absenceCount,
      upcomingSessionCount: upcomingSessions.length,
      upcomingSessions: upcomingSessions.take(5).toList(),
      sessionCount: sessions.length,
    );
  }

  @override
  Future<List<StudentCourse>> loadCourses(AppUser user) async {
    final enrollments = await _firestore
        .collection('enrollments')
        .where('studentUid', isEqualTo: user.uid)
        .get();

    final courseIds = <String>{};
    for (final enrollment in enrollments.docs) {
      final data = enrollment.data();
      final status = data['status'];
      if (status != 'active') continue;

      final courseId = data['courseId'];
      if (courseId is! String || courseId.isEmpty) {
        throw FormatException(
          'Inscription ${enrollment.id} sans identifiant de cours valide.',
        );
      }
      if (enrollment.id != '${user.uid}_$courseId') {
        throw FormatException(
          'Identifiant d’inscription invalide : ${enrollment.id}.',
        );
      }
      courseIds.add(courseId);
    }

    final courses = <StudentCourse>[];
    for (final courseId in courseIds) {
      final snapshot = await _firestore
          .collection('courses')
          .doc(courseId)
          .get();
      if (!snapshot.exists) {
        throw FormatException('Le cours $courseId associé est introuvable.');
      }
      courses.add(StudentCourse.fromMap(snapshot.id, snapshot.data()!));
    }
    courses.sort((left, right) => left.name.compareTo(right.name));
    return courses;
  }

  @override
  Future<List<StudentSession>> loadSessions(
    Set<String> courseIds,
    List<StudentCourse> courses,
  ) async {
    final sessions = <StudentSession>[];
    final courseIdList = courseIds.toList();
    for (var start = 0; start < courseIdList.length; start += 30) {
      final courseIdChunk = courseIdList.skip(start).take(30).toList();
      final snapshots = await _firestore
          .collection('sessions')
          .where('courseId', whereIn: courseIdChunk)
          .get();

      for (final snapshot in snapshots.docs) {
        final data = snapshot.data();
        final courseId = data['courseId'];
        final teacherUid = data['teacherUid'];
        final room = data['room'];
        StudentCourse? course;
        for (final item in courses) {
          if (item.id == courseId) {
            course = item;
            break;
          }
        }
        if (courseId is! String || course == null || teacherUid is! String) {
          throw FormatException(
            'La séance ${snapshot.id} contient un cours ou un enseignant invalide.',
          );
        }

        final startsAt = data['startsAt'];
        if (startsAt is! Timestamp) {
          throw FormatException(
            'La séance ${snapshot.id} ne contient pas de date startsAt valide.',
          );
        }

        final endsAt = data['endsAt'];
        if ((endsAt != null && endsAt is! Timestamp) ||
            (room != null && room is! String)) {
          throw FormatException(
            'La séance ${snapshot.id} contient une heure de fin ou une salle invalide.',
          );
        }

        sessions.add(
          StudentSession(
            id: snapshot.id,
            courseName: course.name,
            teacherName: course.teacherName,
            startsAt: startsAt.toDate(),
            endsAt: (endsAt as Timestamp?)?.toDate(),
            room: room as String? ?? '',
          ),
        );
      }
    }
    sessions.sort((left, right) => left.startsAt.compareTo(right.startsAt));
    return sessions;
  }

  @override
  Future<List<StudentAttendanceRecord>> loadAttendance(AppUser user) async {
    final attendance = await _firestore
        .collection('attendance')
        .where('studentUid', isEqualTo: user.uid)
        .get();

    final records = <StudentAttendanceRecord>[];
    for (final record in attendance.docs) {
      final data = record.data();
      final sessionId = data['sessionId'];
      final courseId = data['courseId'];
      final status = data['status'];
      final recordedAt = data['recordedAt'];
      if (sessionId is! String ||
          record.id != '${user.uid}_$sessionId' ||
          courseId is! String ||
          status is! String ||
          !const {'present', 'late', 'absent'}.contains(status) ||
          recordedAt is! Timestamp) {
        throw FormatException(
          'Données invalides dans la présence ${record.id}.',
        );
      }
      records.add(
        StudentAttendanceRecord(
          id: record.id,
          sessionId: sessionId,
          courseId: courseId,
          status: status,
          recordedAt: recordedAt.toDate(),
        ),
      );
    }
    records.sort((left, right) {
      return (right.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(left.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
    return records;
  }

  @override
  Stream<List<StudentNotification>> watchNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((document) {
            final data = document.data();
            final title = data['title'];
            final message = data['message'];
            final createdAt = data['createdAt'];
            final isRead = data['isRead'];
            if (title is! String ||
                message is! String ||
                createdAt is! Timestamp ||
                (isRead != null && isRead is! bool)) {
              throw FormatException('Notification ${document.id} invalide.');
            }
            return StudentNotification(
              id: document.id,
              title: title,
              message: message,
              createdAt: createdAt.toDate(),
              isRead: isRead as bool? ?? false,
            );
          }).toList();
        });
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'cannot be empty');
    }
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.uid != uid) {
      throw StateError('La session ne correspond pas au profil demandé.');
    }
    final previousName = firebaseUser.displayName;
    await firebaseUser.updateDisplayName(trimmedName);
    try {
      await _firestore.collection('users').doc(uid).update({
        'displayName': trimmedName,
      });
    } catch (_) {
      try {
        await firebaseUser.updateDisplayName(previousName);
      } catch (_) {
        // Keep the original Firestore error; the user can refresh the profile.
      }
      rethrow;
    }
  }

  @override
  Future<void> markNotificationRead(String uid, String notificationId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}
