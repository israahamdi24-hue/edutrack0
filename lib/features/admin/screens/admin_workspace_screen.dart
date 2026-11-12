import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/app_user.dart';
import '../../teacher/services/teacher_session_qr_service.dart';
import '../services/admin_data_service.dart';

class AdminWorkspaceScreen extends StatefulWidget {
  const AdminWorkspaceScreen({
    super.key,
    required this.sectionIndex,
    this.service,
    this.qrService,
  });
  final int sectionIndex;
  final AdminDataService? service;
  final TeacherSessionQrService? qrService;

  @override
  State<AdminWorkspaceScreen> createState() => _AdminWorkspaceScreenState();
}

class _AdminWorkspaceScreenState extends State<AdminWorkspaceScreen> {
  late Future<AdminWorkspaceData> _data;
  bool _working = false;
  AdminDataService get _service => widget.service ?? AdminDataService();
  TeacherSessionQrService get _qrService =>
      widget.qrService ?? TeacherSessionQrService();

  @override
  void initState() {
    super.initState();
    _data = _service.load();
  }

  void _reload() {
    final data = _service.load();
    if (!mounted) return;
    setState(() {
      _data = data;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminWorkspaceData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (snapshot.hasError) {
        return _AdminError(error: snapshot.error!, retry: _reload);
      }
      final data = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(_title, style: _titleStyle)),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          switch (widget.sectionIndex) {
            0 => _dashboard(data),
            1 => _users(data),
            2 => _management(data),
            3 => _statistics(data),
            _ => const SizedBox.shrink(),
          },
        ],
      );
    },
  );

  String get _title => switch (widget.sectionIndex) {
    0 => 'Tableau de bord administrateur',
    1 => 'Étudiants et enseignants',
    2 => 'Cours, inscriptions et séances',
    3 => 'Statistiques des présences',
    _ => 'Administration EduTrack',
  };

  Widget _dashboard(AdminWorkspaceData data) {
    final students = data.users
        .where((user) => user.role == AppRole.student)
        .length;
    final teachers = data.users
        .where((user) => user.role == AppRole.teacher)
        .length;
    final present = data.attendance
        .where((item) => item.status == 'present' || item.status == 'late')
        .length;
    final rate = data.attendance.isEmpty
        ? null
        : present / data.attendance.length;
    final recentSessions = [...data.sessions]
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricGrid(
          items: [
            ('Étudiants', '$students', Icons.school_outlined),
            ('Enseignants', '$teachers', Icons.co_present_outlined),
            ('Cours', '${data.courses.length}', Icons.menu_book_outlined),
            ('Séances', '${data.sessions.length}', Icons.event_outlined),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          rate == null
              ? 'Aucun pointage serveur disponible.'
              : 'Présence constatée sur les pointages enregistrés : ${(rate * 100).round()}%',
          style: const TextStyle(color: AppColors.secondary),
        ),
        const SizedBox(height: 18),
        const Text('Séances récentes', style: _sectionStyle),
        const SizedBox(height: 8),
        if (recentSessions.isEmpty)
          const _AdminEmpty('Aucune séance enregistrée.')
        else
          for (final session in recentSessions.take(5))
            _sessionCard(session, data.courses),
        const SizedBox(height: 16),
        const Text('Pointages récents', style: _sectionStyle),
        const SizedBox(height: 8),
        if (data.attendance.isEmpty)
          const _AdminEmpty('Aucun pointage serveur enregistré.')
        else
          for (final record in ([
            ...data.attendance,
          ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt))).take(5))
            ListTile(
              leading: Icon(
                _statusIcon(record.status),
                color: _statusColor(record.status),
              ),
              title: Text(_userLabel(data.users, record.studentUid)),
              subtitle: Text(_courseLabel(data.courses, record.courseId)),
              trailing: Text(_statusLabel(record.status)),
            ),
      ],
    );
  }

  Widget _users(AdminWorkspaceData data) {
    if (data.users.isEmpty) {
      return const _AdminEmpty('Aucun profil utilisateur.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Les comptes enseignant et administrateur sont provisionnés manuellement dans un environnement de confiance. Cette page ne permet pas de modifier les rôles.',
          style: TextStyle(color: AppColors.secondary, height: 1.45),
        ),
        const SizedBox(height: 12),
        for (final user in data.users)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Icon(_roleIcon(user.role))),
              title: Text(user.displayName),
              subtitle: Text(
                '${user.email}\n${user.role.label}${user.className?.isNotEmpty == true ? ' • ${user.className}' : ''}',
              ),
              isThreeLine: true,
              trailing: user.role == AppRole.student
                  ? IconButton(
                      tooltip: 'Attribuer une classe',
                      onPressed: _working ? null : () => _editClass(user),
                      icon: const Icon(Icons.edit_outlined),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _management(AdminWorkspaceData data) => DefaultTabController(
    length: 3,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Cours'),
            Tab(text: 'Inscriptions'),
            Tab(text: 'Séances'),
          ],
        ),
        SizedBox(
          height: 560,
          child: TabBarView(
            children: [
              _courseList(data),
              _enrollmentList(data),
              _sessionList(data),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _courseList(AdminWorkspaceData data) => ListView(
    padding: const EdgeInsets.only(top: 12),
    children: [
      FilledButton.icon(
        onPressed:
            _working ||
                data.users.where((u) => u.role == AppRole.teacher).isEmpty
            ? null
            : () => _createCourse(data),
        icon: const Icon(Icons.add),
        label: const Text('Créer un cours et affecter un enseignant'),
      ),
      const SizedBox(height: 10),
      if (data.courses.isEmpty)
        const _AdminEmpty('Aucun cours dans Firestore.'),
      for (final course in data.courses)
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.menu_book_outlined,
              color: AppColors.primary,
            ),
            title: Text(course.name),
            subtitle: Text(
              'Enseignant : ${course.teacherName}\n${data.enrollments.where((e) => e.courseId == course.id && e.status == 'active').length} inscription(s) active(s)',
            ),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 0,
              children: [
                IconButton(
                  tooltip: 'Modifier le cours ou l’affectation',
                  onPressed: _working
                      ? null
                      : () => _editCourse(
                          course,
                          data.users
                              .where((u) => u.role == AppRole.teacher)
                              .toList(),
                        ),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Supprimer le cours',
                  onPressed: _working ? null : () => _removeCourse(course),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _enrollmentList(AdminWorkspaceData data) => ListView(
    padding: const EdgeInsets.only(top: 12),
    children: [
      FilledButton.icon(
        onPressed:
            _working ||
                data.courses.isEmpty ||
                data.users.where((u) => u.role == AppRole.student).isEmpty
            ? null
            : () => _addEnrollment(data),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Inscrire un étudiant'),
      ),
      const SizedBox(height: 10),
      if (data.enrollments.isEmpty)
        const _AdminEmpty('Aucune inscription enregistrée.'),
      for (final enrollment in data.enrollments)
        Card(
          child: ListTile(
            leading: const Icon(Icons.assignment_ind_outlined),
            title: Text(_userLabel(data.users, enrollment.studentUid)),
            subtitle: Text(
              '${_courseLabel(data.courses, enrollment.courseId)} • ${enrollment.status}',
            ),
            trailing: IconButton(
              tooltip: 'Retirer l’inscription',
              onPressed: _working ? null : () => _removeEnrollment(enrollment),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ),
        ),
    ],
  );

  Widget _sessionList(AdminWorkspaceData data) => ListView(
    padding: const EdgeInsets.only(top: 12),
    children: [
      FilledButton.icon(
        onPressed: _working || data.courses.isEmpty
            ? null
            : () => _createSession(data),
        icon: const Icon(Icons.add),
        label: const Text('Créer une séance'),
      ),
      const SizedBox(height: 10),
      if (data.sessions.isEmpty)
        const _AdminEmpty('Aucune séance enregistrée.'),
      for (final session in [
        ...data.sessions,
      ]..sort((a, b) => a.startsAt.compareTo(b.startsAt)))
        _sessionCard(session, data.courses, allowActions: true),
    ],
  );

  Widget _sessionCard(
    AdminSession session,
    List<AdminCourse> courses, {
    bool allowActions = false,
  }) {
    final course = courses.where((c) => c.id == session.courseId).firstOrNull;
    final date = session.startsAt;
    final label =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.event_outlined, color: AppColors.primary),
        title: Text(course?.name ?? 'Cours'),
        subtitle: Text(
          '$label${session.room?.isNotEmpty == true ? ' • ${session.room}' : ''}',
        ),
        trailing: allowActions
            ? Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: 'Lancer la séance et afficher son QR',
                    onPressed: _working || course == null
                        ? null
                        : () => _launchSession(session, course),
                    icon: const Icon(Icons.qr_code_2_outlined),
                  ),
                  IconButton(
                    tooltip: 'Modifier la séance',
                    onPressed: _working
                        ? null
                        : () => _editSession(session, course),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Supprimer la séance',
                    onPressed: _working ? null : () => _removeSession(session),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _statistics(AdminWorkspaceData data) {
    final recentAttendance = [...data.attendance]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final present = data.attendance.where((r) => r.status == 'present').length;
    final late = data.attendance.where((r) => r.status == 'late').length;
    final absent = data.attendance.where((r) => r.status == 'absent').length;
    final known = present + late + absent;
    final rate = known == 0 ? null : (present + late) / known;
    final names = {for (final course in data.courses) course.id: course.name};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Les absences et le taux ci-dessous utilisent uniquement les documents attendance réellement enregistrés.',
          style: TextStyle(color: AppColors.secondary, height: 1.45),
        ),
        const SizedBox(height: 12),
        _MetricGrid(
          items: [
            ('Présents', '$present', Icons.check_circle_outline),
            ('Retards', '$late', Icons.schedule),
            ('Absences enregistrées', '$absent', Icons.cancel_outlined),
            (
              'Taux',
              rate == null ? '—' : '${(rate * 100).round()}%',
              Icons.analytics_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (data.attendance.isEmpty)
          const _AdminEmpty('Aucun pointage disponible.'),
        for (final item in recentAttendance.take(40))
          ListTile(
            dense: true,
            leading: Icon(
              _statusIcon(item.status),
              color: _statusColor(item.status),
            ),
            title: Text(names[item.courseId] ?? 'Cours'),
            subtitle: Text(
              'Étudiant ${item.studentUid} • Séance ${item.sessionId}',
            ),
            trailing: Text(_statusLabel(item.status)),
          ),
      ],
    );
  }

  Future<void> _editClass(AppUser student) async {
    final controller = TextEditingController(text: student.className ?? '');
    final value = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Classe de ${student.displayName}'),
        content: TextField(
          controller: controller,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Classe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Effacer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _run(() => _service.updateStudentClass(student.uid, value));
  }

  Future<void> _createCourse(AdminWorkspaceData data) async {
    final teachers = data.users
        .where((u) => u.role == AppRole.teacher)
        .toList();
    final name = TextEditingController();
    final description = TextEditingController();
    var teacher = teachers.first;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau cours'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom du cours'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Description facultative',
                  ),
                ),
                DropdownButtonFormField<AppUser>(
                  initialValue: teacher,
                  decoration: const InputDecoration(labelText: 'Enseignant'),
                  items: [
                    for (final user in teachers)
                      DropdownMenuItem(
                        value: user,
                        child: Text(user.displayName),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => teacher = value ?? teacher),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, name.text.trim().isNotEmpty),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _run(
        () => _service.createCourse(
          name: name.text,
          teacher: teacher,
          description: description.text,
        ),
      );
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _editCourse(AdminCourse course, List<AppUser> teachers) async {
    if (teachers.isEmpty) {
      _message('Aucun compte enseignant n’est provisionné.');
      return;
    }
    final name = TextEditingController(text: course.name);
    final description = TextEditingController(text: course.description ?? '');
    var teacher =
        teachers.where((user) => user.uid == course.teacherUid).firstOrNull ??
        teachers.first;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le cours'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom du cours'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Description facultative',
                  ),
                ),
                DropdownButtonFormField<AppUser>(
                  initialValue: teacher,
                  decoration: const InputDecoration(
                    labelText: 'Enseignant affecté',
                  ),
                  items: [
                    for (final user in teachers)
                      DropdownMenuItem(
                        value: user,
                        child: Text(user.displayName),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => teacher = value ?? teacher),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, name.text.trim().isNotEmpty),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _run(
        () => _service.updateCourse(
          courseId: course.id,
          name: name.text,
          teacher: teacher,
          description: description.text,
        ),
      );
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _addEnrollment(AdminWorkspaceData data) async {
    final students = data.users
        .where((u) => u.role == AppRole.student)
        .toList();
    final selectedStudentUids = <String>{};
    var course = data.courses.first;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Inscrire des étudiants'),
          content: SizedBox(
            width: 420,
            height: 390,
            child: Column(
              children: [
                DropdownButtonFormField<AdminCourse>(
                  initialValue: course,
                  decoration: const InputDecoration(labelText: 'Cours'),
                  items: [
                    for (final item in data.courses)
                      DropdownMenuItem(value: item, child: Text(item.name)),
                  ],
                  onChanged: (value) => setDialogState(() {
                    course = value ?? course;
                    selectedStudentUids.clear();
                  }),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final student in students)
                        Builder(
                          builder: (context) {
                            final alreadyEnrolled = data.enrollments.any(
                              (enrollment) =>
                                  enrollment.studentUid == student.uid &&
                                  enrollment.courseId == course.id &&
                                  enrollment.status == 'active',
                            );
                            return CheckboxListTile(
                              value: selectedStudentUids.contains(student.uid),
                              title: Text(student.displayName),
                              subtitle: alreadyEnrolled
                                  ? const Text('Déjà inscrit')
                                  : null,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: alreadyEnrolled
                                  ? null
                                  : (selected) => setDialogState(() {
                                      if (selected == true) {
                                        selectedStudentUids.add(student.uid);
                                      } else {
                                        selectedStudentUids.remove(student.uid);
                                      }
                                    }),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selectedStudentUids.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Inscrire'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final selectedStudents = students
          .where((student) => selectedStudentUids.contains(student.uid))
          .toList();
      await _run(
        () => _service.createEnrollments(
          students: selectedStudents,
          course: course,
        ),
      );
    }
  }

  Future<void> _createSession(AdminWorkspaceData data) async {
    var course = data.courses.first;
    var startsAt = DateTime.now().add(const Duration(hours: 1));
    var endsAt = startsAt.add(const Duration(hours: 2));
    final room = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouvelle séance'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AdminCourse>(
                  initialValue: course,
                  decoration: const InputDecoration(labelText: 'Cours'),
                  items: [
                    for (final item in data.courses)
                      DropdownMenuItem(value: item, child: Text(item.name)),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => course = value ?? course),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startsAt,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(startsAt),
                    );
                    if (time != null) {
                      setDialogState(() {
                        startsAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                        if (!endsAt.isAfter(startsAt)) {
                          endsAt = startsAt.add(const Duration(hours: 2));
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    '${startsAt.day}/${startsAt.month}/${startsAt.year} ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endsAt,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(endsAt),
                    );
                    if (time != null) {
                      setDialogState(
                        () => endsAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                    'Fin : ${endsAt.day}/${endsAt.month}/${endsAt.year} ${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}',
                  ),
                ),
                if (!endsAt.isAfter(startsAt))
                  const Text(
                    'La fin doit être postérieure au début.',
                    style: TextStyle(color: AppColors.error),
                  ),
                TextField(
                  controller: room,
                  decoration: const InputDecoration(
                    labelText: 'Salle facultative',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: endsAt.isAfter(startsAt)
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _run(
        () => _service.createSession(
          course: course,
          startsAt: startsAt,
          endsAt: endsAt,
          room: room.text,
        ),
      );
    }
    room.dispose();
  }

  Future<void> _editSession(AdminSession session, AdminCourse? course) async {
    if (course == null) {
      _message('Le cours associé à cette séance est introuvable.');
      return;
    }
    var startsAt = session.startsAt;
    var endsAt =
        session.endsAt ?? session.startsAt.add(const Duration(hours: 2));
    final room = TextEditingController(text: session.room ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Modifier • ${course.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: startsAt,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(startsAt),
                  );
                  if (time != null) {
                    setDialogState(() {
                      startsAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                      if (!endsAt.isAfter(startsAt)) {
                        endsAt = startsAt.add(const Duration(hours: 2));
                      }
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  '${startsAt.day}/${startsAt.month}/${startsAt.year} ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: endsAt,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(endsAt),
                  );
                  if (time != null) {
                    setDialogState(
                      () => endsAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  'Fin : ${endsAt.day}/${endsAt.month}/${endsAt.year} ${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
              if (!endsAt.isAfter(startsAt))
                const Text(
                  'La fin doit être postérieure au début.',
                  style: TextStyle(color: AppColors.error),
                ),
              TextField(
                controller: room,
                decoration: const InputDecoration(
                  labelText: 'Salle facultative',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: endsAt.isAfter(startsAt)
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _run(
        () => _service.updateSession(
          sessionId: session.id,
          course: course,
          startsAt: startsAt,
          endsAt: endsAt,
          room: room.text,
        ),
      );
    }
    room.dispose();
  }

  Future<void> _removeSession(AdminSession session) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette séance ?'),
        content: const Text(
          'La suppression est refusée si des pointages existent pour cette séance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (yes == true) await _run(() => _service.removeSession(session));
  }

  Future<void> _removeEnrollment(AdminEnrollment enrollment) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cette inscription ?'),
        content: const Text(
          'L’étudiant perdra l’accès au cours et à ses séances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (yes == true) await _run(() => _service.removeEnrollment(enrollment.id));
  }

  Future<void> _launchSession(AdminSession session, AdminCourse? course) async {
    if (course == null) {
      _message('Le cours associé à cette séance est introuvable.');
      return;
    }

    final startsNow = session.startsAt.isAfter(DateTime.now());
    if (startsNow) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Démarrer la séance maintenant ?'),
          content: const Text(
            'L’heure de début prévue sera remplacée par l’heure actuelle. '
            'La durée prévue sera conservée et le QR sera ensuite généré.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Démarrer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final startsAt = startsNow ? DateTime.now() : session.startsAt;
    final duration = session.endsAt?.difference(session.startsAt);
    final endsAt = startsNow && duration != null
        ? startsAt.add(duration)
        : session.endsAt;

    setState(() => _working = true);
    try {
      if (startsNow) {
        await _service.updateSession(
          sessionId: session.id,
          course: course,
          startsAt: startsAt,
          endsAt: endsAt,
          room: session.room,
        );
      }

      final token = await _qrService.generate(session.id);
      if (!mounted) return;
      _reload();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Séance lancée • ${course.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: token.payload,
                size: 230,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                'QR signé par Firebase. Valide jusqu’à '
                '${TimeOfDay.fromDateTime(token.expiresAt).format(context)} '
                '(15 minutes après le début).',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'permission-denied' =>
          'Accès refusé. Vérifiez le rôle admin et son custom claim Firebase.',
        'failed-precondition' => 'La séance ne peut pas être lancée. Vérifiez son horaire et son affectation.',
        'deadline-exceeded' => 'La fenêtre QR de 15 minutes est dépassée. Modifiez l’horaire de la séance puis relancez-la.',
        'unauthenticated' => 'Reconnectez-vous pour lancer une séance.',
        _ => 'Impossible de générer le QR (${error.message ?? error.code}).',
      };
      _message(message);
    } on FirebaseException catch (error) {
      if (mounted) {
        _message('Impossible de démarrer la séance (${error.code}).');
      }
    } catch (error) {
      if (mounted) _message('Impossible de lancer la séance : $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _removeCourse(AdminCourse course) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce cours ?'),
        content: const Text(
          'La suppression est refusée tant que des inscriptions, des séances '
          'ou des pointages sont associés au cours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (yes == true) await _run(() => _service.removeCourse(course));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      _reload();
      _message('Enregistré.');
    } on FirebaseException catch (error) {
      if (mounted) _message('Opération refusée par Firestore (${error.code}).');
    } catch (error) {
      if (mounted) _message('Impossible de terminer l’opération : $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<(String, String, IconData)> items;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final item in items)
        SizedBox(
          width: 170,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$3, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item.$1,
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.secondary),
      ),
    ),
  );
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Impossible de charger les données : $error',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: retry, child: const Text('Réessayer')),
      ],
    ),
  );
}

String _userLabel(List<AppUser> users, String uid) =>
    users.where((u) => u.uid == uid).firstOrNull?.displayName ?? uid;
String _courseLabel(List<AdminCourse> courses, String id) =>
    courses.where((c) => c.id == id).firstOrNull?.name ?? id;
IconData _roleIcon(AppRole role) => switch (role) {
  AppRole.student => Icons.school_outlined,
  AppRole.teacher => Icons.co_present_outlined,
  AppRole.admin => Icons.admin_panel_settings_outlined,
};
IconData _statusIcon(String value) => switch (value) {
  'present' => Icons.check_circle_outline,
  'late' => Icons.schedule,
  _ => Icons.cancel_outlined,
};
Color _statusColor(String value) => switch (value) {
  'present' => AppColors.success,
  'late' => Colors.orange,
  _ => AppColors.error,
};
String _statusLabel(String value) => switch (value) {
  'present' => 'Présent',
  'late' => 'Retard',
  _ => 'Absent',
};

const _titleStyle = TextStyle(
  color: AppColors.primaryDark,
  fontSize: 20,
  fontWeight: FontWeight.w800,
);
const _sectionStyle = TextStyle(
  color: AppColors.primaryDark,
  fontSize: 16,
  fontWeight: FontWeight.w700,
);
