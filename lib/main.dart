import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'auth_service.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MessageBoardApp());
}

class MessageBoardApp extends StatelessWidget {
  const MessageBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Message Board Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8A452B)),
        useMaterial3: true,
      ),
      home: const FirebaseStartup(),
    );
  }
}

class FirebaseStartup extends StatefulWidget {
  const FirebaseStartup({super.key});

  @override
  State<FirebaseStartup> createState() => _FirebaseStartupState();
}

class _FirebaseStartupState extends State<FirebaseStartup> {
  static const _useEmulators =
      kDebugMode && bool.fromEnvironment('USE_FIREBASE_EMULATORS');

  static const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

  static const _localAppName = 'message-board-local';

  late Future<AuthService> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<AuthService> _initialize() async {
    if (_useEmulators && _emulatorHost.trim().isEmpty) {
      throw StateError(
        'Set FIREBASE_EMULATOR_HOST when enabling local emulator mode.',
      );
    }

    final FirebaseApp app;

    if (_useEmulators) {
      final localAppExists = Firebase.apps.any(
        (existing) => existing.name == _localAppName,
      );

      app = localAppExists
          ? Firebase.app(_localAppName)
          : await Firebase.initializeApp(
              name: _localAppName,
              demoProjectId: 'demo-message-board',
            );
    } else {
      final defaultAppExists = Firebase.apps.any(
        (existing) => existing.name == '[DEFAULT]',
      );

      app = defaultAppExists
          ? Firebase.app()
          : await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
    }

    return AuthService.connect(
      app: app,
      useEmulators: _useEmulators,
      emulatorHost: _emulatorHost,
    );
  }

  void _retry() {
    setState(() => _initialization = _initialize());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthService>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const VaultSplash();
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Message Board Vault')),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Could not start Firebase',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _useEmulators
                            ? 'Check the emulator configuration '
                                  'and try again.'
                            : 'Check the Firebase configuration '
                                  'and try again.',
                        textAlign: TextAlign.center,
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 16),
                        SelectableText(
                          'Startup diagnostic:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            if (_useEmulators)
              const Material(
                color: Color(0xFFFFE0B2),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'LOCAL TEST — demo-message-board',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            Expanded(child: AuthGate(auth: snapshot.requireData)),
          ],
        );
      },
    );
  }
}

class VaultSplash extends StatelessWidget {
  const VaultSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF241B18),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.forum_outlined,
                  size: 80,
                  color: Color(0xFFF1BD91),
                ),
                const SizedBox(height: 24),
                Text(
                  'Message Board Vault',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Opening your message board…',
                  style: TextStyle(color: Color(0xFFE4D2C7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                const CircularProgressIndicator(
                  color: Color(0xFFF1BD91),
                  semanticsLabel: 'Initializing Firebase',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
