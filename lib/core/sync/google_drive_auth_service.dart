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
        '234127810480-uvesp3703ktqon6oj90abhjc62k9g6me.apps.googleusercontent.com',
  );
  static const _iosServerClientId = String.fromEnvironment(
    'GOOGLE_IOS_SERVER_CLIENT_ID',
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
  );
  static const _defaultDesktopClientId =
      '234127810480-caigb6e78fj43lv268t78sam64c3aivb.apps.googleusercontent.com';
  static const _desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
  );
  static const _storagePrefix = 'daily.google_drive.';
  static const _accessTokenKey = '${_storagePrefix}access_token';
  static const _refreshTokenKey = '${_storagePrefix}refresh_token';
  static const _expiresAtKey = '${_storagePrefix}expires_at';
  static const _emailKey = '${_storagePrefix}email';
  static const _displayNameKey = '${_storagePrefix}display_name';
  static const _mobileUserApprovalTimeout = Duration(minutes: 2);
  static const _mobileSilentAuthorizationTimeout = Duration(seconds: 10);
  static const _mobileLightweightAuthTimeout = Duration(seconds: 3);
  static const _mobileAccountClearTimeout = Duration(seconds: 2);
  static const _mobileSignOutTimeout = Duration(seconds: 3);
  static const _desktopUserApprovalTimeout = Duration(minutes: 2);
  static const _desktopNetworkTimeout = Duration(seconds: 10);

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
    final fromEnvironment =
        Platform.environment['GOOGLE_DESKTOP_CLIENT_ID']?.trim() ?? '';
    if (fromEnvironment.isNotEmpty) {
      return fromEnvironment;
    }
    final fromConfig = _desktopOAuthConfigValue('client_id');
    if (fromConfig.isNotEmpty) {
      return fromConfig;
    }
    return _defaultDesktopClientId;
  }

  String get _configuredDesktopClientSecret {
    final fromBuild = _desktopClientSecret.trim();
    if (fromBuild.isNotEmpty) {
      return fromBuild;
    }
    final fromEnvironment =
        Platform.environment['GOOGLE_DESKTOP_CLIENT_SECRET']?.trim() ?? '';
    if (fromEnvironment.isNotEmpty) {
      return fromEnvironment;
    }
    return _desktopOAuthConfigValue('client_secret');
  }

  String get _configuredDesktopRedirectHost {
    for (final uri in _desktopOAuthConfigUriListValue('redirect_uris')) {
      final parsed = Uri.tryParse(uri);
      if (parsed == null || parsed.scheme != 'http') {
        continue;
      }
      final host = parsed.host.toLowerCase();
      if (host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '[::1]' ||
          host == '::1') {
        return host == '[::1]' ? '::1' : host;
      }
    }
    return '127.0.0.1';
  }

  String _desktopOAuthConfigValue(String key) {
    for (final file in _desktopOAuthConfigFiles()) {
      try {
        if (!file.existsSync()) {
          continue;
        }
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final value = _oauthJsonValue(decoded, key);
        if (value.isNotEmpty) {
          return value;
        }
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return '';
  }

  Iterable<File> _desktopOAuthConfigFiles() sync* {
    final override = Platform.environment['GOOGLE_DESKTOP_OAUTH_CONFIG']
        ?.trim();
    if (override != null && override.isNotEmpty) {
      yield File(override);
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME']?.trim();
      if (home != null && home.isNotEmpty) {
        yield File(
          '$home${Platform.pathSeparator}Library'
          '${Platform.pathSeparator}Application Support'
          '${Platform.pathSeparator}Daily'
          '${Platform.pathSeparator}google_desktop_oauth.json',
        );
        yield File(
          '$home${Platform.pathSeparator}Library'
          '${Platform.pathSeparator}Application Support'
          '${Platform.pathSeparator}com.littlebit0.daily'
          '${Platform.pathSeparator}google_desktop_oauth.json',
        );
      }
      return;
    }

    if (Platform.isWindows) {
      for (final root in <String?>[
        Platform.environment['APPDATA'],
        Platform.environment['LOCALAPPDATA'],
      ]) {
        final normalizedRoot = root?.trim();
        if (normalizedRoot == null || normalizedRoot.isEmpty) {
          continue;
        }
        yield File(
          '$normalizedRoot${Platform.pathSeparator}Daily'
          '${Platform.pathSeparator}google_desktop_oauth.json',
        );
      }
    }
  }

  Iterable<String> _desktopOAuthConfigUriListValue(String key) sync* {
    for (final file in _desktopOAuthConfigFiles()) {
      try {
        if (!file.existsSync()) {
          continue;
        }
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        yield* _oauthJsonStringListValue(decoded, key);
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
  }

  String _oauthJsonValue(Map<String, dynamic> json, String key) {
    final direct = json[key];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    for (final sectionName in const ['installed', 'web']) {
      final section = json[sectionName];
      if (section is! Map<String, dynamic>) {
        continue;
      }
      final nested = section[key];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }
    return '';
  }

  Iterable<String> _oauthJsonStringListValue(
    Map<String, dynamic> json,
    String key,
  ) sync* {
    final direct = json[key];
    if (direct is List) {
      for (final item in direct) {
        if (item is String && item.trim().isNotEmpty) {
          yield item.trim();
        }
      }
    }
    for (final sectionName in const ['installed', 'web']) {
      final section = json[sectionName];
      if (section is! Map<String, dynamic>) {
        continue;
      }
      final nested = section[key];
      if (nested is List) {
        for (final item in nested) {
          if (item is String && item.trim().isNotEmpty) {
            yield item.trim();
          }
        }
      }
    }
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

  String get _configuredGoogleSignInServerClientId {
    if (Platform.isIOS) {
      final iosSpecific = _iosServerClientId.trim();
      if (iosSpecific.isNotEmpty) {
        return iosSpecific;
      }
      return Platform.environment['GOOGLE_IOS_SERVER_CLIENT_ID']?.trim() ?? '';
    }
    return _serverClientId.trim();
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
      try {
        return await _signInWithDesktopOAuth();
      } on TimeoutException {
        _setDesktopAccount(null);
        throw const GoogleDriveAuthException(
          'Google Drive 연결 응답 시간이 초과되었습니다. 브라우저 창을 닫고 다시 시도해 주세요.',
        );
      }
    }
    if (!_isAvailable) {
      throw UnsupportedError('현재 플랫폼에서는 Google Drive 연결을 지원하지 않습니다.');
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError('현재 플랫폼에서는 Google Drive 연결을 지원하지 않습니다.');
    }

    try {
      if (forceAccountSelection && _currentUser != null) {
        await _clearMobileAccountForSelection();
        _setCurrentUser(null);
      }

      final existing = _currentUser;
      if (existing != null) {
        return _toDriveAccount(existing);
      }

      final user = await GoogleSignIn.instance
          .authenticate(scopeHint: scopes)
          .timeout(_mobileUserApprovalTimeout);
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
        'Google Drive 연결 승인이 완료되지 않았습니다. 연결 창을 닫았다면 다시 연결 버튼을 눌러 주세요.',
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
      await GoogleSignIn.instance.signOut().timeout(
        _mobileSignOutTimeout,
        onTimeout: () {},
      );
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
      try {
        return await _desktopAuthorizationHeaders(
          promptIfNecessary: promptIfNecessary,
        );
      } on TimeoutException {
        throw const GoogleDriveAuthException(
          'Google Drive 연결 응답 시간이 초과되었습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
        );
      }
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
        if (promptIfNecessary) {
          await signIn();
          user = _currentUser;
        }
      }
    }
    try {
      final timeout = promptIfNecessary
          ? _mobileUserApprovalTimeout
          : _mobileSilentAuthorizationTimeout;
      final headers = await user?.authorizationClient
          .authorizationHeaders(scopes, promptIfNecessary: promptIfNecessary)
          .timeout(timeout);
      if (headers == null && promptIfNecessary) {
        _setCurrentUser(null);
        throw const GoogleDriveAuthException(
          'Google Drive 권한 승인이 완료되지 않았습니다. 다시 연결해 주세요.',
        );
      }
      return headers;
    } on PlatformException catch (error) {
      throw GoogleDriveAuthException(_platformAuthMessage(error));
    } on TimeoutException {
      throw const GoogleDriveAuthException(
        'Google Drive 권한 승인이 완료되지 않았습니다. 승인 창을 닫았다면 다시 연결해 주세요.',
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
      final serverClientId = _configuredGoogleSignInServerClientId;
      await GoogleSignIn.instance.initialize(
        clientId: appleClientId.isEmpty ? null : appleClientId,
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
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

    _setCurrentUser(null);
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
      return 'iOS Google Drive 연결을 사용하려면 GIDClientID plist 설정 또는 '
          'GOOGLE_IOS_CLIENT_ID 빌드 인자와 reversed client ID URL scheme이 필요합니다. '
          '지금은 로컬 모드로 사용할 수 있습니다.';
    }
    if (Platform.isMacOS) {
      return 'macOS Google Drive 연결을 사용하려면 GIDClientID plist 설정 또는 '
          'GOOGLE_MACOS_CLIENT_ID 빌드 인자와 reversed client ID URL scheme이 필요합니다. '
          '지금은 로컬 모드로 사용할 수 있습니다.';
    }
    return 'Google Drive 연결 클라이언트 설정이 필요합니다.';
  }

  String get _macosKeychainConfigurationMessage =>
      'macOS Google Drive 연결을 사용하려면 keychain sharing entitlement가 필요합니다. '
      '새 빌드에서도 같은 오류가 나면 Apple 개발 팀 서명 설정을 확인해 주세요.';

  Future<GoogleDriveAccount?> _signInWithDesktopOAuth() async {
    if (_configuredDesktopClientId.isEmpty) {
      throw UnsupportedError(
        'Google Drive 연결 설정이 아직 완료되지 않았습니다. 앱 업데이트 후 다시 시도해 주세요.',
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
    final redirectHost = _configuredDesktopRedirectHost;
    final server = await HttpServer.bind(
      redirectHost == '::1'
          ? InternetAddress.loopbackIPv6
          : redirectHost == 'localhost'
          ? 'localhost'
          : InternetAddress.loopbackIPv4,
      0,
    );
    final redirectUri = redirectHost == '::1'
        ? 'http://[::1]:${server.port}/'
        : 'http://$redirectHost:${server.port}/';
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
        _desktopUserApprovalTimeout,
        onTimeout: () => throw TimeoutException('Google Drive 연결이 시간 초과되었습니다.'),
      );
      final params = request.uri.queryParameters;
      final requestState = params['state'];
      final code = params['code'];
      final error = params['error'];

      if (error != null) {
        await _writeBrowserResponse(
          request,
          'Google Drive 연결이 취소되었습니다. 이 창을 닫고 Daily로 돌아가세요.',
        );
        throw GoogleDriveAuthException(
          _desktopAuthorizationErrorMessage(error),
        );
      }
      if (requestState != state || code == null || code.isEmpty) {
        await _writeBrowserResponse(
          request,
          'Google Drive 연결 응답을 확인할 수 없습니다. 이 창을 닫고 다시 시도하세요.',
        );
        throw const GoogleDriveAuthException('Google Drive 연결 응답이 올바르지 않습니다.');
      }

      await _writeBrowserResponse(
        request,
        'Google Drive 연결이 완료되었습니다. 이 창을 닫고 Daily로 돌아가세요.',
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
    final response = await _httpClient
        .post(
          Uri.https('oauth2.googleapis.com', '/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: _withDesktopClientSecret({
            'client_id': _configuredDesktopClientId,
            'code': codeResponse.code,
            'code_verifier': codeResponse.codeVerifier,
            'grant_type': 'authorization_code',
            'redirect_uri': codeResponse.redirectUri,
          }),
        )
        .timeout(_desktopNetworkTimeout);
    final decoded = _decodeTokenResponse(response);
    final refreshToken = decoded['refresh_token'] as String?;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const GoogleDriveAuthException(
        'Google Drive 연결을 완료하지 못했습니다. 다시 연결해 주세요.',
      );
    }
    return _tokensFromJson(decoded, refreshToken: refreshToken);
  }

  Future<void> _refreshDesktopAccessToken() async {
    final refreshToken = _desktopTokens?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const GoogleDriveAuthException('저장된 Google Drive 갱신 토큰이 없습니다.');
    }
    final response = await _httpClient
        .post(
          Uri.https('oauth2.googleapis.com', '/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: _withDesktopClientSecret({
            'client_id': _configuredDesktopClientId,
            'refresh_token': refreshToken,
            'grant_type': 'refresh_token',
          }),
        )
        .timeout(_desktopNetworkTimeout);
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
    final decoded = _decodeJsonObject(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw GoogleDriveAuthException(
      _desktopTokenRequestMessage(response.statusCode, decoded),
    );
  }

  _DesktopTokens _tokensFromJson(
    Map<String, Object?> json, {
    required String refreshToken,
  }) {
    final accessToken = json['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const GoogleDriveAuthException(
        'Google Drive 연결을 완료하지 못했습니다. 다시 연결해 주세요.',
      );
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
    final response = await _httpClient
        .get(
          Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(_desktopNetworkTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveAuthException(
        _desktopAccountRequestMessage(response.statusCode),
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

  Map<String, Object?> _decodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } on FormatException {
      return const {};
    }
    return const {};
  }

  String _desktopAuthorizationErrorMessage(String error) {
    final normalized = error.trim().toLowerCase();
    if (normalized == 'access_denied') {
      return 'Google Drive 연결이 취소되었습니다.';
    }
    if (normalized.contains('temporarily_unavailable') ||
        normalized.contains('server_error')) {
      return 'Google Drive 연결 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.';
    }
    return 'Google Drive 연결을 완료하지 못했습니다. 다시 시도해 주세요.';
  }

  String get _desktopPlatformLabel {
    if (Platform.isMacOS) {
      return 'macOS';
    }
    if (Platform.isWindows) {
      return 'Windows';
    }
    return '데스크톱';
  }

  String _desktopTokenRequestMessage(
    int statusCode,
    Map<String, Object?> decoded,
  ) {
    final error = '${decoded['error'] ?? ''}'.toLowerCase();
    final description = '${decoded['error_description'] ?? ''}'.toLowerCase();
    final detail = '$error $description';

    if (detail.contains('invalid_client')) {
      return '$_desktopPlatformLabel Google Drive 연결 클라이언트 설정이 올바르지 않습니다. OAuth 클라이언트 정보를 확인해 주세요.';
    }
    if (detail.contains('redirect_uri')) {
      return '$_desktopPlatformLabel Google Drive 연결 리디렉션 설정이 올바르지 않습니다. OAuth 클라이언트 설정을 확인해 주세요.';
    }
    if (statusCode == 401 ||
        detail.contains('invalid_grant') ||
        detail.contains('invalid_token')) {
      return 'Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.';
    }
    if (statusCode == 403 || detail.contains('access_denied')) {
      return 'Google Drive 권한이 부족합니다. 다시 연결해 권한을 승인해 주세요.';
    }
    if (statusCode == 429) {
      return 'Google 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (statusCode >= 500) {
      return 'Google Drive 연결 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.';
    }
    return 'Google Drive 연결 정보를 확인하지 못했습니다. 다시 연결해 주세요.';
  }

  String _desktopAccountRequestMessage(int statusCode) {
    if (statusCode == 401) {
      return 'Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.';
    }
    if (statusCode == 403) {
      return 'Google 계정 정보를 확인할 권한이 없습니다. 다시 연결해 주세요.';
    }
    if (statusCode == 429) {
      return 'Google 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (statusCode >= 500) {
      return 'Google 계정 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.';
    }
    return 'Google 계정 정보를 확인하지 못했습니다. 다시 연결해 주세요.';
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
    await Future.wait([
      _deleteDesktopStorage(_accessTokenKey),
      _deleteDesktopStorage(_refreshTokenKey),
      _deleteDesktopStorage(_expiresAtKey),
      _deleteDesktopStorage(_emailKey),
      _deleteDesktopStorage(_displayNameKey),
    ]);
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
    final isApiConsoleRegistrationError = detailText.contains(
      'UNREGISTERED_ON_API_CONSOLE',
    );
    final androidConfigurationMessage =
        'Google Drive 연결 클라이언트 설정이 올바르지 않습니다. '
        'Android 패키지명과 앱 서명 SHA-1이 Google Cloud OAuth 클라이언트에 등록되어 있는지 확인해 주세요.'
        '${detailText.isEmpty ? '' : ' ($detailText)'}';

    if (isApiConsoleRegistrationError && !Platform.isIOS && !Platform.isMacOS) {
      return androidConfigurationMessage;
    }

    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Google Drive 연결이 취소되었습니다.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        Platform.isIOS || Platform.isMacOS
            ? _appleClientConfigurationMessage
            : androidConfigurationMessage,
      GoogleSignInExceptionCode.providerConfigurationError =>
        Platform.isMacOS && hasKeychainError
            ? '$_macosKeychainConfigurationMessage'
                  '${detailText.isEmpty ? '' : ' ($detailText)'}'
            : '기기의 Google 연결 설정 문제로 연결할 수 없습니다. Google Play 서비스와 Google 계정 상태를 확인해 주세요.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google Drive 연결 화면을 열 수 없습니다. 앱을 다시 열고 연결 버튼을 다시 눌러 주세요.',
      _ => 'Google Drive 연결을 완료하지 못했습니다. 다시 시도해 주세요.',
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
      return 'Google 계정 상태를 초기화하지 못했습니다. 앱을 다시 열고 연결 버튼을 다시 눌러 주세요.';
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
    return 'Google Drive 연결 처리 중 문제가 발생했습니다. 앱을 다시 열고 연결 버튼을 다시 눌러 주세요.';
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
