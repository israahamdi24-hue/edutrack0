import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/app_user.dart';

class AdminCourse {
  const AdminCourse({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.teacherUid,
    this.description,
  });
  final String id;
  final String name;
  final String teacherName;
  final String teacherUid;
  final String? description;
}

class AdminEnrollment {
  const AdminEnrollment({
    required this.id,
    required this.studentUid,
    required this.courseId,
    required this.status,
  });
  final String id;
  final String studentUid;
  final String courseId;
  final String status;
}

class AdminSession {
  const AdminSession({
    required this.id,
    required this.courseId,
    required this.teacherUid,
    required this.startsAt,
    this.endsAt,
    this.room,
  });
  final String id;
  final String courseId;
  final String teacherUid;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? room;
}

class AdminAttendance {
  const AdminAttendance({
    required this.studentUid,
    required this.courseId,
    required this.sessionId,
    required this.status,
    required this.recordedAt,
  });
  final String studentUid;
  final String courseId;
  final String sessionId;
  final String status;
  final DateTime recordedAt;
}

class AdminWorkspaceData {
  const AdminWorkspaceData({
    required this.users,
    required this.courses,
    required this.enrollments,
    required this.sessions,
    required this.attendance,
  });
  final List<AppUser> users;
  final List<AdminCourse> courses;
  final List<AdminEnrollment> enrollments;
  final List<AdminSession> sessions;
  final List<AdminAttendance> attendance;
}

class AdminDataService {
  AdminDataService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<AdminWorkspaceData> load() async {
    final results = await Future.wait([
      _firestore.collection('users').orderBy('displayName').get(),
      _firestore.collection('courses').get(),
      _firestore.collection('enrollments').get(),
      _firestore.collection('sessions').get(),
      _firestore.collection('attendance').get(),
    ]);
    final users = <AppUser>[];
    for (final document in results[0].docs) {
      final data = document.data();
      if (data['uid'] != document.id ||
          data['email'] is! String ||
          data['displayName'] is! String) {
        throw FormatException('Profil utilisateur invalide : ${document.id}.');
      }
      users.add(
        AppUser(
          uid: document.id,
          email: data['email'] as String,
          displayName: data['displayName'] as String,
          role: AppRole.fromValue(data['role']),
          className: data['className'] as String?,
        ),
      );
    }
    final courses = <AdminCourse>[];
    for (final document in results[1].docs) {
      final data = document.data();
      if (data['name'] is! String ||
          data['teacherName'] is! String ||
          data['teacherUid'] is! String) {
        throw FormatException('Cours invalide : ${document.id}.');
      }
      courses.add(
        AdminCourse(
          id: document.id,
          name: data['name'] as String,
          teacherName: data['teacherName'] as String,
          teacherUid: data['teacherUid'] as String,
          description: data['description'] as String?,
        ),
      );
    }
    final enrollments = <AdminEnrollment>[];
    for (final document in results[2].docs) {
      final data = document.data();
      final studentUid = data['studentUid'];
      final courseId = data['courseId'];
      final status = data['status'];
      if (studentUid is! String ||
          courseId is! String ||
          status is! String ||
          document.id != '${studentUid}_$courseId') {
        throw FormatException('Inscription invalide : ${document.id}.');
      }
      enrollments.add(
        AdminEnrollment(
          id: document.id,
          studentUid: studentUid,
          courseId: courseId,
          status: status,
        ),
      );
    }
    final sessions = <AdminSession>[];
    for (final document in results[3].docs) {
      final data = document.data();
      final startsAt = data['startsAt'];
      if (data['courseId'] is! String ||
          data['teacherUid'] is! String ||
          startsAt is! Timestamp) {
        throw FormatException('Séance invalide : ${document.id}.');
      }
      final endsAt = data['endsAt'];
      if ((endsAt != null && endsAt is! Timestamp) ||
          (data['room'] != null && data['room'] is! String)) {
        throw FormatException(
          'Champs invalides dans la séance ${document.id}.',
        );
      }
      sessions.add(
        AdminSession(
          id: document.id,
          courseId: data['courseId'] as String,
          teacherUid: data['teacherUid'] as String,
          startsAt: startsAt.toDate(),
          endsAt: (endsAt as Timestamp?)?.toDate(),
          room: data['room'] as String?,
        ),
      );
    }
    final attendance = <AdminAttendance>[];
    for (final document in results[4].docs) {
      final data = document.data();
      final uid = data['studentUid'];
      final sessionId = data['sessionId'];
      final courseId = data['courseId'];
      final status = data['status'];
      final recordedAt = data['recordedAt'];
      if (uid is! String ||
          sessionId is! String ||
          courseId is! String ||
          status is! String ||
          !const {'present', 'late', 'absent'}.contains(status) ||
          recordedAt is! Timestamp ||
          document.id != '${uid}_$sessionId') {
        throw FormatException('Pointage invalide : ${document.id}.');
      }
      attendance.add(
        AdminAttendance(
          studentUid: uid,
          courseId: courseId,
          sessionId: sessionId,
          status: status,
          recordedAt: recordedAt.toDate(),
        ),
      );
    }
    return AdminWorkspaceData(
      users: users,
      courses: courses,
      enrollments: enrollments,
      sessions: sessions,
      attendance: attendance,
    );
  }

