import 'package:firebase_core/firebase_core.dart';

/// Firebase is initialized only after FlutterFire generates firebase_options.dart.
/// This project intentionally does not contain invented Firebase credentials.
class FirebaseInitializer {
  FirebaseInitializer._();

  static Future<void> initialize(FirebaseOptions options) async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(options: options);
  }
}
