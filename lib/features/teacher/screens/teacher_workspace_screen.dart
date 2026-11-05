import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/app_user.dart';
import '../services/teacher_data_service.dart';
import '../services/teacher_session_qr_service.dart';

class TeacherWorkspaceScreen extends StatefulWidget {
  const TeacherWorkspaceScreen({
    super.key,
    required this.user,
    required this.sectionIndex,
    this.service,
    this.qrService,
  });

  final AppUser user;
  final int sectionIndex;
  final TeacherDataService? service;
  final TeacherSessionQrService? qrService;

  @override
  State<TeacherWorkspaceScreen> createState() => _TeacherWorkspaceScreenState();
}

class _TeacherWorkspaceScreenState extends State<TeacherWorkspaceScreen> {
  late Future<_TeacherData> _data;
  bool _isSaving = false;

  TeacherDataService get _service => widget.service ?? TeacherDataService();
  TeacherSessionQrService get _qrService =>
      widget.qrService ?? TeacherSessionQrService();

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_TeacherData> _load() async {
    final courses = await _service.loadCourses(widget.user.uid);
    final results = await Future.wait([
      _service.loadSessions(widget.user.uid),
      _service.loadAttendance(courses),
    ]);
    return _TeacherData(
      courses: courses,
      sessions: results[0] as List<TeacherSession>,
      attendance: results[1] as List<TeacherAttendance>,
    );
  }

