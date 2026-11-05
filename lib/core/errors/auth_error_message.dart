import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Adresse email ou mot de passe incorrect.',
    'email-already-in-use' => 'Cette adresse email est déjà utilisée.',
    'invalid-email' => 'Cette adresse email n’est pas valide.',
    'weak-password' => 'Choisissez un mot de passe plus sécurisé.',
    'network-request-failed' =>
      'Connexion réseau impossible. Vérifiez votre connexion.',
    'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
    'user-disabled' => 'Ce compte est désactivé. Contactez l’administration de votre établissement.',
    _ => 'L’opération a échoué (${error.code}).',
  };
}
