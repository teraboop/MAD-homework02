import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'auth_service.dart';

/// Pass --dart-define=USE_FIREBASE_EMULATOR=true to `flutter run` to point
/// Auth/Firestore at the local Firebase emulators instead of the live project.
const bool useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

/// The Android emulator can't reach the host machine's `localhost`; it must
/// use the special `10.0.2.2` loopback alias instead. Other platforms (web,
/// iOS simulator, desktop) can use `localhost` directly.
String get firebaseEmulatorHost {
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2';
  return 'localhost';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: SplashScreen()));
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Future<FirebaseApp> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<FirebaseApp> _initialize() async {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (useFirebaseEmulator) {
      await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
    }
    return app;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Firebase could not start. Check your setup.'),
                  ElevatedButton(
                    onPressed: () {
                      setState(() { _initialization = _initialize(); });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const AuthGate();
      },
    );
  }
}