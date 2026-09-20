import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/services/google_auth_service.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleAuthService.instance.initialize();

  runApp(const SuperTgAttendanceApp());
}
