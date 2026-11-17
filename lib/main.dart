import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
  late Future<AuthService> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<AuthService> _initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return AuthService(FirebaseAuth.instance);
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
                child: Padding(
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
                      const Text(
                        'Check the Firebase configuration and try again.',
                        textAlign: TextAlign.center,
                      ),
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

        return AuthGate(auth: snapshot.requireData);
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
