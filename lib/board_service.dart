import 'package:cloud_firestore/cloud_firestore.dart';

import 'board_message.dart';

class BoardService {
  BoardService(FirebaseFirestore firestore) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<void> saveUserRecord({
    required String uid,
    required String firstName,
    required String lastName,
  }) async {
    final first = firstName.trim();
    final last = lastName.trim();

    if (first.isEmpty || last.isEmpty) {
      throw ArgumentError('First and last name are required.');
    }

    if (first.length > 80 || last.length > 80) {
      throw ArgumentError('Names must contain at most 80 characters.');
    }

    final ref = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(ref);

      if (existing.exists) return;

      transaction.set(ref, {
        'uid': uid,
        'firstName': first,
        'lastName': last,
        'role': 'member',
        'registrationDateTime': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> hasUserRecord(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    return snapshot.exists;
  }

  Future<String> authorName(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    final data = snapshot.data();
    final first = data?['firstName'];
    final last = data?['lastName'];

    if (first is! String || last is! String) {
      throw const FormatException('Your profile is incomplete.');
    }

    return '$first $last';
  }

  MessageDraft newDraft({
    required String authorUid,
    required String authorName,
    required String text,
  }) {
    final messageText = _validateText(text);

    if (authorUid.isEmpty || authorName.trim().isEmpty) {
      throw ArgumentError('A message requires an author.');
    }

    return MessageDraft(
      id: _firestore.collection('messages').doc().id,
      text: messageText,
      authorUid: authorUid,
      authorName: authorName.trim(),
    );
  }

  Future<void> postMessage(MessageDraft draft) async {
    final ref = _firestore.collection('messages').doc(draft.id);
    final text = _validateText(draft.text);

    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(ref);

      if (existing.exists) {
        final data = existing.data();

        if (data == null ||
            data['authorUid'] != draft.authorUid ||
            data['authorName'] != draft.authorName ||
            data['text'] != text ||
            data['schemaVersion'] != 2) {
          throw const MessageCollision();
        }

        return;
      }

      transaction.set(ref, {
        'schemaVersion': 2,
        'text': text,
        'authorUid': draft.authorUid,
        'authorName': draft.authorName,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
      });
    });
  }

  Stream<List<BoardMessage>> messageBoard() {
    return _firestore
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_readMessage).toList(growable: false),
        );
  }

  Future<void> editMessage({
    required String messageId,
    required String text,
  }) async {
    await _firestore.collection('messages').doc(messageId).update({
      'text': _validateText(text),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await _firestore.collection('messages').doc(messageId).delete();
  }

  // Evidence check: call only while the app is signed out.
  // Source.server prevents a cached result from satisfying this check.
  Future<String> checkSignedOutRead() async {
    try {
      await _firestore
          .collection('messages')
          .limit(1)
          .get(const GetOptions(source: Source.server));

      return 'FAIL — The signed-out server read succeeded. '
          'Check the deployed Firestore rules.';
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return 'PASS — Firestore returned permission-denied '
            'for the signed-out server read.';
      }

      return 'INCONCLUSIVE — Firestore returned ${error.code}. '
          'Expected permission-denied. Check the connection and retry.';
    }
  }

  // This deliberately attempts another author's write.
  // Only disposable, clearly labeled test messages are accepted.
  //
  // A transaction avoids queuing an ordinary offline update/delete.
  // No UI updates or ID generation belong in its callback.
  Future<String> checkCrossUserWrite({
    required String messageId,
    required String currentUid,
    required bool delete,
  }) async {
    final id = messageId.trim();

    if (id.isEmpty || id.contains('/')) {
      throw ArgumentError('Enter a message document ID, without a path.');
    }

    if (currentUid.isEmpty) {
      throw ArgumentError('Sign in as the second test user first.');
    }

    final ref = _firestore.collection('messages').doc(id);
    final operation = delete ? 'delete' : 'update';

    // Establish that the target exists before attempting the write.
    // A missing document must not count as an ownership denial.
    final before = await ref.get(const GetOptions(source: Source.server));
    final original = before.data();

    if (!before.exists || original == null) {
      return 'NOT RUN — messages/$id does not exist on the server.';
    }

    final authorUid = original['authorUid'];
    final text = original['text'];

    if (authorUid is! String || authorUid.isEmpty) {
      return 'NOT RUN — The target has no valid authorUid.';
    }

    if (authorUid == currentUid) {
      return 'NOT RUN — This is your own message. '
          'Sign in as a different test user.';
    }

    if (original['schemaVersion'] != 2 ||
        text is! String ||
        !text.startsWith('PERMISSION TEST:')) {
      return 'NOT RUN — Use a disposable version-2 message whose text '
          'begins with PERMISSION TEST:.';
    }

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final latest = await transaction.get(ref);
        final latestData = latest.data();

        if (!latest.exists ||
            latestData == null ||
            !_sameMessageData(original, latestData)) {
          throw StateError(
            'The test message changed before the write. '
            'Check it and start again.',
          );
        }

        if (delete) {
          transaction.delete(ref);
        } else {
          transaction.update(ref, {
            'text': 'PERMISSION TEST: unauthorized update was accepted.',
            'editedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      return 'FAIL — Firestore accepted another user’s $operation.\n'
          'Path: messages/$id\n'
          'The disposable test message may have changed or been deleted. '
          'Correct the rules before continuing.';
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        return 'INCONCLUSIVE — $operation returned ${error.code}.\n'
            'Path: messages/$id\n'
            'Expected permission-denied. No pass is recorded.';
      }

      // A denial alone does not establish that the original stayed intact.
      // Verify its complete stored data with a separate server read.
      try {
        final after = await ref.get(const GetOptions(source: Source.server));
        final afterData = after.data();

        if (!after.exists ||
            afterData == null ||
            !_sameMessageData(original, afterData)) {
          return 'INCONCLUSIVE — Firestore returned permission-denied '
              'for $operation, but the follow-up server read found the '
              'message missing or changed.\n'
              'Path: messages/$id\n'
              'Check for another client modifying the fixture.';
        }

        return 'PASS — Firestore returned permission-denied '
            'for another user’s $operation.\n'
            'Path: messages/$id\n'
            'Follow-up server read: original message unchanged.';
      } on FirebaseException catch (verificationError) {
        return 'INCONCLUSIVE — Firestore returned permission-denied '
            'for $operation, but preservation could not be verified.\n'
            'Path: messages/$id\n'
            'Verification error: ${verificationError.code}.';
      }
    }
  }

  // The supported message schema contains scalar values and timestamps.
  bool _sameMessageData(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    if (first.length != second.length) return false;

    for (final entry in first.entries) {
      if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }

  BoardMessage _readMessage(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final text = data['text'];
    final uid = data['authorUid'];
    final name = data['authorName'];
    final createdAt = data['createdAt'];
    final editedAt = data['editedAt'];

    if (data['schemaVersion'] != 2 ||
        text is! String ||
        text.trim().isEmpty ||
        text.length > 1000 ||
        uid is! String ||
        uid.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        (createdAt != null && createdAt is! Timestamp) ||
        (editedAt != null && editedAt is! Timestamp) ||
        (createdAt == null && !snapshot.metadata.hasPendingWrites)) {
      throw const FormatException(
        'A message has an unsupported or incomplete format.',
      );
    }

    return BoardMessage(
      id: snapshot.id,
      text: text,
      authorUid: uid,
      authorName: name,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      editedAt: editedAt is Timestamp ? editedAt.toDate() : null,
    );
  }

  String _validateText(String text) {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      throw ArgumentError('Enter a message.');
    }

    if (trimmed.length > 1000) {
      throw ArgumentError('Use at most 1,000 characters.');
    }

    return trimmed;
  }
}
