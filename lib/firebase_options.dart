import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured. Run `flutterfire configure` and replace '
      'lib/firebase_options.dart with generated options.',
    );
  }

  static bool get isPlaceholder => kDebugMode;
}
