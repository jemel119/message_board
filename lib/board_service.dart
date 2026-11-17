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
