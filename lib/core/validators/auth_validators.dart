
class AuthValidators {
  AuthValidators._();

  static String? requiredText(
    String? value, {
    String label = 'Ce champ',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label est obligatoire.';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L’adresse email est obligatoire.';
    }

    final valid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value.trim());

    return valid ? null : 'Saisissez une adresse email valide.';
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire.';
    }

    if (value.length < 8) {
      return '8 caractères minimum.';
    }

    return null;
  }

  static String? confirmPassword(
    String? value,
    String original,
  ) {
    if (value == null || value.isEmpty) {
      return 'Confirmez votre mot de passe.';
    }

    if (value != original) {
      return 'Les mots de passe ne correspondent pas.';
    }

    return null;
  }
}