  Future<void> updateStudentClass(String uid, String? className) async {
    final value = className?.trim();
    await _firestore.collection('users').doc(uid).update({
      if (value == null || value.isEmpty)
        'className': FieldValue.delete()
      else
        'className': value,
    });
  }

  Future<void> createCourse({
    required String name,
    required AppUser teacher,
    String? description,
  }) async {
    final courseName = name.trim();
    if (courseName.isEmpty) {
      throw ArgumentError('Le nom du cours est obligatoire.');
    }
    await _firestore.collection('courses').add({
      'name': courseName,
      'teacherName': teacher.displayName,
      'teacherUid': teacher.uid,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
  }

  Future<void> updateCourse({
    required String courseId,
    required String name,
    required AppUser teacher,
    String? description,
  }) async {
    final courseName = name.trim();
    if (courseName.isEmpty) {
      throw ArgumentError('Le nom du cours est obligatoire.');
    }
    await _firestore.collection('courses').doc(courseId).update({
      'name': courseName,
      'teacherName': teacher.displayName,
      'teacherUid': teacher.uid,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim()
      else
        'description': FieldValue.delete(),
    });
  }

  Future<void> removeCourse(AdminCourse course) async {
    final results = await Future.wait([
      _firestore
          .collection('enrollments')
          .where('courseId', isEqualTo: course.id)
          .limit(1)
          .get(),
      _firestore
          .collection('sessions')
          .where('courseId', isEqualTo: course.id)
          .limit(1)
          .get(),
      _firestore
          .collection('attendance')
          .where('courseId', isEqualTo: course.id)
          .limit(1)
          .get(),
    ]);
    if (results.any((snapshot) => snapshot.docs.isNotEmpty)) {
      throw StateError(
        'Ce cours possède des inscriptions, des séances ou des pointages. '
        'Supprimez d’abord les inscriptions et les séances sans historique.',
      );
    }
    await _firestore.collection('courses').doc(course.id).delete();
  }

  Future<void> createEnrollments({
    required List<AppUser> students,
    required AdminCourse course,
  }) async {
    final uniqueStudents = {
      for (final student in students) student.uid: student,
    };
    if (uniqueStudents.isEmpty) {
      throw ArgumentError('Sélectionnez au moins un étudiant.');
    }
    final studentList = uniqueStudents.values.toList();
    const batchSize = 10;
    for (var start = 0; start < studentList.length; start += batchSize) {
      final batch = _firestore.batch();
      for (final student in studentList.skip(start).take(batchSize)) {
        batch.set(
          _firestore
              .collection('enrollments')
              .doc('${student.uid}_${course.id}'),
          {
            'studentUid': student.uid,
            'courseId': course.id,
            'status': 'active',
          },
        );
      }
      await batch.commit();
    }
  }

  Future<void> createEnrollment({
    required AppUser student,
    required AdminCourse course,
  }) async {
    await createEnrollments(students: [student], course: course);
  }

  Future<void> removeEnrollment(String id) =>
      _firestore.collection('enrollments').doc(id).delete();

  Future<void> createSession({
    required AdminCourse course,
    required DateTime startsAt,
    DateTime? endsAt,
    String? room,
  }) async {
    _validateSessionTimes(startsAt, endsAt);
    final data = <String, dynamic>{
      'courseId': course.id,
      'teacherUid': course.teacherUid,
      'startsAt': Timestamp.fromDate(startsAt),
    };
    if (endsAt != null) data['endsAt'] = Timestamp.fromDate(endsAt);
    if (room != null && room.trim().isNotEmpty) data['room'] = room.trim();
    await _firestore.collection('sessions').add(data);
  }

  Future<void> removeSession(AdminSession session) async {
    final attendance = await _firestore
        .collection('attendance')
        .where('courseId', isEqualTo: session.courseId)
        .get();
    if (attendance.docs.any(
      (document) => document.data()['sessionId'] == session.id,
    )) {
      throw StateError(
        'Cette séance possède des pointages et ne peut pas être supprimée.',
      );
    }
    await _firestore.collection('sessions').doc(session.id).delete();
  }

  Future<void> updateSession({
    required String sessionId,
    required AdminCourse course,
    required DateTime startsAt,
    DateTime? endsAt,
    String? room,
  }) async {
    _validateSessionTimes(startsAt, endsAt);
    final data = <String, dynamic>{
      'courseId': course.id,
      'teacherUid': course.teacherUid,
      'startsAt': Timestamp.fromDate(startsAt),
    };
    data['endsAt'] = endsAt == null
        ? FieldValue.delete()
        : Timestamp.fromDate(endsAt);
    data['room'] = room == null || room.trim().isEmpty
        ? FieldValue.delete()
        : room.trim();
    await _firestore.collection('sessions').doc(sessionId).update(data);
  }

  void _validateSessionTimes(DateTime startsAt, DateTime? endsAt) {
    if (endsAt != null && !endsAt.isAfter(startsAt)) {
      throw ArgumentError('L’heure de fin doit être postérieure au début.');
    }
  }
}
