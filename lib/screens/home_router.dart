
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class HomeRouter extends StatefulWidget {
  final DemoRole role;

  const HomeRouter({
    super.key,
    required this.role,
  });

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  int selectedIndex = 0;

  String get roleName {
    switch (widget.role) {
      case DemoRole.student:
        return 'Étudiant';
      case DemoRole.teacher:
        return 'Enseignant';
      case DemoRole.admin:
        return 'Administrateur';
    }
  }

  String get pageTitle {
    if (widget.role == DemoRole.student) {
      return [
        'Mon espace',
        'Mes cours',
        'Mes présences',
        'Notifications',
        'Mon profil',
      ][selectedIndex];
    }

    if (widget.role == DemoRole.teacher) {
      return [
        'Mon espace',
        'Mes classes',
        'Séances',
        'Présences',
        'Mon profil',
      ][selectedIndex];
    }

    return [
      'Vue générale',
      'Utilisateurs',
      'Classes et matières',
      'Statistiques',
      'Paramètres',
    ][selectedIndex];
  }

  List<NavigationDestination> get destinations {
    if (widget.role == DemoRole.student) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Cours',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'Présences',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alertes',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    }

    if (widget.role == DemoRole.teacher) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Classes',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Séances',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'Présences',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    }

    return const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Accueil',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Utilisateurs',
      ),
      NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school),
        label: 'Classes',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Statistiques',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Paramètres',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'EduTrack',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  if (widget.role == DemoRole.student) {
                    setState(() => selectedIndex = 3);
                  } else {
                    _showMessage('Les notifications seront bientôt disponibles.');
                  }
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 4),
                child: CircleAvatar(
                  backgroundColor: AppColors.paleBlue,
                  child: Text(
                    roleName.substring(0, 1),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              if (isWide) _buildSidebar(),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWide ? 28 : 18),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPageHeader(),
                            const SizedBox(height: 24),
                            if (selectedIndex == 0)
                              _buildOverview()
                            else
                              _buildSelectedPage(),
                            const SizedBox(height: 28),
                            const Center(
                              child: Text(
                                'EduTrack • Smart Learning & Attendance',
                                style: TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => selectedIndex = index);
                  },
                  destinations: destinations,
                  backgroundColor: Colors.white,
                  indicatorColor: AppColors.paleBlue,
                ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.paleBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleName,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bienvenue sur EduTrack',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final selected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: selected,
                    selectedTileColor: AppColors.paleBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      selected
                          ? _selectedIcon(index)
                          : _unselectedIcon(index),
                      color: selected
                          ? AppColors.primary
                          : AppColors.secondary,
                    ),
                    title: Text(
                      destination.label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primaryDark,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      setState(() => selectedIndex = index);
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
            ),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: _logout,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  IconData _selectedIcon(int index) {
    final destination = destinations[index];
    return (destination.selectedIcon as Icon).icon ??
        Icons.dashboard;
  }

  IconData _unselectedIcon(int index) {
    final destination = destinations[index];
    return (destination.icon as Icon).icon ?? Icons.dashboard_outlined;
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pageTitle,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          selectedIndex == 0
              ? 'Bonjour ! Voici un aperçu de votre activité.'
              : 'Retrouvez ici vos informations et vos outils.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview() {
    if (widget.role == DemoRole.student) {
      return _buildStudentOverview();
    }

    if (widget.role == DemoRole.teacher) {
      return _buildTeacherOverview();
    }

    return _buildAdminOverview();
  }

  Widget _buildStudentOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeBanner(
          title: 'Continuez à progresser !',
          subtitle:
              'Suivez vos cours et gardez un œil sur vos présences.',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: 20),
        _buildStatsGrid([
          _StatData(
            'Taux de présence',
            '92%',
            Icons.fact_check_outlined,
            AppColors.success,
          ),
          _StatData(
            'Cours suivis',
            '8',
            Icons.menu_book_outlined,
            AppColors.primary,
          ),
          _StatData(
            'Absences',
            '2',
            Icons.event_busy_outlined,
            AppColors.error,
          ),
        ]),
        const SizedBox(height: 26),
        _sectionTitle('Prochaine séance'),
        const SizedBox(height: 12),
        _buildSessionCard(
          title: 'Développement mobile',
          subtitle: 'Aujourd’hui • 10:00 – 12:00',
          room: 'Salle B12',
          icon: Icons.phone_android_rounded,
        ),
        const SizedBox(height: 24),
        _sectionTitle('Accès rapide'),
        const SizedBox(height: 12),
        _buildActionGrid([
          _ActionData(
            'Scanner un QR code',
            'Enregistrer ma présence',
            Icons.qr_code_scanner_rounded,
            () => _showMessage(
              'Le scanner sera connecté à la caméra dans une prochaine étape.',
            ),
          ),
          _ActionData(
            'Historique',
            'Consulter mes présences',
            Icons.history_rounded,
            () => setState(() => selectedIndex = 2),
          ),
        ]),
      ],
    );
  }

  Widget _buildTeacherOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeBanner(
          title: 'Votre espace enseignant',
          subtitle:
              'Organisez vos séances et suivez les présences de vos étudiants.',
          icon: Icons.co_present_rounded,
        ),
        const SizedBox(height: 20),
        _buildStatsGrid([
          _StatData(
            'Mes classes',
            '4',
            Icons.groups_outlined,
            AppColors.primary,
          ),
          _StatData(
            'Séances cette semaine',
            '6',
            Icons.calendar_month_outlined,
            const Color(0xFF805AD5),
          ),
          _StatData(
            'Présence moyenne',
            '89%',
            Icons.fact_check_outlined,
            AppColors.success,
          ),
        ]),
        const SizedBox(height: 26),
        _sectionTitle('Séances récentes'),
        const SizedBox(height: 12),
        _buildSessionCard(
          title: 'Programmation Python',
          subtitle: 'Aujourd’hui • 08:00 – 10:00',
          room: 'Salle A03',
          icon: Icons.code_rounded,
        ),
        const SizedBox(height: 12),
        _buildSessionCard(
          title: 'Développement mobile',
          subtitle: 'Demain • 10:00 – 12:00',
          room: 'Salle B12',
          icon: Icons.phone_android_rounded,
        ),
        const SizedBox(height: 24),
        _sectionTitle('Actions rapides'),
        const SizedBox(height: 12),
        _buildActionGrid([
          _ActionData(
            'Ouvrir une séance',
            'Préparer une nouvelle séance',
            Icons.add_circle_outline,
            () => setState(() => selectedIndex = 2),
          ),
          _ActionData(
            'Voir les présences',
            'Suivre les étudiants',
            Icons.fact_check_outlined,
            () => setState(() => selectedIndex = 3),
          ),
        ]),
      ],
    );
  }

  Widget _buildAdminOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeBanner(
          title: 'Administration EduTrack',
          subtitle:
              'Gérez les utilisateurs, les affectations et le suivi global.',
          icon: Icons.admin_panel_settings_outlined,
        ),
        const SizedBox(height: 20),
        _buildStatsGrid([
          _StatData(
            'Étudiants',
            '248',
            Icons.school_outlined,
            AppColors.primary,
          ),
          _StatData(
            'Enseignants',
            '18',
            Icons.co_present_outlined,
            const Color(0xFF805AD5),
          ),
          _StatData(
            'Classes',
            '12',
            Icons.groups_outlined,
            AppColors.success,
          ),
          _StatData(
            'Présence globale',
            '91%',
            Icons.bar_chart_rounded,
            const Color(0xFFE69B22),
          ),
        ]),
        const SizedBox(height: 26),
        _sectionTitle('Gestion rapide'),
        const SizedBox(height: 12),
        _buildActionGrid([
          _ActionData(
            'Utilisateurs',
            'Gérer les comptes',
            Icons.people_outline,
            () => setState(() => selectedIndex = 1),
          ),
          _ActionData(
            'Classes et matières',
            'Organiser les groupes',
            Icons.school_outlined,
            () => setState(() => selectedIndex = 2),
          ),
          _ActionData(
            'Statistiques',
            'Consulter les indicateurs',
            Icons.analytics_outlined,
            () => setState(() => selectedIndex = 3),
          ),
        ]),
        const SizedBox(height: 24),
        _sectionTitle('Activité récente'),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Gestion des utilisateurs',
          subtitle: 'Consultez et gérez les comptes de la plateforme.',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          icon: Icons.event_available_outlined,
          title: 'Suivi des séances',
          subtitle: 'Retrouvez les séances et leur état de présence.',
        ),
      ],
    );
  }

  Widget _buildSelectedPage() {
    if (widget.role == DemoRole.student) {
      switch (selectedIndex) {
        case 1:
          return _buildListPage(
            'Mes cours',
            [
              ('Développement mobile', 'Lundi • 10:00', Icons.phone_android),
              ('Programmation Python', 'Mardi • 08:00', Icons.code),
              ('Bases de données', 'Mercredi • 14:00', Icons.storage),
              ('Génie logiciel', 'Jeudi • 09:00', Icons.architecture),
            ],
          );
        case 2:
          return Column(
            children: [
              _buildStatsGrid([
                _StatData(
                  'Présences',
                  '22',
                  Icons.check_circle_outline,
                  AppColors.success,
                ),
                _StatData(
                  'Absences',
                  '2',
                  Icons.cancel_outlined,
                  AppColors.error,
                ),
              ]),
              const SizedBox(height: 20),
              _buildListPage(
                'Historique des présences',
                [
                  ('Développement mobile', 'Présent • 14 octobre', Icons.check_circle),
                  ('Programmation Python', 'Présent • 12 octobre', Icons.check_circle),
                  ('Bases de données', 'Absent • 10 octobre', Icons.cancel),
                ],
              ),
            ],
          );
        case 3:
          return _buildListPage(
            'Notifications',
            [
              ('Nouvelle séance', 'Une séance est prévue prochainement.', Icons.notifications),
              ('Rappel de cours', 'Vérifiez votre emploi du temps.', Icons.alarm),
            ],
          );
        default:
          return _buildProfile();
      }
    }

    if (widget.role == DemoRole.teacher) {
      switch (selectedIndex) {
        case 1:
          return _buildListPage(
            'Mes classes',
            [
              ('DSI L3 - Groupe A', '32 étudiants', Icons.groups),
              ('DSI L3 - Groupe B', '28 étudiants', Icons.groups),
              ('DSI L2 - Groupe A', '30 étudiants', Icons.groups),
              ('DSI L2 - Groupe B', '26 étudiants', Icons.groups),
            ],
          );
        case 2:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeBanner(
                title: 'Gestion des séances',
                subtitle: 'Préparez une séance et sa future validation de présence.',
                icon: Icons.calendar_month_outlined,
              ),
              const SizedBox(height: 18),
              _buildActionGrid([
                _ActionData(
                  'Préparer une séance',
                  'Créer une séance de cours',
                  Icons.add_circle_outline,
                  () => _showMessage(
                    'La création des séances sera connectée au backend.',
                  ),
                ),
                _ActionData(
                  'Générer un QR code',
                  'Préparer le pointage',
                  Icons.qr_code_2_rounded,
                  () => _showMessage(
                    'Le QR code sécurisé sera développé dans la prochaine étape.',
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _buildListPage(
                'Séances programmées',
                [
                  ('Programmation Python', 'Aujourd’hui • 08:00', Icons.code),
                  ('Développement mobile', 'Demain • 10:00', Icons.phone_android),
                ],
              ),
            ],
          );
        case 3:
          return _buildListPage(
            'Suivi des présences',
            [
              ('Programmation Python', '28 présents sur 32', Icons.fact_check),
              ('Développement mobile', '25 présents sur 30', Icons.fact_check),
            ],
          );
        default:
          return _buildProfile();
      }
    }

    switch (selectedIndex) {
      case 1:
        return _buildListPage(
          'Gestion des utilisateurs',
          [
            ('Étudiants', 'Consulter les comptes étudiants', Icons.school),
            ('Enseignants', 'Consulter les comptes enseignants', Icons.co_present),
            ('Administrateurs', 'Gérer les accès administratifs', Icons.admin_panel_settings),
          ],
        );
      case 2:
        return _buildListPage(
          'Classes et matières',
          [
            ('DSI L3 - Groupe A', '32 étudiants • 5 matières', Icons.groups),
            ('DSI L3 - Groupe B', '28 étudiants • 5 matières', Icons.groups),
            ('Développement mobile', 'Matière • Enseignant à affecter', Icons.menu_book),
          ],
        );
      case 3:
        return Column(
          children: [
            _buildStatsGrid([
              _StatData('Présence globale', '91%', Icons.bar_chart, AppColors.success),
              _StatData('Étudiants actifs', '248', Icons.people, AppColors.primary),
              _StatData('Séances', '36', Icons.event, const Color(0xFF805AD5)),
            ]),
            const SizedBox(height: 20),
            _buildInfoCard(
              icon: Icons.insights_outlined,
              title: 'Statistiques globales',
              subtitle: 'Les graphiques réels seront alimentés par Firestore.',
            ),
          ],
        );
      default:
        return _buildProfile();
    }
  }

  Widget _buildWelcomeBanner({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 48),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(List<_StatData> stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 430
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.map((stat) {
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: stat.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(stat.icon, color: stat.color),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      stat.value,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stat.title,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActionGrid(List<_ActionData> actions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 2 : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions.map((action) {
            return SizedBox(
              width: width,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: action.onTap,
                child: Container(
                  padding: const EdgeInsets.all(18),
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
                          color: AppColors.paleBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          action.icon,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              action.subtitle,
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSessionCard({
    required String title,
    required String subtitle,
    required String room,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.paleBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  room,
                  style: const TextStyle(
                    color: AppColors.primary,
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 27),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
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

  Widget _buildListPage(
    String title,
    List<(String, String, IconData)> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        const SizedBox(height: 14),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildInfoCard(
              icon: item.$3,
              title: item.$1,
              subtitle: item.$2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.paleBlue,
            child: Icon(
              Icons.person,
              color: AppColors.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            roleName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Compte de démonstration',
            style: TextStyle(color: AppColors.secondary),
          ),
          const SizedBox(height: 22),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Rôle'),
            trailing: Text(roleName),
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Sécurité du compte'),
            subtitle: const Text('Disponible après la connexion Firebase'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryDark,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatData(
    this.title,
    this.value,
    this.icon,
    this.color,
  );
}

class _ActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionData(
    this.title,
    this.subtitle,
    this.icon,
    this.onTap,
  );
}
