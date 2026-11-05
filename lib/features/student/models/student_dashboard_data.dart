class StudentDashboardData {
  const StudentDashboardData({
    required this.courseCount,
    required this.attendedCount,
    required this.lateCount,
    required this.absenceCount,
    required this.upcomingSessionCount,
    required this.upcomingSessions,
    this.sessionCount = 0,
  });

  final int courseCount;
  final int attendedCount;
  final int lateCount;
  final int absenceCount;
  final int upcomingSessionCount;
  final List<StudentSession> upcomingSessions;
  final int sessionCount;

  int get attendanceCount => attendedCount + lateCount + absenceCount;

  double? get attendanceRate => attendanceCount == 0
      ? null
      : (attendedCount + lateCount) / attendanceCount;
}

class StudentSession {
  const StudentSession({
    required this.id,
    required this.courseName,
    required this.teacherName,
    required this.startsAt,
    required this.endsAt,
    required this.room,
  });

  final String id;
  final String courseName;
  final String teacherName;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String room;
}
