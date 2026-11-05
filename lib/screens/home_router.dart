import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_colors.dart';
import '../features/student/screens/student_attendance_screen.dart';
import '../features/student/screens/student_courses_screen.dart';
import '../features/student/screens/student_notifications_screen.dart';
import '../features/student/screens/student_profile_screen.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/admin/screens/admin_workspace_screen.dart';
import '../features/teacher/screens/teacher_workspace_screen.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class HomeRouter extends StatefulWidget {
  final AppUser user;

  const HomeRouter({super.key, required this.user});

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  int selectedIndex = 0;
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  AppRole get role => _user.role;

  String get roleName {
    return role.label;
  }

  String get avatarInitial {
    final source = role == AppRole.student
        ? _user.displayName.trim()
        : roleName;
    return source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();
  }

  String get pageTitle {
    if (role == AppRole.student) {
      return [
        'Espace Étudiant',
        'Mes cours',
        'Mes présences',
        'Notifications',
        'Mon profil',
      ][selectedIndex];
    }

    if (role == AppRole.teacher) {
      return [
        'Mon espace',
        'Mes cours',
        'Séances',
        'Présences',
        'Mon profil',
      ][selectedIndex];
    }

    return [
      'Vue générale',
      'Utilisateurs',
      'Cours et séances',
      'Statistiques',
      'Paramètres',
    ][selectedIndex];
  }

  List<NavigationDestination> get destinations {
    if (role == AppRole.student) {
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
          label: 'Notifications',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    }

    if (role == AppRole.teacher) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Cours',
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
            title: role == AppRole.student
                ? Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.paleBlue,
                        child: Icon(
                          Icons.school_rounded,
                          color: AppColors.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Espace Étudiant',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : Row(
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
                  if (role == AppRole.student) {
                    setState(() => selectedIndex = 3);
                  } else {
                    _showMessage(
                      'Les notifications seront bientôt disponibles.',
                    );
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
                    avatarInitial,
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
                            if (!(role == AppRole.student &&
                                selectedIndex == 0)) ...[
                              _buildPageHeader(),
                              const SizedBox(height: 24),
                            ],
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
        border: Border(right: BorderSide(color: AppColors.border)),
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
                    style: TextStyle(color: AppColors.secondary, fontSize: 12),
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
                      selected ? _selectedIcon(index) : _unselectedIcon(index),
                      color: selected ? AppColors.primary : AppColors.secondary,
                    ),
                    title: Text(
                      destination.label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primaryDark,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
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
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
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
    return (destination.selectedIcon as Icon).icon ?? Icons.dashboard;
  }

  IconData _unselectedIcon(int index) {
    final destination = destinations[index];
    return (destination.icon as Icon).icon ?? Icons.dashboard_outlined;
  }

  Widget _buildPageHeader() {
    final subtitle = role == AppRole.student && selectedIndex == 0
        ? 'Suivez vos cours, vos prochaines séances et vos présences.'
        : selectedIndex == 0
        ? 'Bonjour ! Voici un aperçu de votre activité.'
        : 'Retrouvez ici vos informations et vos outils.';
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
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.secondary),
        ),
      ],
    );
  }

  Widget _buildOverview() {
    if (role == AppRole.student) {
      return _buildStudentOverview();
    }

    if (role == AppRole.teacher) {
      return _buildTeacherOverview();
    }

    return _buildAdminOverview();
  }

  Widget _buildStudentOverview() {
    return StudentDashboardScreen(
      user: _user,
      onNavigate: (index) => setState(() => selectedIndex = index),
    );
  }

  Widget _buildTeacherOverview() {
    return TeacherWorkspaceScreen(user: _user, sectionIndex: 0);
  }

  Widget _buildAdminOverview() {
    return const AdminWorkspaceScreen(sectionIndex: 0);
  }

  Widget _buildSelectedPage() {
    if (role == AppRole.student) {
      switch (selectedIndex) {
        case 1:
          return StudentCoursesScreen(user: _user);
        case 2:
          return StudentAttendanceScreen(user: _user);
        case 3:
          return StudentNotificationsScreen(user: _user);
        case 4:
          return StudentProfileScreen(user: _user, onDisplayNameChanged: _updateDisplayName);
        default:
          return _buildProfile();
      }
    }

    if (role == AppRole.teacher) {
      if (selectedIndex == 4) return _buildProfile();
      return TeacherWorkspaceScreen(
        user: _user,
        sectionIndex: selectedIndex,
      );
    }

    switch (selectedIndex) {
      case 1:
        return const AdminWorkspaceScreen(sectionIndex: 1);
      case 2:
        return const AdminWorkspaceScreen(sectionIndex: 2);
      case 3:
        return const AdminWorkspaceScreen(sectionIndex: 3);
      default:
        return _buildProfile();
    }
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
            child: Icon(Icons.person, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 14),
          Text(
            _user.displayName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(_user.email, style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 22),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Rôle'),
            subtitle: Text(roleName),
          ),
          if (role == AppRole.student && _user.className?.isNotEmpty == true)
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Classe'),
              subtitle: Text(_user.className!),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _updateDisplayName(String displayName) {
    setState(() {
      _user = AppUser(
        uid: _user.uid,
        email: _user.email,
        displayName: displayName,
        role: _user.role,
        className: _user.className,
      );
    });
  }

  Future<void> _logout() async {
    try {
      await AuthService().signOut();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showMessage('Impossible de se déconnecter (${error.code}).');
      }
    }
  }
}
