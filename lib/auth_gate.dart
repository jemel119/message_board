import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Could not check your sign-in.')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return LoginScreen(auth: auth);

        return SignedInScreen(key: ValueKey(user.uid), auth: auth, user: user);
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.auth.signIn(email: _email.text, password: _password.text);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = switch (error.code) {
          'network-request-failed' =>
            'Could not connect. Check your connection and try again.',
          'too-many-requests' => 'Too many attempts. Wait before trying again.',
          'invalid-email' => 'Enter a valid email address.',
          'invalid-credential' || 'wrong-password' || 'user-not-found' =>
            'Unable to sign in. Check your email and password.',
          _ => 'Sign-in is unavailable. Please try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Sign-in is unavailable. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Message Board Vault',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                      ? null
                      : 'Enter a valid email address.';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_submitting,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null,
                onFieldSubmitted: (_) => _signIn(),
              ),
              if (_error case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _signIn,
                child: Text(_submitting ? 'Signing in…' : 'Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignedInScreen extends StatefulWidget {
  const SignedInScreen({super.key, required this.auth, required this.user});

  final AuthService auth;
  final User user;

  @override
  State<SignedInScreen> createState() => _SignedInScreenState();
}

class _SignedInScreenState extends State<SignedInScreen> {
  bool _signingOut = false;
  String? _error;

  Future<void> _signOut() async {
    if (_signingOut) return;

    setState(() {
      _signingOut = true;
      _error = null;
    });

    try {
      await widget.auth.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not sign out. Please try again.');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Board Vault')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Signed in as ${widget.user.email ?? 'a board member'}'),
            const SizedBox(height: 12),
            const Text('Your message board will appear here.'),
            if (_error case final message?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(message),
              ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _signingOut ? null : _signOut,
              child: Text(_signingOut ? 'Signing out…' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
