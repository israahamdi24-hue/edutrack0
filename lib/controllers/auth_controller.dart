import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Coordinates authentication actions used by the app's entry screens.
/// AuthGate remains the source of truth for restoring Firebase sessions.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? service}) : _service = service ?? AuthService();

  final AuthService _service;
  bool _isLoading = false;
  Object? _lastError;

  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  Future<AppUser> signIn({required String email, required String password}) {
    return _run(() => _service.signIn(email: email, password: password));
  }

  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _run(
      () => _service.register(
        displayName: displayName,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _run(() => _service.sendPasswordReset(email));
  }

  Future<void> signOut() => _run(_service.signOut);

  Future<T> _run<T>(Future<T> Function() action) async {
    if (_isLoading) {
      throw StateError('Une action d’authentification est déjà en cours.');
    }
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
