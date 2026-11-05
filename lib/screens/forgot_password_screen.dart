import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/errors/auth_error_message.dart';
import '../core/validators/auth_validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_header.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authController = AuthController();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _authController.sendPasswordReset(_emailController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Si un compte correspond à cette adresse, un lien '
              'de réinitialisation a été envoyé.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.code == 'user-not-found'
                  ? 'Si un compte correspond à cette adresse, un lien '
                        'de réinitialisation a été envoyé.'
                  : authErrorMessage(error),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeader(
                      title: 'Mot de passe oublié ?',
                      subtitle:
                          'Saisissez votre email pour recevoir un lien '
                          'de réinitialisation.',
                    ),
                    const SizedBox(height: 34),
                    AppTextField(
                      controller: _emailController,
                      label: 'Adresse email',
                      hint: 'exemple@universite.tn',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: AuthValidators.email,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _isLoading ? 'Envoi...' : 'Envoyer le lien',
                      icon: Icons.send_rounded,
                      onPressed: _isLoading ? null : _sendResetLink,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Un email de réinitialisation sera envoyé à cette adresse.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF5D78A2),
                      ),
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
