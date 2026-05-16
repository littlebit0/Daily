import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleDriveAccount {
  const GoogleDriveAccount({required this.email, this.displayName});

  final String email;
  final String? displayName;
}

class GoogleDriveAuthService {
  static const driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const scopes = <String>[driveAppDataScope];
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
    defaultValue:
        '424765276744-j32k4bdck7lr4ba0lg5s99u91c4849bp.apps.googleusercontent.com',
  );

  final _accountController = StreamController<GoogleDriveAccount?>.broadcast();
  Future<void>? _initializeFuture;
  GoogleSignInAccount? _currentUser;
  var _isAvailable = true;

  Stream<GoogleDriveAccount?> get accountChanges => _accountController.stream;

  GoogleDriveAccount? get currentAccount => _toDriveAccount(_currentUser);

  bool get isAvailable => _isAvailable;

  Future<void> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<GoogleDriveAccount?> signIn() async {
    await initialize();
    if (!_isAvailable) {
      throw UnsupportedError('현재 플랫폼에서는 Google Drive 동기화를 아직 지원하지 않습니다.');
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError('현재 플랫폼에서는 Google 로그인을 아직 지원하지 않습니다.');
    }

    final existing = _currentUser;
    if (existing != null) {
      await existing.authorizationClient.authorizeScopes(scopes);
      return _toDriveAccount(existing);
    }

    final user = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    await user.authorizationClient.authorizeScopes(scopes);
    _setCurrentUser(user);
    return _toDriveAccount(user);
  }

  Future<void> signOut() async {
    await initialize();
    if (!_isAvailable) {
      _setCurrentUser(null);
      return;
    }
    await GoogleSignIn.instance.signOut();
    _setCurrentUser(null);
  }

  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    await initialize();
    if (!_isAvailable) {
      return null;
    }
    var user = _currentUser;
    if (user == null) {
      try {
        final attempt = GoogleSignIn.instance
            .attemptLightweightAuthentication();
        if (attempt != null) {
          user = await attempt;
          _setCurrentUser(user);
        }
      } on Object {
        _setCurrentUser(null);
      }
    }
    return user?.authorizationClient.authorizationHeaders(
      scopes,
      promptIfNecessary: promptIfNecessary,
    );
  }

  Future<void> _initialize() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );
    } on MissingPluginException {
      _isAvailable = false;
      _setCurrentUser(null);
      return;
    } on UnimplementedError {
      _isAvailable = false;
      _setCurrentUser(null);
      return;
    }

    GoogleSignIn.instance.authenticationEvents.listen((event) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn(:final user):
          _setCurrentUser(user);
        case GoogleSignInAuthenticationEventSignOut():
          _setCurrentUser(null);
      }
    }, onError: (_) => _setCurrentUser(null));

    try {
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (attempt != null) {
        final user = await attempt;
        _setCurrentUser(user);
      }
    } on Object {
      _setCurrentUser(null);
    }
  }

  void _setCurrentUser(GoogleSignInAccount? user) {
    _currentUser = user;
    _accountController.add(_toDriveAccount(user));
  }

  GoogleDriveAccount? _toDriveAccount(GoogleSignInAccount? user) {
    if (user == null) {
      return null;
    }
    return GoogleDriveAccount(email: user.email, displayName: user.displayName);
  }
}
