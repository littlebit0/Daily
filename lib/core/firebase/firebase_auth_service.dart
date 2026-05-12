import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_app_service.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._firebaseAppService);

  final FirebaseAppService _firebaseAppService;

  User? get currentUser {
    if (!_firebaseAppService.isInitialized) {
      return null;
    }
    return FirebaseAuth.instance.currentUser;
  }

  Stream<User?> authStateChanges() async* {
    final initialized = await _firebaseAppService.initialize();
    if (!initialized) {
      yield null;
      return;
    }
    yield* FirebaseAuth.instance.authStateChanges();
  }

  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    final initialized = await _firebaseAppService.initialize();
    if (!initialized) {
      return null;
    }
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> createAccount({
    required String email,
    required String password,
  }) async {
    final initialized = await _firebaseAppService.initialize();
    if (!initialized) {
      return null;
    }
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (!_firebaseAppService.isInitialized) {
      return;
    }
    await FirebaseAuth.instance.signOut();
  }
}
