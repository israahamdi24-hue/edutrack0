import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/app_user.dart';
import '../models/student_course.dart';
import '../services/student_dashboard_service.dart';

class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({
    super.key,
    required this.user,
    this.repository,
  });

  final AppUser user;
  final StudentDataRepository? repository;

  @override
  State<StudentNotificationsScreen> createState() =>
      _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState
    extends State<StudentNotificationsScreen> {
  StudentDataRepository get _service =>
      widget.repository ?? StudentDashboardService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentNotification>>(
      stream: _service.watchNotifications(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessagePanel(
            icon: Icons.error_outline,
            message: snapshot.error is FirebaseException
                ? 'Impossible de charger les notifications. '
                      'Vérifiez les règles Firestore.'
                : snapshot.error.toString(),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final notifications = snapshot.data!;
        if (notifications.isEmpty) {
          return const _MessagePanel(
            icon: Icons.notifications_none_outlined,
            message: 'Vous n’avez aucune notification pour le moment.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vos notifications',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            for (final notification in notifications)
              _NotificationCard(
                notification: notification,
                onMarkRead: notification.isRead
                    ? null
                    : () => _markRead(notification.id),
              ),
          ],
        );
      },
    );
  }

  Future<void> _markRead(String id) async {
    try {
      await _service.markNotificationRead(widget.user.uid, id);
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de mettre à jour la notification '
              '(${error.code}).',
            ),
          ),
        );
      }
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
  });

  final StudentNotification notification;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final date = notification.createdAt;
    final dateLabel = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year} • ${date.hour.toString().padLeft(2, '0')}:'
              '${date.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : AppColors.paleBlue,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active_outlined,
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
                const SizedBox(height: 5),
                Text(
                  notification.message,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    height: 1.4,
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMarkRead != null)
            IconButton(
              tooltip: 'Marquer comme lu',
              onPressed: onMarkRead,
              icon: const Icon(Icons.done),
            ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.secondary),
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
