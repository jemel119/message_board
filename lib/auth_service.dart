import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'board_service.dart';

class AuthService {
  AuthService(FirebaseAuth auth, {FirebaseFirestore? firestore})
    : _auth = auth,
      board = BoardService(
        firestore ?? FirebaseFirestore.instanceFor(app: auth.app),
      ),
      authStateChanges = auth.authStateChanges();

  final FirebaseAuth _auth;
  final BoardService board;
  final Stream<User?> authStateChanges;

  User? get currentUser => _auth.currentUser;

  static Future<AuthService> connect({
    required FirebaseApp app,
    required bool useEmulators,
    required String emulatorHost,
  }) async {
    if (useEmulators) {
      if (emulatorHost.trim().isEmpty) {
        throw ArgumentError('An emulator host address is required.');
      }

      if (app.options.projectId != 'demo-message-board') {
        throw StateError('Local emulator mode requires demo-message-board.');
      }
    }

    // Both services must use the exact app initialized at startup.
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);

    if (useEmulators) {
      // Configure caching before connecting Firestore to its emulator.
      firestore.settings = const Settings(persistenceEnabled: false);

      firestore.useFirestoreEmulator(emulatorHost.trim(), 8080);

      await auth.useAuthEmulator(emulatorHost.trim(), 9099);
    }

    return AuthService(auth, firestore: firestore);
  }

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
