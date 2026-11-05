import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'home_router.dart';
import 'welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _profileUid;
  Future<AppUser>? _profileFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return _AuthErrorScreen(message: authSnapshot.error.toString());
        }
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          _profileUid = null;
          _profileFuture = null;
          return const WelcomeScreen();
        }

        if (_profileUid != firebaseUser.uid || _profileFuture == null) {
          _profileUid = firebaseUser.uid;
          _profileFuture = AuthService().loadProfile(firebaseUser.uid);
        }

        return FutureBuilder<AppUser>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return _AuthErrorScreen(
                message: _profileErrorMessage(profileSnapshot.error!),
                canSignOut: true,
              );
            }
            if (!profileSnapshot.hasData) return const _LoadingScreen();
            return HomeRouter(user: profileSnapshot.data!);
          },
        );
      },
    );
  }

  String _profileErrorMessage(Object error) {
    if (error is UserProfileNotFoundException) {
      return 'Ce compte ne possède pas de profil EduTrack autorisé.';
    }
    if (error is UnauthorizedAccountException) return error.message;
    if (error is FormatException) {
      return 'Le profil EduTrack est incomplet ou contient un rôle invalide.';
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firebase a refusé l’accès au profil. Vérifiez les autorisations du compte.';
    }
    if (error is FirebaseAuthException && error.code == 'user-disabled') {
      return 'Ce compte est désactivé. Contactez l’administration.';
    }
    return 'Impossible de vérifier le compte. Vérifiez votre connexion puis réessayez.';
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.primary,
                    size: 58,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'EduTrack',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'La configuration Firebase est nécessaire pour '
                    'utiliser la connexion et gérer les comptes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondary, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  const SelectableText(
                    'Dans le terminal du projet :\n'
                    'dart pub global activate flutterfire_cli\n'
                    'flutterfire configure',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontFamily: 'monospace',
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
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

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.message, this.canSignOut = false});

  final String message;
  final bool canSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compte indisponible')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Impossible de charger le profil utilisateur.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.secondary),
              ),
              if (canSignOut) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Se déconnecter'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
