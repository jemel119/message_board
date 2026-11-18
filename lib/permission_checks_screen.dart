import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class PermissionChecksScreen extends StatefulWidget {
  const PermissionChecksScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<PermissionChecksScreen> createState() => _PermissionChecksScreenState();
}

class _PermissionChecksScreenState extends State<PermissionChecksScreen> {
  final _messageId = TextEditingController();

  bool _running = false;
  bool _confirmedDisposable = false;
  String? _result;

  @override
  void dispose() {
    _messageId.dispose();
    super.dispose();
  }

  Future<void> _run({required bool signedOutRead, bool delete = false}) async {
    if (_running) return;

    final initiatingUid = widget.auth.currentUser?.uid;

    if (signedOutRead && initiatingUid != null) {
      setState(() {
        _result = 'NOT RUN — Sign out before checking a signed-out read.';
      });
      return;
    }

    if (!signedOutRead && (initiatingUid == null || !_confirmedDisposable)) {
      setState(() {
        _result =
            'NOT RUN — Sign in and confirm that the target '
            'is a disposable test message.';
      });
      return;
    }

    setState(() {
      _running = true;
      _result = null;
    });

    try {
      final result = signedOutRead
          ? await widget.auth.board.checkSignedOutRead()
          : await widget.auth.board.checkCrossUserWrite(
              messageId: _messageId.text,
              currentUid: initiatingUid!,
              delete: delete,
            );

      if (!mounted) return;

      setState(() {
        _result = widget.auth.currentUser?.uid == initiatingUid
            ? result
            : 'INCONCLUSIVE — Authentication changed during the check. '
                  'The previous account’s result was discarded. '
                  'Check the test message before repeating.';
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        _result =
            'INCONCLUSIVE — Firestore returned ${error.code}. '
            'The requested denial check was not completed.';
      });
    } on ArgumentError catch (error) {
      if (!mounted) return;

      setState(() {
        _result = 'NOT RUN — ${error.message}';
      });
    } on StateError catch (error) {
      if (!mounted) return;

      setState(() {
        _result = 'NOT RUN — ${error.message}';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _result =
            'INCONCLUSIVE — The check could not finish. '
            'Check the connection and test message before retrying.';
      });
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.auth.currentUser != null;

    return PopScope(
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Permission checks'),
          automaticallyImplyLeading: !_running,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Assignment evidence checks',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'These buttons send real requests to Firestore using '
                'the current authentication session. '
                'They do not change the security rules.',
              ),
              const SizedBox(height: 12),
              Text(
                signedIn
                    ? 'Current session: signed in.'
                    : 'Current session: signed out.',
              ),
              const SizedBox(height: 24),
              Text(
                'Signed-out read',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'While signed out, request the board from the server. '
                'Expected result: permission-denied.',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _running || signedIn
                    ? null
                    : () => _run(signedOutRead: true),
                child: const Text('Attempt signed-out server read'),
              ),
              const SizedBox(height: 24),
              Text(
                'Cross-user writes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a disposable message as test user A. '
                'Begin its text with PERMISSION TEST: and copy its '
                'document ID from Firestore.\n\n'
                'Sign in as test user B, enter that ID below, '
                'then attempt update and delete separately.\n\n'
                'If the rules are incorrect, these operations could '
                'change or delete the target. Use fictional test '
                'content only, and keep other clients from editing '
                'the target during these checks.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageId,
                enabled: !_running && signedIn,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Test message document ID',
                  helperText: 'ID only; omit messages/ from the path.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmedDisposable,
                onChanged: _running || !signedIn
                    ? null
                    : (value) {
                        setState(() {
                          _confirmedDisposable = value ?? false;
                        });
                      },
                title: const Text(
                  'This is another test user’s disposable '
                  'PERMISSION TEST: message.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              OutlinedButton(
                onPressed: _running || !signedIn || !_confirmedDisposable
                    ? null
                    : () => _run(signedOutRead: false),
                child: const Text('Attempt another user’s update'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _running || !signedIn || !_confirmedDisposable
                    ? null
                    : () => _run(signedOutRead: false, delete: true),
                child: const Text('Attempt another user’s delete'),
              ),
              if (_running) ...[
                const SizedBox(height: 24),
                const LinearProgressIndicator(
                  semanticsLabel: 'Waiting for Firestore permission check',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Waiting for Firestore. Keep this screen open '
                  'until the request settles.',
                ),
              ],
              if (_result case final result?) ...[
                const SizedBox(height: 24),
                Semantics(liveRegion: true, child: SelectableText(result)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
