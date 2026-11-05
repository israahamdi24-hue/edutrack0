import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseInitializationError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    firebaseInitializationError = error.message ?? error.code;
  } on UnsupportedError catch (error) {
    firebaseInitializationError = error.toString();
  }

  runApp(EduTrackApp(firebaseInitializationError: firebaseInitializationError));
}

class EduTrackApp extends StatelessWidget {
  const EduTrackApp({super.key, this.firebaseInitializationError});

  final String? firebaseInitializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: firebaseInitializationError == null
          ? const AuthGate()
          : FirebaseSetupScreen(error: firebaseInitializationError!),
    );
  }
}
