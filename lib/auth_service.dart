import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(FirebaseAuth auth)
    : _auth = auth,
      authStateChanges = auth.authStateChanges();

  final FirebaseAuth _auth;
  final Stream<User?> authStateChanges;

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
