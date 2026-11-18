import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'board_service.dart';

class AuthService {
  AuthService(FirebaseAuth auth)
    : _auth = auth,
      board = BoardService(FirebaseFirestore.instance),
      authStateChanges = auth.authStateChanges();

  final FirebaseAuth _auth;
  final BoardService board;
  final Stream<User?> authStateChanges;

  User? get currentUser => _auth.currentUser;

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<bool> hasUserRecord(String uid) {
    return board.hasUserRecord(uid);
  }

  Future<void> completeProfile({
    required String firstName,
    required String lastName,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Sign in before completing your profile.');
    }

    await board.saveUserRecord(
      uid: user.uid,
      firstName: firstName,
      lastName: lastName,
    );
  }
}
