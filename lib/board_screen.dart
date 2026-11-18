import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'board_message.dart';
import 'board_service.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.auth,
    required this.board,
    required this.uid,
  });

  final AuthService auth;
  final BoardService board;
  final String uid;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _text = TextEditingController();

  late final Stream<List<BoardMessage>> _messages;
  late final Future<String> _authorName;

  MessageDraft? _draft;
  bool _posting = false;
  bool _signingOut = false;
  String? _busyMessageId;
  String? _error;

  bool get _busy => _posting || _signingOut || _busyMessageId != null;

  bool get _currentUser =>
      mounted && widget.auth.currentUser?.uid == widget.uid;

  @override
  void initState() {
    super.initState();
    _messages = widget.board.messageBoard();
    _authorName = widget.board.authorName(widget.uid);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firestore denied this action. Check your account and permissions.',
        'unauthenticated' => 'Sign in again to continue.',
        'unavailable' =>
          'Firestore is unavailable. Check your connection and retry.',
        'resource-exhausted' =>
          'Firestore reported a usage limit. Wait before retrying.',
        _ => 'The action could not be confirmed. Please retry.',
      };
    }
    if (error is MessageCollision) {
      return 'This message ID contains different data. '
          'The existing message was preserved.';
    }
    if (error is ArgumentError) {
      return error.message.toString();
    }
    return 'The action could not be confirmed. Please retry.';
  }

  Future<void> _post() async {
    if (_busy || !_currentUser) return;

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      if (_draft == null) {
        final name = await _authorName;
        if (!_currentUser) return;

        _draft = widget.board.newDraft(
          authorUid: widget.uid,
          authorName: name,
          text: _text.text,
        );
      }

      await widget.board.postMessage(_draft!);
      if (!_currentUser) return;

      setState(() {
        _draft = null;
        _text.clear();
      });
    } catch (error) {
      if (!_currentUser) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (_currentUser) setState(() => _posting = false);
    }
  }

  Future<void> _edit(BoardMessage message) async {
    if (_busy || !_currentUser || message.authorUid != widget.uid) return;

    final controller = TextEditingController(text: message.text);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Message'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a message.'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, controller.text);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    // Wait for the dialog route to finish before disposing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();

    if (updated == null || !_currentUser || _busy) return;

    setState(() {
      _busyMessageId = message.id;
      _error = null;
    });

    try {
      await widget.board.editMessage(messageId: message.id, text: updated);
    } catch (error) {
      if (_currentUser) {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      if (_currentUser) setState(() => _busyMessageId = null);
    }
  }

  Future<void> _delete(BoardMessage message) async {
    if (_busy || !_currentUser || message.authorUid != widget.uid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This removes the message from the board.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !_currentUser || _busy) return;

    setState(() {
      _busyMessageId = message.id;
      _error = null;
    });

    try {
      await widget.board.deleteMessage(message.id);
    } catch (error) {
      if (_currentUser) {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      if (_currentUser) setState(() => _busyMessageId = null);
    }
  }

  Future<void> _signOut() async {
    if (_busy || _draft != null) return;

    setState(() {
      _signingOut = true;
      _error = null;
    });

    try {
      await widget.auth.signOut();
    } catch (error) {
      if (_currentUser) {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      if (_currentUser) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board Vault'),
        actions: [
          TextButton(
            onPressed: _busy || _draft != null ? null : _signOut,
            child: Text(_signingOut ? 'Signing out…' : 'Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _text,
                    enabled: !_busy && _draft == null,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Write a message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _post,
                    child: Text(
                      _posting
                          ? 'Posting…'
                          : _draft == null
                          ? 'Post message'
                          : 'Retry same message',
                    ),
                  ),
                  if (_draft != null && !_posting)
                    const Text(
                      'This draft is retained until posting is confirmed. '
                      'Retry uses the same message ID.',
                    ),
                  if (_error case final message?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<BoardMessage>>(
                stream: _messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Could not display the board. Check your '
                          'connection, permissions, and message format.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.requireData;
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('No messages yet. Start the conversation.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final ownMessage = message.authorUid == widget.uid;
                      final timestamp = message.createdAt;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.authorName,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(message.text),
                              const SizedBox(height: 8),
                              Text(
                                timestamp == null
                                    ? 'Awaiting server timestamp…'
                                    : timestamp.toLocal().toString(),
                              ),
                              if (message.editedAt != null)
                                const Text('Edited'),
                              if (ownMessage)
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _edit(message),
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _delete(message),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              if (_busyMessageId == message.id)
                                const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
