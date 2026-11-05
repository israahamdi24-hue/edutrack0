import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/app_user.dart';
import '../models/student_dashboard_data.dart';
import '../models/student_course.dart';
import '../services/student_dashboard_service.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key, required this.user, this.repository});

  final AppUser user;
  final StudentDataRepository? repository;

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  late Future<List<StudentCourse>> _courses;
  String? _expandedCourseId;
  Future<_CourseDetailsData>? _details;

  StudentDataRepository get _service =>
      widget.repository ?? StudentDashboardService();

  @override
  void initState() {
    super.initState();
    _courses = _service.loadCourses(widget.user);
  }

  void _reload() {
    setState(() {
      _courses = _service.loadCourses(widget.user);
      _expandedCourseId = null;
      _details = null;
    });
  }

  void _toggleCourse(StudentCourse course) {
    setState(() {
      if (_expandedCourseId == course.id) {
        _expandedCourseId = null;
        _details = null;
      } else {
        _expandedCourseId = course.id;
        _details = _loadDetails(course);
      }
    });
  }

  Future<_CourseDetailsData> _loadDetails(StudentCourse course) async {
    final results = await Future.wait([
      _service.loadSessions({course.id}, [course]),
      _service.loadAttendance(widget.user),
    ]);
    return _CourseDetailsData(
      sessions: results[0] as List<StudentSession>,
      attendance: results[1] as List<StudentAttendanceRecord>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentCourse>>(
      future: _courses,
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

        final courses = snapshot.data!;
        if (courses.isEmpty) {
          return const _EmptyPanel(
            icon: Icons.menu_book_outlined,
            message: 'Aucun cours ne vous est attribué pour le moment.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Vos cours inscrits',
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
            const SizedBox(height: 8),
            const Text(
              'Les cours et inscriptions sont gérés par votre établissement.',
              style: TextStyle(color: AppColors.secondary),
            ),
            const SizedBox(height: 16),
            for (final course in courses)
              _CourseCard(
                course: course,
                expanded: _expandedCourseId == course.id,
                details: _expandedCourseId == course.id ? _details : null,
                onTap: () => _toggleCourse(course),
              ),
          ],
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.expanded,
    required this.details,
    required this.onTap,
  });

  final StudentCourse course;
  final bool expanded;
  final Future<_CourseDetailsData>? details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: const CircleAvatar(
                backgroundColor: AppColors.paleBlue,
                child: Icon(Icons.menu_book_outlined, color: AppColors.primary),
              ),
              title: Text(
                course.name,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  'Enseignant : ${course.teacherName}',
                  style: const TextStyle(color: AppColors.secondary),
                ),
              ),
              trailing: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.primary,
              ),
              onTap: onTap,
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (course.description.isNotEmpty) ...[
                      Text(
                        course.description,
                        style: const TextStyle(
                          color: AppColors.secondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    const Text(
                      'Séances du cours',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<_CourseDetailsData>(
                      future: details,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text(
                            _firestoreError(snapshot.error!),
                            style: const TextStyle(color: AppColors.error),
                          );
                        }
                        if (snapshot.data!.sessions.isEmpty) {
                          return const Text(
                            'Aucune séance programmée pour ce cours.',
                            style: TextStyle(color: AppColors.secondary),
                          );
                        }
                        return Column(
                          children: [
                            for (final session in snapshot.data!.sessions)
                              _SessionRow(
                                session: session,
                                attendance: snapshot.data!.attendance
                                    .where(
                                      (record) =>
                                          record.sessionId == session.id,
                                    )
                                    .firstOrNull,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.attendance});

  final StudentSession session;
  final StudentAttendanceRecord? attendance;

  @override
  Widget build(BuildContext context) {
    final startsAt = session.startsAt;
    final date =
        '${startsAt.day.toString().padLeft(2, '0')}/'
        '${startsAt.month.toString().padLeft(2, '0')}/'
        '${startsAt.year}';
    final time =
        '${startsAt.hour.toString().padLeft(2, '0')}:'
        '${startsAt.minute.toString().padLeft(2, '0')}';
    final isUpcoming = startsAt.isAfter(DateTime.now());

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isUpcoming ? Icons.upcoming_outlined : Icons.event_available_outlined,
        color: isUpcoming ? AppColors.primary : AppColors.secondary,
      ),
      title: Text(date),
      subtitle: Text(
        [time, if (session.room.isNotEmpty) session.room].join(' • '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isUpcoming ? 'À venir' : 'Terminée',
            style: TextStyle(
              color: isUpcoming ? AppColors.primary : AppColors.secondary,
              fontSize: 12,
            ),
          ),
          if (attendance != null)
            Text(
              switch (attendance!.status) {
                'present' => 'Présent',
                'late' => 'En retard',
                'absent' => 'Absent',
                _ => 'Inconnu',
              },
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseDetailsData {
  const _CourseDetailsData({required this.sessions, required this.attendance});

  final List<StudentSession> sessions;
  final List<StudentAttendanceRecord> attendance;
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ],
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
        Text(
          _firestoreError(error),
          style: const TextStyle(color: AppColors.error),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}

String _firestoreError(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Accès Firestore refusé. Vérifiez les règles du module Étudiant.';
  }
  if (error is FirebaseException) {
    return 'Erreur Firestore (${error.code}) : '
        '${error.message ?? 'lecture impossible.'}';
  }
  return error.toString();
}
