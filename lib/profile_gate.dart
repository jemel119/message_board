import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'board_screen.dart';
import 'board_service.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.auth,
    required this.board,
    required this.user,
  });

  final AuthService auth;
  final BoardService board;
  final User user;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  late Future<bool> _profileCheck;
  bool _saving = false;
  bool _signingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profileCheck = widget.auth.hasUserRecord(widget.user.uid);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _retryCheck() {
    setState(() {
      _error = null;
      _profileCheck = widget.auth.hasUserRecord(widget.user.uid);
    });
  }

  Future<void> _saveProfile() async {
    if (_saving || _signingOut || !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.auth.completeProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
      );

      if (mounted) _retryCheck();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Your account is signed in, but the profile could not be '
              'confirmed. Check your connection and try saving again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    if (_saving || _signingOut) return;

    setState(() {
      _signingOut = true;
      _error = null;
    });

    try {
      await widget.auth.signOut();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your name.';
    if (name.length > 80) return 'Use at most 80 characters.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _profileCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasError && snapshot.data == true) {
          return BoardScreen(
            key: ValueKey(widget.user.uid),
            auth: widget.auth,
            board: widget.board,
            uid: widget.user.uid,
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Complete registration')),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (snapshot.hasError) ...[
                    const Text(
                      'Could not check your profile. Check your connection '
                      'and try again.',
                    ),
                    OutlinedButton(
                      onPressed: _retryCheck,
                      child: const Text('Retry profile check'),
                    ),
                  ] else ...[
                    const Text('Add your name to finish registration.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstName,
                      enabled: !_saving && !_signingOut,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastName,
                      enabled: !_saving && !_signingOut,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: _validateName,
                      onFieldSubmitted: (_) => _saveProfile(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving || _signingOut ? null : _saveProfile,
                      child: Text(
                        _saving ? 'Saving profile…' : 'Finish registration',
                      ),
                    ),
                  ],
                  if (_error case final message?)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
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
                  OutlinedButton(
                    onPressed: _saving || _signingOut ? null : _signOut,
                    child: Text(_signingOut ? 'Signing out…' : 'Sign out'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
