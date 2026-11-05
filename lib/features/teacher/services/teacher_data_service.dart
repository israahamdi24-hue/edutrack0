import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TeacherCourse {
  const TeacherCourse({
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

class TeacherSession {
  const TeacherSession({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.startsAt,
    this.endsAt,
    this.room,
  });

  final String id;
  final String courseId;
  final String courseName;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? room;
}

class TeacherAttendance {
  const TeacherAttendance({
    required this.id,
    required this.studentUid,
    required this.courseId,
    required this.sessionId,
    required this.status,
    required this.recordedAt,
  });

  final String id;
  final String studentUid;
  final String courseId;
  final String sessionId;
  final String status;
  final DateTime recordedAt;
}

class EnrolledStudent {
  const EnrolledStudent({
    required this.uid,
    required this.displayName,
    this.className,
  });

  final String uid;
  final String displayName;
  final String? className;
}

class TeacherDataService {
  TeacherDataService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<List<TeacherCourse>> loadCourses(String teacherUid) async {
    final snapshot = await _firestore
        .collection('courses')
        .where('teacherUid', isEqualTo: teacherUid)
        .get();
    final result = <TeacherCourse>[];
    for (final document in snapshot.docs) {
      final data = document.data();
      if (data['name'] is! String ||
          data['teacherName'] is! String ||
          data['teacherUid'] != teacherUid) {
        throw FormatException('Le cours ${document.id} est incomplet.');
      }
      result.add(
        TeacherCourse(
          id: document.id,
          name: data['name'] as String,
          teacherName: data['teacherName'] as String,
          teacherUid: teacherUid,
          description: data['description'] as String?,
        ),
      );
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<List<TeacherSession>> loadSessions(String teacherUid) async {
    final snapshot = await _firestore
        .collection('sessions')
        .where('teacherUid', isEqualTo: teacherUid)
        .get();
    final courseSnapshots = await loadCourses(teacherUid);
    final courses = {for (final course in courseSnapshots) course.id: course};
    final result = <TeacherSession>[];
    for (final document in snapshot.docs) {
      final data = document.data();
      final courseId = data['courseId'];
      final startsAt = data['startsAt'];
      if (courseId is! String ||
          startsAt is! Timestamp ||
          courses[courseId] == null) {
        throw FormatException('La séance ${document.id} est incomplète.');
      }
      final endsAt = data['endsAt'];
      final room = data['room'];
      if ((endsAt != null && endsAt is! Timestamp) ||
          (room != null && room is! String)) {
        throw FormatException('La séance ${document.id} contient des champs invalides.');
      }
      result.add(
        TeacherSession(
          id: document.id,
          courseId: courseId,
          courseName: courses[courseId]!.name,
          startsAt: startsAt.toDate(),
          endsAt: (endsAt as Timestamp?)?.toDate(),
          room: room as String?,
        ),
      );
    }
    result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return result;
  }

  Future<List<TeacherAttendance>> loadAttendance(
    List<TeacherCourse> courses,
  ) async {
    final records = <TeacherAttendance>[];
    final ids = courses.map((course) => course.id).toList();
    for (var start = 0; start < ids.length; start += 30) {
      final courseIds = ids.skip(start).take(30).toList();
      final snapshot = await _firestore
          .collection('attendance')
          .where('courseId', whereIn: courseIds)
          .get();
      for (final document in snapshot.docs) {
        final data = document.data();
        final studentUid = data['studentUid'];
        final sessionId = data['sessionId'];
        final courseId = data['courseId'];
        final status = data['status'];
        final recordedAt = data['recordedAt'];
        if (studentUid is! String ||
            sessionId is! String ||
            courseId is! String ||
            !ids.contains(courseId) ||
            document.id != '${studentUid}_$sessionId' ||
            status is! String ||
            !const {'present', 'late', 'absent'}.contains(status) ||
            recordedAt is! Timestamp) {
          throw FormatException('Le pointage ${document.id} est invalide.');
        }
        records.add(
          TeacherAttendance(
            id: document.id,
            studentUid: studentUid,
            courseId: courseId,
            sessionId: sessionId,
            status: status,
            recordedAt: recordedAt.toDate(),
          ),
        );
      }
    }
    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return records;
  }

  Future<List<EnrolledStudent>> loadEnrolledStudents(String courseId) async {
    final result = await _functions
        .httpsCallable('getEnrolledStudents')
        .call<Map<String, dynamic>>({'courseId': courseId});
    final rawStudents = result.data['students'];
    if (rawStudents is! List) {
      throw const FormatException('La réponse étudiant est invalide.');
    }
    return rawStudents.map((raw) {
      if (raw is! Map || raw['uid'] is! String || raw['displayName'] is! String) {
        throw const FormatException('Le profil étudiant retourné est invalide.');
      }
      return EnrolledStudent(
        uid: raw['uid'] as String,
        displayName: raw['displayName'] as String,
        className: raw['className'] as String?,
      );
    }).toList();
  }

  Future<void> createSession({
    required String courseId,
    required String teacherUid,
    required DateTime startsAt,
    DateTime? endsAt,
    String? room,
  }) async {
    final data = <String, dynamic>{
      'courseId': courseId,
      'teacherUid': teacherUid,
      'startsAt': Timestamp.fromDate(startsAt),
    };
    if (endsAt != null) data['endsAt'] = Timestamp.fromDate(endsAt);
    if (room != null && room.trim().isNotEmpty) data['room'] = room.trim();
    await _firestore.collection('sessions').add(data);
  }

  Future<void> updateSession({
    required TeacherSession session,
    required String teacherUid,
    required DateTime startsAt,
    DateTime? endsAt,
    String? room,
  }) async {
    await _firestore.collection('sessions').doc(session.id).update({
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': endsAt == null ? FieldValue.delete() : Timestamp.fromDate(endsAt),
      'room': room == null || room.trim().isEmpty ? FieldValue.delete() : room.trim(),
      'teacherUid': teacherUid,
      'courseId': session.courseId,
    });
  }

  Future<void> removeSession(TeacherSession session) async {
    final attendance = await _firestore
        .collection('attendance')
        .where('courseId', isEqualTo: session.courseId)
        .get();
    if (attendance.docs.any((document) => document.data()['sessionId'] == session.id)) {
      throw StateError('Cette séance possède des pointages et ne peut pas être supprimée.');
    }
    await _firestore.collection('sessions').doc(session.id).delete();
  }
}
