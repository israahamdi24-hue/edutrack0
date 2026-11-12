import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/app_user.dart';
import '../models/student_dashboard_data.dart';
import '../models/student_course.dart';
import '../services/student_dashboard_service.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({
    super.key,
    required this.user,
    this.repository,
  });

  final AppUser user;
  final StudentDataRepository? repository;

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  late Future<_AttendancePageData> _data;

  StudentDataRepository get _service =>
      widget.repository ?? StudentDashboardService();

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_AttendancePageData> _load() async {
    final results = await Future.wait([
      _service.loadCourses(widget.user),
      _service.loadAttendance(widget.user),
    ]);
    final courses = results[0] as List<StudentCourse>;
    final attendance = results[1] as List<StudentAttendanceRecord>;
    final sessions = await _service.loadSessions(
      courses.map((course) => course.id).toSet(),
      courses,
    );
    return _AttendancePageData(
      courses: courses,
      sessions: sessions,
      attendance: attendance,
    );
  }

  void _reload() {
    final data = _load();
    if (!mounted) return;
    setState(() {
      _data = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AttendancePageData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _ErrorPanel(error: snapshot.error!, onRetry: _reload);
        }

        final data = snapshot.data!;
        return DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Séances et présences',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualiser',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const TabBar(
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.secondary,
                tabs: [
                  Tab(text: 'Séances'),
                  Tab(text: 'Historique'),
                  Tab(text: 'Par cours'),
                ],
              ),
              SizedBox(
                height: 520,
                child: TabBarView(
                  children: [
                    _SessionsTab(data: data),
                    _HistoryTab(data: data),
                    _CourseStatsTab(data: data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttendancePageData {
  const _AttendancePageData({
    required this.courses,
    required this.sessions,
    required this.attendance,
  });

  final List<StudentCourse> courses;
  final List<StudentSession> sessions;
  final List<StudentAttendanceRecord> attendance;
}

class _SessionsTab extends StatelessWidget {
  const _SessionsTab({required this.data});

  final _AttendancePageData data;

  @override
  Widget build(BuildContext context) {
    if (data.sessions.isEmpty) {
      return const _EmptyState('Aucune séance n’est encore programmée.');
    }

    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        for (final session in data.sessions)
          _DataCard(
            icon: _sessionStateIcon(session, now).$1,
            title: session.courseName,
            subtitle: _sessionDescription(session),
            trailing: _sessionStateIcon(session, now).$2,
          ),
      ],
    );
  }
}

(IconData, String) _sessionStateIcon(StudentSession session, DateTime now) {
  if (session.startsAt.isAfter(now)) {
    return (Icons.upcoming_outlined, 'À venir');
  }
  if (session.endsAt?.isAfter(now) ?? false) {
    return (Icons.play_circle_outline, 'En cours');
  }
  return (Icons.event_available_outlined, 'Terminée');
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({required this.data});

  final _AttendancePageData data;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String _courseId = '*';
  String _status = '*';
  String _query = '';
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.attendance.isEmpty) {
      return const _EmptyState(
        'Aucune présence enregistrée dans votre historique.',
      );
    }

    final courses = {for (final course in data.courses) course.id: course.name};
    final sessions = {for (final session in data.sessions) session.id: session};
    final filtered = data.attendance.where((record) {
      final session = sessions[record.sessionId];
      final eventDate = session?.startsAt ?? record.recordedAt;
      final matchesDate =
          _date == null ||
          (eventDate != null && DateUtils.isSameDay(eventDate, _date));
      final courseName = courses[record.courseId] ?? '';
      final matchesQuery =
          _query.trim().isEmpty ||
          courseName.toLowerCase().contains(_query.trim().toLowerCase());
      return (_courseId == '*' || record.courseId == _courseId) &&
          (_status == '*' || record.status == _status) &&
          matchesDate &&
          matchesQuery;
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Rechercher un cours',
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: _courseId,
                decoration: const InputDecoration(
                  labelText: 'Cours',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: '*',
                    child: Text('Tous les cours'),
                  ),
                  for (final course in data.courses)
                    DropdownMenuItem(
                      value: course.id,
                      child: Text(course.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _courseId = value ?? '*'),
              ),
            ),
            SizedBox(
              width: 145,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: '*', child: Text('Tous les statuts')),
                  DropdownMenuItem(value: 'present', child: Text('Présent')),
                  DropdownMenuItem(value: 'late', child: Text('En retard')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent')),
                ],
                onChanged: (value) => setState(() => _status = value ?? '*'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (selected != null && mounted) {
                  setState(() => _date = DateUtils.dateOnly(selected));
                }
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                _date == null
                    ? 'Date'
                    : '${_date!.day.toString().padLeft(2, '0')}/'
                          '${_date!.month.toString().padLeft(2, '0')}/'
                          '${_date!.year}',
              ),
            ),
            if (_date != null)
              IconButton(
                tooltip: 'Effacer la date',
                onPressed: () => setState(() => _date = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aucun résultat pour ces filtres.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
        for (final record in filtered)
          _DataCard(
            icon: _statusIcon(record.status),
            title: courses[record.courseId] ?? 'Cours',
            subtitle: _historyDescription(record, sessions[record.sessionId]),
            trailing: _statusLabel(record.status),
          ),
      ],
    );
  }
}

class _CourseStatsTab extends StatelessWidget {
  const _CourseStatsTab({required this.data});

  final _AttendancePageData data;

  @override
  Widget build(BuildContext context) {
    if (data.courses.isEmpty) {
      return const _EmptyState('Aucun cours n’est associé à votre compte.');
    }

    final attended = data.attendance
        .where(
          (record) => record.status == 'present' || record.status == 'late',
        )
        .length;
    final late = data.attendance
        .where((record) => record.status == 'late')
        .length;
    final absent = data.attendance
        .where((record) => record.status == 'absent')
        .length;
    final rate = data.attendance.isEmpty
        ? null
        : attended / data.attendance.length;

    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistiques calculées sur les pointages enregistrés',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  Text('Séances programmées : ${data.sessions.length}'),
                  Text('Présences : $attended'),
                  Text('Retards : $late'),
                  Text('Absences confirmées : $absent'),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: rate ?? 0,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: AppColors.paleBlue,
                color: AppColors.success,
              ),
              const SizedBox(height: 6),
              Text(
                rate == null
                    ? 'Le taux sera calculé dès qu’un pointage sera enregistré.'
                    : '${(rate * 100).round()}% de présence sur '
                          '${data.attendance.length} pointage(s) enregistrés',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        for (final course in data.courses)
          Builder(
            builder: (context) {
              final records = data.attendance
                  .where((record) => record.courseId == course.id)
                  .toList();
              final attendanceCount = records
                  .where(
                    (record) =>
                        record.status == 'present' || record.status == 'late',
                  )
                  .length;
              final rate = records.isEmpty
                  ? null
                  : attendanceCount / records.length;
              final absences = records
                  .where((record) => record.status == 'absent')
                  .length;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: rate ?? 0,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: AppColors.paleBlue,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rate == null
                          ? 'Aucun pointage disponible pour ce cours.'
                          : '${(rate * 100).round()}% • '
                                '${records.length} séance(s) enregistrée(s) • '
                                '$absences absence(s)',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: const TextStyle(color: AppColors.secondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondary),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(error.toString(), style: const TextStyle(color: AppColors.error)),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}

String _sessionDescription(StudentSession session) {
  final date =
      '${session.startsAt.day.toString().padLeft(2, '0')}/'
      '${session.startsAt.month.toString().padLeft(2, '0')}/'
      '${session.startsAt.year}';
  final time =
      '${session.startsAt.hour.toString().padLeft(2, '0')}:'
      '${session.startsAt.minute.toString().padLeft(2, '0')}';
  return [
    date,
    time,
    if (session.teacherName.isNotEmpty) session.teacherName,
    if (session.room.isNotEmpty) session.room,
  ].join(' • ');
}

String _historyDescription(
  StudentAttendanceRecord record,
  StudentSession? session,
) {
  if (session == null) return 'Séance ${record.sessionId}';
  return _sessionDescription(session);
}

String _statusLabel(String status) => switch (status) {
  'present' => 'Présent',
  'late' => 'En retard',
  'absent' => 'Absent',
  _ => 'Inconnu',
};

IconData _statusIcon(String status) => switch (status) {
  'present' => Icons.check_circle_outline,
  'late' => Icons.schedule_outlined,
  'absent' => Icons.cancel_outlined,
  _ => Icons.help_outline,
};
