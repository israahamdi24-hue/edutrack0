import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../services/student_attendance_qr_service.dart';

class StudentQrAttendanceScreen extends StatefulWidget {
  const StudentQrAttendanceScreen({super.key, this.attendanceService});

  final StudentAttendanceQrService? attendanceService;

  @override
  State<StudentQrAttendanceScreen> createState() =>
      _StudentQrAttendanceScreenState();
}

class _StudentQrAttendanceScreenState extends State<StudentQrAttendanceScreen> {
  late final MobileScannerController _controller;
  bool _isSubmitting = false;
  String? _resultMessage;
  bool _isSuccess = false;

  StudentAttendanceQrService get _attendanceService =>
      widget.attendanceService ?? CallableStudentAttendanceQrService();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isSubmitting) return;
    final payload = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (payload == null || payload.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
    });
    try {
      await _controller.stop();
      final message = await _attendanceService.recordPresence(payload);
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _resultMessage = message;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _resultMessage = switch (error.code) {
          'not-found' =>
            'Le service de validation des présences n’est pas encore déployé.',
          'invalid-argument' => 'Ce QR code est invalide ou n’est pas reconnu.',
          'permission-denied' =>
            'Vous n’êtes pas autorisé à pointer cette séance.',
          'already-exists' =>
            'Votre présence à cette séance a déjà été enregistrée.',
          'deadline-exceeded' =>
            'Le délai de pointage de 15 minutes est dépassé.',
          'unauthenticated' =>
            'Reconnectez-vous pour enregistrer votre présence.',
          _ => 'La validation serveur a échoué (${error.code}).',
        };
      });
    } on StudentAttendanceValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _resultMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _resultMessage = 'La validation n’a pas abouti. Vérifiez la connexion puis réessayez.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _isSubmitting = false;
      _resultMessage = null;
    });
    try {
      await _controller.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _resultMessage =
              'La caméra ne peut pas redémarrer. Vérifiez son autorisation.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraSupported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Scanner une séance')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Scannez le QR code affiché par votre enseignant.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: cameraSupported
                          ? MobileScanner(
                              controller: _controller,
                              onDetect: _onDetect,
                              errorBuilder: (context, error) {
                                return _ScannerMessage(
                                  icon: Icons.camera_alt_outlined,
                                  message:
                                      'La caméra est indisponible. '
                                      'Autorisez son accès dans le navigateur '
                                      'ou sur l’appareil.',
                                );
                              },
                            )
                          : const _ScannerMessage(
                              icon: Icons.devices_other_outlined,
                              message:
                                  'Le scan caméra n’est pas disponible sur '
                              'cette plateforme. Utilisez Chrome, Android, '
                              'iOS ou macOS.',
                            ),
                    ),
                  ),
                  if (_isSubmitting) ...[
                    const SizedBox(height: 18),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    const Text('Validation sécurisée par le serveur...'),
                  ],
                  if (_resultMessage case final message?) ...[
                    const SizedBox(height: 16),
                    _ResultBanner(message: message, isSuccess: _isSuccess),
                    const SizedBox(height: 10),
                    if (!_isSuccess && cameraSupported)
                      OutlinedButton.icon(
                        onPressed: _scanAgain,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Scanner à nouveau'),
                      ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'La lecture du QR seule ne valide pas la présence. '
                    'Le serveur vérifie le compte, l’inscription, la séance '
                    'et le délai autorisé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                      height: 1.5,
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

class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.paleBlue,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: AppColors.primary),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
