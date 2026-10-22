
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/auth_header.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -95,
            right: -100,
            child: _BackgroundCircle(size: 250),
          ),
          const Positioned(
            bottom: -115,
            left: -105,
            child: _BackgroundCircle(size: 275),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 36,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AuthHeader(
                          title: '',
                          subtitle: '',
                        ),
                        const SizedBox(height: 8),
                        _WelcomeIllustration(),
                        const SizedBox(height: 28),
                        const Text(
                          'Gérez vos cours et vos présences simplement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 24,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'EduTrack vous aide à organiser vos cours, '
                          'suivre vos présences et rester connecté '
                          'à votre parcours universitaire.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 15,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 30),
                        PrimaryButton(
                          label: 'Commencer',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text('Créer un compte'),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PageDot(active: true),
                            _PageDot(active: false),
                            _PageDot(active: false),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 255,
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(90),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: 35,
            bottom: 25,
            child: Icon(
              Icons.menu_book_rounded,
              size: 115,
              color: Color(0xFF1675F8),
            ),
          ),
          const Positioned(
            left: 68,
            top: 22,
            child: Icon(
              Icons.school_rounded,
              size: 88,
              color: AppColors.primaryDark,
            ),
          ),
          Positioned(
            right: 22,
            bottom: 28,
            child: Container(
              width: 67,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFFB8D5FF),
                  width: 2,
                ),
              ),
              child: const Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                    child: SizedBox(
                      width: 63,
                      height: 18,
                    ),
                  ),
                  SizedBox(height: 7),
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 31,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundCircle extends StatelessWidget {
  const _BackgroundCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFFDCEAFF),
            Color(0xFFEFF5FF),
          ],
        ),
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 12 : 9,
      height: active ? 12 : 9,
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary
            : const Color(0xFFBDD4FA),
        shape: BoxShape.circle,
      ),
    );
  }
}
