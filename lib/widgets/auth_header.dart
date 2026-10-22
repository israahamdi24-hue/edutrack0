
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showLogo = true,
  });

  final String title;
  final String subtitle;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showLogo) ...[
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1976FF),
                  Color(0xFF0759DF),
                ],
              ),
              borderRadius: BorderRadius.circular(21),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 39,
            ),
          ),
          const SizedBox(height: 15),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(
                  text: 'Edu',
                  style: TextStyle(color: AppColors.primaryDark),
                ),
                TextSpan(
                  text: 'Track',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Smart Learning & Attendance',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 27),
        ],
        if (title.isNotEmpty)
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.secondary,
            ),
          ),
        ],
      ],
    );
  }
}
