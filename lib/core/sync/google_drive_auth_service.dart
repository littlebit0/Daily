import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleDriveAccount {
  const GoogleDriveAccount({required this.email, this.displayName});

  final String email;
  final String? displayName;
}

class GoogleDriveAuthService {
  GoogleDriveAuthService({
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _httpClient = httpClient ?? http.Client();

  static const driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const scopes = <String>[driveAppDataScope];
  static const _desktopScopes = <String>[
    'openid',
    'email',
    'profile',
    driveAppDataScope,
  ];
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
    defaultValue:
        '424765276744-j32k4bdck7lr4ba0lg5s99u91c4849bp.apps.googleusercontent.com',
  );
  static const _appleClientId = String.fromEnvironment(
    'GOOGLE_APPLE_CLIENT_ID',
  );
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const _macosClientId = String.fromEnvironment(
    'GOOGLE_MACOS_CLIENT_ID',
    defaultValue:
        '424765276744-rjfs830agtj0i0mrrlc1pci4sbh1ifpq.apps.googleusercontent.com',
  );
  static const _macosAuthMode = String.fromEnvironment(
    'GOOGLE_MACOS_AUTH_MODE',
  );
  static const _desktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
    defaultValue:
        '234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com',
  );
  static const _desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
  );
  static const _storagePrefix = 'daily.google_drive.';
  static const _accessTokenKey = '${_storagePrefix}access_token';
  static const _refreshTokenKey = '${_storagePrefix}refresh_token';
  static const _expiresAtKey = '${_storagePrefix}expires_at';
  static const _emailKey = '${_storagePrefix}email';
  static const _displayNameKey = '${_storagePrefix}display_name';
  static const _mobileGoogleSignInTimeout = Duration(seconds: 45);
  static const _mobileAuthorizationTimeout = Duration(seconds: 45);
  static const _mobileLightweightAuthTimeout = Duration(seconds: 8);
  static const _mobileAccountClearTimeout = Duration(seconds: 3);

  final FlutterSecureStorage _secureStorage;
  final http.Client _httpClient;
  final _accountController = StreamController<GoogleDriveAccount?>.broadcast();
  Future<void>? _initializeFuture;
  GoogleSignInAccount? _currentUser;
  GoogleDriveAccount? _desktopAccount;
  _DesktopTokens? _desktopTokens;
  var _isAvailable = true;
  var _usesDesktopOAuth = false;

  Stream<GoogleDriveAccount?> get accountChanges => _accountController.stream;

  GoogleDriveAccount? get currentAccount =>
      _usesDesktopOAuth ? _desktopAccount : _toDriveAccount(_currentUser);

  bool get isAvailable => _isAvailable;

  String get _configuredDesktopClientId {
    final fromBuild = _desktopClientId.trim();
    if (fromBuild.isNotEmpty) {
      return fromBuild;
    }
    return Platform.environment['GOOGLE_DESKTOP_CLIENT_ID']?.trim() ?? '';
  }

  String get _configuredDesktopClientSecret {
    final fromBuild = _desktopClientSecret.trim();
    if (fromBuild.isNotEmpty) {
      return fromBuild;
    }
    return Platform.environment['GOOGLE_DESKTOP_CLIENT_SECRET']?.trim() ?? '';
  }

  String get _configuredAppleClientId {
    final platformSpecific = Platform.isIOS
        ? _iosClientId.trim()
        : Platform.isMacOS
        ? _macosClientId.trim()
        : '';
    if (platformSpecific.isNotEmpty) {
      return platformSpecific;
    }
    final environmentSpecific =
        Platform
            .environment[Platform.isIOS
                ? 'GOOGLE_IOS_CLIENT_ID'
                : 'GOOGLE_MACOS_CLIENT_ID']
            ?.trim() ??
        '';
    if (environmentSpecific.isNotEmpty) {
      return environmentSpecific;
    }
    final shared = _appleClientId.trim();
    if (shared.isNotEmpty) {
      return shared;
    }
    return Platform.environment['GOOGLE_APPLE_CLIENT_ID']?.trim() ?? '';
  }

  bool get _shouldUseMacosDesktopOAuth {
    if (!Platform.isMacOS) {
      return false;
    }
    final mode = _macosAuthMode.trim().toLowerCase();
    final environmentMode =
        Platform.environment['GOOGLE_MACOS_AUTH_MODE']?.trim().toLowerCase() ??
        '';
    if (mode == 'native' || environmentMode == 'native') {
      return false;
    }
    return true;
  }

  Future<void> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<GoogleDriveAccount?> signIn({
    bool forceAccountSelection = false,
  }) async {
    await initialize();
    if (_usesDesktopOAuth) {
      return _signInWithDesktopOAuth();
    }
    if (!_isAvailable) {
      throw UnsupportedError('현재 플랫폼에서는 Google 로그인을 지원하지 않습니다.');
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError('현재 플랫폼에서는 Google 로그인을 지원하지 않습니다.');
    }

    try {
      if (forceAccountSelection && _currentUser != null) {
        await _clearMobileAccountForSelection();
        _setCurrentUser(null);
      }

      final existing = _currentUser;
      if (existing != null) {
        await existing.authorizationClient
            .authorizeScopes(scopes)
            .timeout(_mobileAuthorizationTimeout);
        return _toDriveAccount(existing);
      }

      final user = await GoogleSignIn.instance
          .authenticate(scopeHint: scopes)
          .timeout(_mobileGoogleSignInTimeout);
      await user.authorizationClient
          .authorizeScopes(scopes)
          .timeout(_mobileAuthorizationTimeout);
      _setCurrentUser(user);
      return _toDriveAccount(user);
    } on GoogleSignInException catch (error) {
      _setCurrentUser(null);
      throw GoogleDriveAuthException(_googleSignInMessage(error));
    } on PlatformException catch (error) {
      _setCurrentUser(null);
      throw GoogleDriveAuthException(_platformAuthMessage(error));
    } on TimeoutException {
      _setCurrentUser(null);
      throw const GoogleDriveAuthException(
        'Google 로그인 응답이 없어 중단했습니다. 로그인 창을 닫았다면 다시 로그인 버튼을 눌러 주세요.',
      );
    }
  }

  Future<void> signOut() async {
    await initialize();
    if (_usesDesktopOAuth) {
      await _clearDesktopSession();
      return;
    }
    if (!_isAvailable) {
      _setCurrentUser(null);
      return;
    }
    try {
      await GoogleSignIn.instance.signOut().timeout(_mobileGoogleSignInTimeout);
    } on PlatformException catch (error) {
      if (!_isCredentialClearFailure(error)) {
        rethrow;
      }
    } on TimeoutException {
      // Local account state is still cleared below.
    }
    _setCurrentUser(null);
  }

  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    await initialize();
    if (_usesDesktopOAuth) {
      return _desktopAuthorizationHeaders(promptIfNecessary: promptIfNecessary);
    }
    if (!_isAvailable) {
      return null;
    }
    var user = _currentUser;
    if (user == null) {
      try {
        user = await _attemptLightweightAuthentication();
        _setCurrentUser(user);
      } on Object {
        _setCurrentUser(null);
      }
    }
    try {
      return await user?.authorizationClient
          .authorizationHeaders(scopes, promptIfNecessary: promptIfNecessary)
          .timeout(_mobileAuthorizationTimeout);
    } on PlatformException catch (error) {
      throw GoogleDriveAuthException(_platformAuthMessage(error));
    } on TimeoutException {
      throw const GoogleDriveAuthException(
        'Google 인증 정보를 가져오지 못했습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
      );
    }
  }

  Future<void> _initialize() async {
    if (Platform.isWindows || _shouldUseMacosDesktopOAuth) {
      _usesDesktopOAuth = true;
      if (_configuredDesktopClientId.isEmpty) {
        _isAvailable = false;
        _setDesktopAccount(null);
        return;
      }
      return;
    }

    try {
      final appleClientId = _configuredAppleClientId;
      await GoogleSignIn.instance.initialize(
        clientId: appleClientId.isEmpty ? null : appleClientId,
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

    if (Platform.isMacOS) {
      return;
    }

    try {
      final user = await _attemptLightweightAuthentication();
      _setCurrentUser(user);
    } on Object {
      _setCurrentUser(null);
    }
  }

  Future<GoogleSignInAccount?> _attemptLightweightAuthentication() async {
    final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
    if (attempt == null) {
      return null;
    }
    return attempt.timeout(_mobileLightweightAuthTimeout);
  }

  Future<void> _clearMobileAccountForSelection() async {
    try {
      await GoogleSignIn.instance.signOut().timeout(
        _mobileAccountClearTimeout,
        onTimeout: () {},
      );
    } on PlatformException {
      // The following authenticate call can still present account selection.
    } on TimeoutException {
      // Ignore slow native account cleanup and continue to the sign-in UI.
    }
  }

  String get _appleClientConfigurationMessage {
    if (Platform.isIOS) {
      return 'iOS Google 로그인을 사용하려면 GOOGLE_IOS_CLIENT_ID 빌드 인자와 '
          'iOS reversed client ID URL scheme 설정이 필요합니다. '
          '지금은 로컬 모드로 사용할 수 있습니다.';
    }
    if (Platform.isMacOS) {
      return 'macOS Google 로그인을 사용하려면 GOOGLE_MACOS_CLIENT_ID 빌드 인자와 '
          'macOS reversed client ID URL scheme 설정이 필요합니다. '
          '지금은 로컬 모드로 사용할 수 있습니다.';
    }
    return 'Google 로그인 클라이언트 설정이 필요합니다.';
  }

  String get _macosKeychainConfigurationMessage =>
      'macOS Google 로그인을 사용하려면 keychain sharing entitlement가 필요합니다. '
      '새 빌드에서도 같은 오류가 나면 Apple 개발 팀 서명 설정을 확인해 주세요.';

  Future<GoogleDriveAccount?> _signInWithDesktopOAuth() async {
    if (_configuredDesktopClientId.isEmpty) {
      throw UnsupportedError(
        'Google 로그인 설정이 아직 완료되지 않았습니다. 앱 업데이트 후 다시 시도해 주세요.',
      );
    }

    final codeResponse = await _requestDesktopAuthorizationCode();
    final tokens = await _exchangeAuthorizationCode(codeResponse);
    final account = await _fetchDesktopAccount(tokens.accessToken);
    await _saveDesktopSession(tokens, account);
    _setDesktopAccount(account);
    return account;
  }

  Future<Map<String, String>?> _desktopAuthorizationHeaders({
    required bool promptIfNecessary,
  }) async {
    if (_configuredDesktopClientId.isEmpty) {
      return null;
    }
    await _restoreDesktopSession();

    if (_desktopTokens == null) {
      if (!promptIfNecessary) {
        return null;
      }
      await _signInWithDesktopOAuth();
    } else if (_desktopTokens!.needsRefresh) {
      try {
        await _refreshDesktopAccessToken();
      } on Object {
        if (!promptIfNecessary) {
          return null;
        }
        await _signInWithDesktopOAuth();
      }
    }

    final accessToken = _desktopTokens?.accessToken;
    if (accessToken == null) {
      return null;
    }
    return {'Authorization': 'Bearer $accessToken'};
  }

  Future<_DesktopCodeResponse> _requestDesktopAuthorizationCode() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}/';
    final verifier = _randomUrlSafeString(64);
    final challenge = _pkceChallenge(verifier);
    final state = _randomUrlSafeString(24);
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _configuredDesktopClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _desktopScopes.join(' '),
      'access_type': 'offline',
      'include_granted_scopes': 'true',
      'prompt': 'consent',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    });

    try {
      await _openSystemBrowser(authUri);
      final request = await server.first.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('Google 로그인이 시간 초과되었습니다.'),
      );
      final params = request.uri.queryParameters;
      final requestState = params['state'];
      final code = params['code'];
      final error = params['error'];

      if (error != null) {
        await _writeBrowserResponse(
          request,
          'Google 로그인이 취소되었습니다. 이 창을 닫고 Daily로 돌아가세요.',
        );
        throw GoogleDriveAuthException('Google 로그인 실패: $error');
      }
      if (requestState != state || code == null || code.isEmpty) {
        await _writeBrowserResponse(
          request,
          'Google 로그인 응답을 확인할 수 없습니다. 이 창을 닫고 다시 시도하세요.',
        );
        throw const GoogleDriveAuthException('Google 로그인 응답이 올바르지 않습니다.');
      }

      await _writeBrowserResponse(
        request,
        'Google 로그인이 완료되었습니다. 이 창을 닫고 Daily로 돌아가세요.',
      );
      return _DesktopCodeResponse(
        code: code,
        redirectUri: redirectUri,
        codeVerifier: verifier,
      );
    } finally {
      await server.close(force: true);
    }
  }

  Future<_DesktopTokens> _exchangeAuthorizationCode(
    _DesktopCodeResponse codeResponse,
  ) async {
    final response = await _httpClient.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: _withDesktopClientSecret({
        'client_id': _configuredDesktopClientId,
        'code': codeResponse.code,
        'code_verifier': codeResponse.codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': codeResponse.redirectUri,
      }),
    );
    final decoded = _decodeTokenResponse(response);
    final refreshToken = decoded['refresh_token'] as String?;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const GoogleDriveAuthException('Google 갱신 토큰을 받지 못했습니다.');
    }
    return _tokensFromJson(decoded, refreshToken: refreshToken);
  }

  Future<void> _refreshDesktopAccessToken() async {
    final refreshToken = _desktopTokens?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const GoogleDriveAuthException('저장된 Google 갱신 토큰이 없습니다.');
    }
    final response = await _httpClient.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: _withDesktopClientSecret({
        'client_id': _configuredDesktopClientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      }),
    );
    final decoded = _decodeTokenResponse(response);
    final tokens = _tokensFromJson(decoded, refreshToken: refreshToken);
    final account = _desktopAccount;
    _desktopTokens = tokens;
    if (account != null) {
      await _saveDesktopSession(tokens, account);
    }
  }

  Map<String, String> _withDesktopClientSecret(Map<String, String> body) {
    final clientSecret = _configuredDesktopClientSecret;
    if (clientSecret.isEmpty) {
      return body;
    }
    return {...body, 'client_secret': clientSecret};
  }

  Map<String, Object?> _decodeTokenResponse(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final error = decoded['error_description'] ?? decoded['error'];
    throw GoogleDriveAuthException('Google 토큰 요청 실패: $error');
  }

  _DesktopTokens _tokensFromJson(
    Map<String, Object?> json, {
    required String refreshToken,
  }) {
    final accessToken = json['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const GoogleDriveAuthException('Google 액세스 토큰을 받지 못했습니다.');
    }
    final expiresIn = json['expires_in'] as int? ?? 3600;
    return _DesktopTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: max(60, expiresIn - 60)),
      ),
    );
  }

  Future<GoogleDriveAccount> _fetchDesktopAccount(String accessToken) async {
    final response = await _httpClient.get(
      Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveAuthException(
        'Google 계정 정보를 가져오지 못했습니다: HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final email = decoded['email'] as String?;
    if (email == null || email.isEmpty) {
      throw const GoogleDriveAuthException('Google 계정 이메일을 확인하지 못했습니다.');
    }
    return GoogleDriveAccount(
      email: email,
      displayName: decoded['name'] as String?,
    );
  }

  Future<void> _restoreDesktopSession() async {
    if (_desktopTokens != null || _desktopAccount != null) {
      return;
    }
    final refreshToken = await _readDesktopStorage(_refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      _setDesktopAccount(null);
      return;
    }
    final accessToken = await _readDesktopStorage(_accessTokenKey);
    final expiresAtValue = await _readDesktopStorage(_expiresAtKey);
    final email = await _readDesktopStorage(_emailKey);
    final displayName = await _readDesktopStorage(_displayNameKey);
    final expiresAt = expiresAtValue == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.tryParse(expiresAtValue)?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    _desktopTokens = _DesktopTokens(
      accessToken: accessToken ?? '',
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
    _setDesktopAccount(
      email == null || email.isEmpty
          ? null
          : GoogleDriveAccount(email: email, displayName: displayName),
    );
  }

  Future<void> _saveDesktopSession(
    _DesktopTokens tokens,
    GoogleDriveAccount account,
  ) async {
    _desktopTokens = tokens;
    await _writeDesktopStorage(_accessTokenKey, tokens.accessToken);
    await _writeDesktopStorage(_refreshTokenKey, tokens.refreshToken);
    await _writeDesktopStorage(
      _expiresAtKey,
      tokens.expiresAt.toIso8601String(),
    );
    await _writeDesktopStorage(_emailKey, account.email);
    await _writeDesktopStorage(_displayNameKey, account.displayName);
  }

  Future<String?> _readDesktopStorage(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } on PlatformException catch (error) {
      if (_isMissingSecureStorageEntitlement(error)) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _writeDesktopStorage(String key, String? value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } on PlatformException catch (error) {
      if (!_isMissingSecureStorageEntitlement(error)) {
        rethrow;
      }
    }
  }

  Future<void> _deleteDesktopStorage(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException catch (error) {
      if (!_isMissingSecureStorageEntitlement(error)) {
        rethrow;
      }
    }
  }

  Future<void> _clearDesktopSession() async {
    _desktopTokens = null;
    await _deleteDesktopStorage(_accessTokenKey);
    await _deleteDesktopStorage(_refreshTokenKey);
    await _deleteDesktopStorage(_expiresAtKey);
    await _deleteDesktopStorage(_emailKey);
    await _deleteDesktopStorage(_displayNameKey);
    _setDesktopAccount(null);
  }

  Future<void> _openSystemBrowser(Uri uri) async {
    final url = uri.toString();
    if (Platform.isWindows) {
      await Process.start('rundll32', [
        'url.dll,FileProtocolHandler',
        url,
      ], mode: ProcessStartMode.detached);
      return;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [url], mode: ProcessStartMode.detached);
      return;
    }
    await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
  }

  Future<void> _writeBrowserResponse(
    HttpRequest request,
    String message,
  ) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write(
      '<!doctype html><html lang="ko"><head><meta charset="utf-8">'
      '<title>Daily</title></head><body>'
      '<p style="font-family: sans-serif; font-size: 16px;">'
      '${htmlEscape.convert(message)}'
      '</p></body></html>',
    );
    await request.response.close();
  }

  String _randomUrlSafeString(int byteLength) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _pkceChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  void _setCurrentUser(GoogleSignInAccount? user) {
    _currentUser = user;
    _accountController.add(_toDriveAccount(user));
  }

  void _setDesktopAccount(GoogleDriveAccount? account) {
    _desktopAccount = account;
    _accountController.add(account);
  }

  GoogleDriveAccount? _toDriveAccount(GoogleSignInAccount? user) {
    if (user == null) {
      return null;
    }
    return GoogleDriveAccount(email: user.email, displayName: user.displayName);
  }

  String _googleSignInMessage(GoogleSignInException error) {
    final description = error.description;
    final details = error.details;
    final detailText = [
      if (description != null && description.trim().isNotEmpty)
        description.trim(),
      if (details != null) '$details',
    ].join(' / ');

    final hasKeychainError = detailText.toLowerCase().contains('keychain');

    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Google 로그인이 취소되었습니다.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        Platform.isIOS || Platform.isMacOS
            ? _appleClientConfigurationMessage
            : 'Google 로그인 클라이언트 설정이 올바르지 않습니다. '
                  'Android 패키지명과 앱 서명 SHA-1이 Google Cloud OAuth 클라이언트에 등록되어 있는지 확인해 주세요.'
                  '${detailText.isEmpty ? '' : ' ($detailText)'}',
      GoogleSignInExceptionCode.providerConfigurationError =>
        Platform.isMacOS && hasKeychainError
            ? '$_macosKeychainConfigurationMessage'
                  '${detailText.isEmpty ? '' : ' ($detailText)'}'
            : '기기의 Google Play 서비스 또는 Google 계정 설정 문제로 로그인할 수 없습니다.'
                  '${detailText.isEmpty ? '' : ' ($detailText)'}',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google 로그인 화면을 열 수 없습니다. 앱을 다시 열고 로그인 버튼을 다시 눌러 주세요.'
            '${detailText.isEmpty ? '' : ' ($detailText)'}',
      _ =>
        'Google 로그인 실패: ${error.code.name}'
            '${detailText.isEmpty ? '' : ' ($detailText)'}',
    };
  }

  bool _isCredentialClearFailure(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = error.message?.toLowerCase() ?? '';
    return code.contains('clear') || message.contains('clear failed');
  }

  bool _isMissingSecureStorageEntitlement(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = error.message?.toLowerCase() ?? '';
    final details = error.details?.toString().toLowerCase() ?? '';
    return code.contains('-34018') ||
        message.contains('-34018') ||
        message.contains('entitlement') ||
        details.contains('-34018');
  }

  String _platformAuthMessage(PlatformException error) {
    if (_isCredentialClearFailure(error)) {
      return 'Google 계정 상태를 초기화하지 못했습니다. 앱을 다시 열고 로그인 버튼을 다시 눌러 주세요.';
    }
    final detail = [
      if (error.code.trim().isNotEmpty) error.code,
      if (error.message != null && error.message!.trim().isNotEmpty)
        error.message!.trim(),
    ].join(' / ');
    if (Platform.isMacOS && detail.toLowerCase().contains('keychain')) {
      return '$_macosKeychainConfigurationMessage'
          '${detail.isEmpty ? '' : ' ($detail)'}';
    }
    if ((Platform.isIOS || Platform.isMacOS) &&
        (detail.contains('No active configuration') ||
            detail.contains('GIDClientID'))) {
      return '$_appleClientConfigurationMessage'
          '${detail.isEmpty ? '' : ' ($detail)'}';
    }
    return 'Google 로그인 처리 중 문제가 발생했습니다.'
        '${detail.isEmpty ? '' : ' ($detail)'}';
  }
}

class GoogleDriveAuthException implements Exception {
  const GoogleDriveAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _DesktopCodeResponse {
  const _DesktopCodeResponse({
    required this.code,
    required this.redirectUri,
    required this.codeVerifier,
  });

  final String code;
  final String redirectUri;
  final String codeVerifier;
}

class _DesktopTokens {
  const _DesktopTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get needsRefresh =>
      accessToken.isEmpty ||
      expiresAt.isBefore(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
}
