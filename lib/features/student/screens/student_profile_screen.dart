import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/app_user.dart';
import '../../../services/auth_service.dart';
import '../services/student_dashboard_service.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key, required this.user, this.repository, this.onDisplayNameChanged});

  final AppUser user;
  final StudentDataRepository? repository;
  final ValueChanged<String>? onDisplayNameChanged;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;
  late String _displayName;

  StudentDataRepository get _service =>
      widget.repository ?? StudentDashboardService();

  @override
  void initState() {
    super.initState();
    _displayName = widget.user.displayName;
    _nameController = TextEditingController(text: _displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _service.updateDisplayName(widget.user.uid, _nameController.text);
      if (mounted) {
        setState(() => _displayName = _nameController.text.trim());
        widget.onDisplayNameChanged?.call(_displayName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre nom a été mis à jour.')),
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de modifier le profil (${error.code}).'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _formKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.paleBlue,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Nom et prénom',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom ne peut pas être vide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: widget.user.email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Adresse e-mail',
                      prefixIcon: Icon(Icons.mail_outline),
                      helperText: 'L’adresse e-mail n’est pas modifiable ici.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: widget.user.className ?? 'Non renseignée',
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Classe',
                      prefixIcon: Icon(Icons.groups_outlined),
                      helperText:
                          'La classe est attribuée par l’établissement.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: widget.user.role.label,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Rôle',
                      prefixIcon: Icon(Icons.badge_outlined),
                      helperText: 'Le rôle ne peut pas être modifié ici.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? 'Enregistrement...' : 'Enregistrer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de se déconnecter (${error.code}).'),
          ),
        );
      }
    }
  }
}
