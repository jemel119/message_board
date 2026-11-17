import 'package:cloud_firestore/cloud_firestore.dart';

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

      if (existing.exists) {
        return;
      }

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
}
