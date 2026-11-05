enum AppRole {
  student,
  teacher,
  admin;

  String get label => switch (this) {
    AppRole.student => 'Étudiant',
    AppRole.teacher => 'Enseignant',
    AppRole.admin => 'Administrateur',
  };

  static AppRole fromValue(Object? value) {
    return switch (value) {
      'student' => AppRole.student,
      'teacher' => AppRole.teacher,
      'admin' => AppRole.admin,
      _ => throw FormatException('Rôle utilisateur invalide : $value'),
    };
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.className,
  });

  final String uid;
  final String email;
  final String displayName;
  final AppRole role;
  final String? className;
}
