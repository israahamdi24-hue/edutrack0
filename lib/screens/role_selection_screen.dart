
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/auth_header.dart';
import 'home_router.dart';

enum DemoRole {
  student,
  teacher,
  admin,
}

extension DemoRoleLabel on DemoRole {
  String get label {
    switch (this) {
      case DemoRole.student:
        return 'Étudiant';
      case DemoRole.teacher:
        return 'Enseignant';
      case DemoRole.admin:
        return 'Administrateur';
    }
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = [
      (
        DemoRole.student,
        Icons.school_outlined,
        'Consulter mes cours et mes présences',
      ),
      (
        DemoRole.teacher,
        Icons.co_present_outlined,
        'Gérer les séances et les présences',
      ),
      (
        DemoRole.admin,
        Icons.admin_panel_settings_outlined,
        'Gérer les utilisateurs et les classes',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  const AuthHeader(
                    title: 'Bienvenue sur EduTrack',
                    subtitle:
                        'Découvrez les espaces de votre application.',
                  ),
                  const SizedBox(height: 28),
                  for (final item in roles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HomeRouter(
                                role: item.$1,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.paleBlue,
                                  borderRadius:
                                      BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  item.$2,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.$1.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.$3,
                                      style: const TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mode maquette : les rôles seront vérifiés '
                    'par le back-end dans la version finale.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
