import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseAppService {
  FirebaseAppService();

  Object? _lastError;

  Object? get lastError => _lastError;

  bool get isInitialized => Firebase.apps.isNotEmpty;

  Future<bool> initialize() async {
    if (isInitialized) {
      return true;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _lastError = null;
      return true;
    } on Object catch (error) {
      _lastError = error;
    }

    try {
      await Firebase.initializeApp();
      _lastError = null;
      return true;
    } on Object catch (error) {
      _lastError = error;
      return false;
    }
  }
}
