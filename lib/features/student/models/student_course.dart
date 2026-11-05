class StudentCourse {
  const StudentCourse({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.teacherUid,
    this.description = '',
  });

  final String id;
  final String name;
  final String teacherName;
  final String teacherUid;
  final String description;

  factory StudentCourse.fromMap(String id, Map<String, dynamic> data) {
    final name = data['name'];
    final teacherName = data['teacherName'];
    final teacherUid = data['teacherUid'];
    final description = data['description'];
    if (name is! String ||
        teacherName is! String ||
        teacherUid is! String ||
        (description != null && description is! String)) {
      throw FormatException(
        'Le cours $id doit contenir name, teacherName et teacherUid.',
      );
    }
    return StudentCourse(
      id: id,
      name: name,
      teacherName: teacherName,
      teacherUid: teacherUid,
      description: description as String? ?? '',
    );
  }
}

class StudentAttendanceRecord {
  const StudentAttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.courseId,
    required this.status,
    required this.recordedAt,
  });

  final String id;
  final String sessionId;
  final String courseId;
  final String status;
  final DateTime? recordedAt;
}

class StudentNotification {
  const StudentNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool isRead;
}
