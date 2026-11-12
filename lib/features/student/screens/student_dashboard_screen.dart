import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/app_user.dart';
import '../models/student_dashboard_data.dart';
import '../models/student_course.dart';
import 'student_qr_attendance_screen.dart';
import '../services/student_dashboard_service.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({
    super.key,
    required this.user,
    required this.onNavigate,
    this.repository,
  });

  final AppUser user;
  final ValueChanged<int> onNavigate;
  final StudentDashboardRepository? repository;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late Future<StudentDashboardData> _dashboard;

  StudentDashboardRepository get _repository =>
      widget.repository ?? StudentDashboardService();

  @override
  void initState() {
    super.initState();
    _dashboard = _repository.load(widget.user);
  }

  void _reload() {
    final dashboard = _repository.load(widget.user);
    setState(() {
      _dashboard = dashboard;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeCard(),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Votre activité',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 20,
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
        const SizedBox(height: 12),
        FutureBuilder<StudentDashboardData>(
          future: _dashboard,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _DashboardError(
                message: _errorMessage(snapshot.error!),
                onRetry: _reload,
              );
            }

            final data = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStats(data),
                const SizedBox(height: 28),
                _buildUpcomingSessions(data),
                const SizedBox(height: 28),
                _buildRecentNotifications(),
                const SizedBox(height: 28),
                _buildQuickActions(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    final firstName = widget.user.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF6555D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour $firstName !',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Voici un aperçu de vos cours et de vos présences.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
                if (widget.user.className?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Classe : ${widget.user.className}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.school_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 42,
          ),
        ],
      ),
    );
  }

  Widget _buildStats(StudentDashboardData data) {
    final stats = [
      _DashboardStat(
        label: 'Cours suivis',
        value: '${data.courseCount}',
        icon: Icons.menu_book_outlined,
        color: AppColors.primary,
      ),
      _DashboardStat(
        label: 'Séances programmées',
        value: '${data.sessionCount}',
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF8055D9),
      ),
      _DashboardStat(
        label: 'Taux de présence',
        value: data.attendanceRate == null
            ? '—'
            : '${(data.attendanceRate! * 100).round()}%',
        icon: Icons.fact_check_outlined,
        color: AppColors.success,
      ),
      _DashboardStat(
        label: 'Présences (avec retards)',
        value: '${data.attendedCount + data.lateCount}',
        icon: Icons.event_available_outlined,
        color: AppColors.primary,
      ),
      _DashboardStat(
        label: 'Absences enregistrées',
        value: '${data.absenceCount}',
        icon: Icons.event_busy_outlined,
        color: AppColors.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 5
            : constraints.maxWidth >= 360
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: _StatCard(stat: stat),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRecentNotifications() {
    final repository = _repository;
    if (repository is! StudentDataRepository) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<StudentNotification>>(
      stream: repository.watchNotifications(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _DashboardError(
            message: 'Impossible de charger les notifications récentes.',
            onRetry: _reload,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final notifications = snapshot.data!.take(3);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notifications récentes',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate(3),
                  child: const Text('Tout voir'),
                ),
              ],
            ),
            for (final notification in notifications)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? Colors.white
                      : AppColors.paleBlue,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: notification.isRead
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            notification.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingSessions(StudentDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prochaines séances',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (data.upcomingSessions.isEmpty)
          const _EmptyState(
            icon: Icons.event_available_outlined,
            message: 'Aucune séance à venir pour le moment.',
          )
        else
          for (final session in data.upcomingSessions)
            _SessionCard(session: session),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accès rapide',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickAction(
              icon: Icons.menu_book_outlined,
              label: 'Mes cours',
              onTap: () => widget.onNavigate(1),
            ),
            _QuickAction(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scanner une présence',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StudentQrAttendanceScreen(),
                  ),
                );
              },
            ),
            _QuickAction(
              icon: Icons.fact_check_outlined,
              label: 'Mes présences',
              onTap: () => widget.onNavigate(2),
            ),
          ],
        ),
      ],
    );
  }

  String _errorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'L’accès aux données du tableau de bord est refusé. '
            'Les règles Firestore des collections courses, enrollments, '
            'sessions et attendance doivent être configurées.';
      }
      return 'Erreur Firestore (${error.code}) : '
          '${error.message ?? 'lecture impossible.'}';
    }
    return error.toString();
  }
}

class _DashboardStat {
  const _DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _DashboardStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(stat.icon, color: stat.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stat.value,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stat.label,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final StudentSession session;

  @override
  Widget build(BuildContext context) {
    final start = session.startsAt;
    final date =
        '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}/'
        '${start.year}';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}';
    final end = session.endsAt;
    final timeRange = end == null
        ? time
        : '$time – ${end.hour.toString().padLeft(2, '0')}:'
              '${end.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.paleBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.event_note_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.courseName,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$date • $timeRange',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
                if (session.teacherName.isNotEmpty ||
                    session.room.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (session.teacherName.isNotEmpty) session.teacherName,
                      if (session.room.isNotEmpty) session.room,
                    ].join(' • '),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary, size: 34),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: AppColors.primaryDark)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
