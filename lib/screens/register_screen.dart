import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_colors.dart';
import '../core/errors/auth_error_message.dart';
import '../core/validators/auth_validators.dart';
import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_header.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authController = AuthController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authController.addListener(_syncAuthState);
  }

  void _syncAuthState() {
    if (mounted && _isLoading != _authController.isLoading) {
      setState(() => _isLoading = _authController.isLoading);
    }
  }

  @override
  void dispose() {
    _authController.removeListener(_syncAuthState);
    _authController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLoading) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les conditions d’utilisation.'),
        ),
      );
      return;
    }

    try {
      await _authController.register(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (error) {
      _showError(authErrorMessage(error));
    } on FirebaseException catch (error) {
      _showError('Impossible de créer le profil Firestore (${error.code}).');
    } on StateError catch (error) {
      _showError(error.toString());
    } on UserProfileNotFoundException catch (error) {
      _showError(error.toString());
    } on UnauthorizedAccountException catch (error) {
      _showError(error.message);
    } on FormatException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25, 4, 25, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeader(
                      title: 'Créer un compte',
                      subtitle:
                          'Rejoignez EduTrack et simplifiez votre quotidien.',
                    ),
                    const SizedBox(height: 26),
                    AppTextField(
                      controller: _nameController,
                      label: 'Nom complet',
                      hint: 'Votre nom et prénom',
                      icon: Icons.person_outline_rounded,
                      validator: (value) =>
                          AuthValidators.requiredText(value, label: 'Le nom'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emailController,
                      label: 'Adresse email',
                      hint: 'exemple@universite.tn',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: AuthValidators.email,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Mot de passe',
                      hint: '8 caractères minimum',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _hidePassword,
                      validator: AuthValidators.password,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirmController,
                      label: 'Confirmer le mot de passe',
                      hint: 'Répétez votre mot de passe',
                      icon: Icons.lock_reset_rounded,
                      obscureText: _hideConfirm,
                      validator: (value) => AuthValidators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hideConfirm = !_hideConfirm;
                          });
                        },
                        icon: Icon(
                          _hideConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _acceptedTerms,
                      activeColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() {
                          _acceptedTerms = value ?? false;
                        });
                      },
                      title: const Text(
                        'J’accepte les conditions d’utilisation et '
                        'la politique de confidentialité.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: _isLoading
                          ? 'Création du compte...'
                          : 'Créer mon compte',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _isLoading ? null : _register,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(
                          child: Text('Vous avez déjà un compte ?'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text('Se connecter'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