  void _reload() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TeacherData>(
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
          return _ErrorPanel(error: snapshot.error!, onRetry: _reload);
        }
        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(_title, style: _headingStyle)),
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
              1 => _courses(data),
              2 => _sessions(data),
              3 => _attendance(data),
              _ => const SizedBox.shrink(),
            },
          ],
        );
      },
    );
  }

  String get _title => switch (widget.sectionIndex) {
    0 => 'Tableau de bord enseignant',
    1 => 'Mes cours et étudiants inscrits',
    2 => 'Séances et QR de présence',
    3 => 'Suivi des présences',
    _ => 'Espace enseignant',
  };

  Widget _dashboard(_TeacherData data) {
    final now = DateTime.now();
    final upcoming = data.sessions.where((s) => s.startsAt.isAfter(now)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsRow(items: [
          ('Cours affectés', '${data.courses.length}', Icons.menu_book_outlined),
          ('Séances à venir', '${upcoming.length}', Icons.event_outlined),
          ('Pointages', '${data.attendance.length}', Icons.fact_check_outlined),
        ]),
        const SizedBox(height: 22),
        const Text('Prochaines séances', style: _subheadingStyle),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          const _EmptyPanel('Aucune séance à venir pour vos cours affectés.')
        else
          for (final session in upcoming.take(5)) _sessionTile(session, allowQr: false),
      ],
    );
  }

  Widget _courses(_TeacherData data) {
    if (data.courses.isEmpty) {
      return const _EmptyPanel('Aucun cours ne vous est affecté pour le moment.');
    }
    return Column(
      children: [
        for (final course in data.courses)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.paleBlue,
                child: Icon(Icons.menu_book_outlined, color: AppColors.primary),
              ),
              title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(course.description?.isNotEmpty == true
                  ? course.description!
                  : 'Aucune description renseignée.'),
              trailing: IconButton(
                tooltip: 'Étudiants inscrits',
                onPressed: () => _showStudents(course),
                icon: const Icon(Icons.people_alt_outlined),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sessions(_TeacherData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _isSaving || data.courses.isEmpty
              ? null
              : () => _createSession(data.courses),
          icon: const Icon(Icons.add),
          label: const Text('Créer une séance'),
        ),
        const SizedBox(height: 12),
        if (data.sessions.isEmpty)
          const _EmptyPanel('Aucune séance enregistrée pour vos cours.')
        else
          for (final session in data.sessions) _sessionTile(session, allowQr: true),
      ],
    );
  }

  Widget _attendance(_TeacherData data) {
    if (data.attendance.isEmpty) {
      return const _EmptyPanel('Aucun pointage serveur n’est disponible pour vos cours.');
    }
    final present = data.attendance.where((r) => r.status == 'present').length;
    final late = data.attendance.where((r) => r.status == 'late').length;
    final absent = data.attendance.where((r) => r.status == 'absent').length;
    final courseNames = {for (final course in data.courses) course.id: course.name};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsRow(items: [
          ('Présents', '$present', Icons.check_circle_outline),
          ('En retard', '$late', Icons.schedule),
          ('Absences enregistrées', '$absent', Icons.cancel_outlined),
        ]),
        const SizedBox(height: 12),
        for (final record in data.attendance)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(_statusIcon(record.status), color: _statusColor(record.status)),
              title: Text(courseNames[record.courseId] ?? 'Cours'),
              subtitle: Text('Étudiant ${record.studentUid} • Séance ${record.sessionId}'),
              trailing: Text(_statusName(record.status)),
            ),
          ),
      ],
    );
  }

  Widget _sessionTile(TeacherSession session, {required bool allowQr}) {
    final date = session.startsAt;
    final dateText = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: const Icon(Icons.event_available_outlined, color: AppColors.primary),
        title: Text(session.courseName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$dateText${session.room?.isNotEmpty == true ? ' • ${session.room}' : ''}'),
        trailing: allowQr
            ? PopupMenuButton<String>(
                tooltip: 'Gérer la séance',
                onSelected: (action) {
                  switch (action) {
                    case 'qr': _showQr(session);
                    case 'edit': _editSession(session);
                    case 'delete': _removeSession(session);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'qr', child: Text('Afficher le QR signé')),
                  PopupMenuItem(value: 'edit', child: Text('Modifier la séance')),
                  PopupMenuItem(value: 'delete', child: Text('Supprimer la séance')),
                ],
                icon: const Icon(Icons.more_vert),
              )
            : null,
      ),
    );
  }

  Future<void> _showStudents(TeacherCourse course) async {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Étudiants • ${course.name}'),
        content: FutureBuilder<List<EnrolledStudent>>(
          future: _service.loadEnrolledStudents(course.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Impossible de charger les inscriptions (${snapshot.error}).');
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) return const Text('Aucun étudiant inscrit activement.');
            return SizedBox(
              width: 380,
              child: ListView(shrinkWrap: true, children: [
                for (final student in snapshot.data!)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(student.displayName),
                    subtitle: Text(student.className ?? 'Classe non renseignée'),
                  ),
              ]),
            );
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _createSession(List<TeacherCourse> courses) async {
    final formKey = GlobalKey<FormState>();
    final roomController = TextEditingController();
    var courseId = courses.first.id;
    var startsAt = DateTime.now().add(const Duration(hours: 1));
    var endsAt = startsAt.add(const Duration(hours: 2));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouvelle séance'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: courseId,
                    decoration: const InputDecoration(labelText: 'Cours'),
                    items: [for (final c in courses) DropdownMenuItem(value: c.id, child: Text(c.name))],
                    onChanged: (value) => courseId = value ?? courseId,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startsAt,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startsAt));
                      if (time == null) return;
                      setDialogState(() {
                        startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        endsAt = startsAt.add(const Duration(hours: 2));
                      });
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Début : ${startsAt.day}/${startsAt.month}/${startsAt.year} ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}'),
                  ),
                  TextFormField(
                    controller: roomController,
                    decoration: const InputDecoration(labelText: 'Salle (facultatif)'),
                    maxLength: 80,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, formKey.currentState!.validate()), child: const Text('Créer')),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      roomController.dispose();
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _service.createSession(
        courseId: courseId,
        teacherUid: widget.user.uid,
        startsAt: startsAt,
        endsAt: endsAt,
        room: roomController.text,
      );
      _reload();
      if (mounted) _message('Séance créée. Le QR peut être demandé au serveur.');
    } on FirebaseException catch (error) {
      if (mounted) _message('Création refusée (${error.code}). Vérifiez vos droits.');
    } finally {
      roomController.dispose();
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showQr(TeacherSession session) async {
    try {
      final token = await _qrService.generate(session.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('QR • ${session.courseName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: token.payload, size: 230, backgroundColor: Colors.white),
              const SizedBox(height: 12),
              const Text('Le QR est signé par le serveur et expire 15 minutes après le début de la séance.', textAlign: TextAlign.center),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _message('Impossible de générer le QR (${error.message ?? error.code}).');
    } catch (error) {
      if (mounted) _message('Le QR n’a pas pu être généré : $error');
    }
  }

  Future<void> _editSession(TeacherSession session) async {
    var startsAt = session.startsAt;
    final room = TextEditingController(text: session.room ?? '');
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text('Modifier • ${session.courseName}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton.icon(
          onPressed: () async {
            final date = await showDatePicker(context: context, initialDate: startsAt, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startsAt));
            if (time != null) setDialogState(() => startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text('${startsAt.day}/${startsAt.month}/${startsAt.year} ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}'),
        ),
        TextField(controller: room, decoration: const InputDecoration(labelText: 'Salle facultative')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer'))],
    )));
    if (saved == true) {
      final duration = session.endsAt?.difference(session.startsAt) ?? const Duration(hours: 2);
      setState(() => _isSaving = true);
      try {
        await _service.updateSession(
          session: session,
          teacherUid: widget.user.uid,
          startsAt: startsAt,
          endsAt: startsAt.add(duration),
          room: room.text,
        );
        _reload();
        if (mounted) _message('Séance mise à jour.');
      } on FirebaseException catch (error) {
        if (mounted) _message('Modification refusée (${error.code}).');
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
    room.dispose();
  }

  Future<void> _removeSession(TeacherSession session) async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Supprimer cette séance ?'),
      content: const Text('La suppression est refusée si des pointages existent pour cette séance.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer'))],
    ));
    if (yes != true) return;
    setState(() => _isSaving = true);
    try {
      await _service.removeSession(session);
      _reload();
      if (mounted) _message('Séance supprimée.');
    } on FirebaseException catch (error) {
      if (mounted) _message('Suppression refusée (${error.code}).');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _TeacherData {
  const _TeacherData({required this.courses, required this.sessions, required this.attendance});
  final List<TeacherCourse> courses;
  final List<TeacherSession> sessions;
  final List<TeacherAttendance> attendance;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});
  final List<(String, String, IconData)> items;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final item in items)
        SizedBox(
          width: 185,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(item.$3, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(item.$2, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                Text(item.$1, style: const TextStyle(color: AppColors.secondary)),
              ]),
            ),
          ),
        ),
    ],
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(22),
    child: Center(child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondary))),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Impossible de charger les données : $error', textAlign: TextAlign.center),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
    ]),
  );
}

const _headingStyle = TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w800);
const _subheadingStyle = TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w700);

IconData _statusIcon(String status) => switch (status) {
  'present' => Icons.check_circle_outline,
  'late' => Icons.schedule,
  _ => Icons.cancel_outlined,
};
Color _statusColor(String status) => switch (status) {
  'present' => AppColors.success,
  'late' => Colors.orange,
  _ => AppColors.error,
};
String _statusName(String status) => switch (status) {
  'present' => 'Présent',
  'late' => 'En retard',
  _ => 'Absent',
};
