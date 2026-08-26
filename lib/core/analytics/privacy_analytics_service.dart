import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'product_analytics.dart';

class AnalyticsEnvironment {
  const AnalyticsEnvironment({
    required this.appVersion,
    required this.platform,
    required this.osMajor,
  });

  final String appVersion;
  final String platform;
  final int osMajor;

  Map<String, Object> toJson() => {
    'appVersion': appVersion,
    'platform': platform,
    'osMajor': osMajor,
  };
}

class PrivacyAnalyticsService implements ProductAnalytics {
  static const _productionEndpoint =
      'https://littlebit.tail6514a4.ts.net/v1/events';
  PrivacyAnalyticsService({
    required SharedPreferences preferences,
    http.Client? httpClient,
    Uri? endpoint,
    Future<AnalyticsEnvironment> Function()? environmentLoader,
    DateTime Function()? now,
    String Function()? idGenerator,
  }) : _preferences = preferences,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _endpoint = endpoint ?? _configuredEndpoint,
       _environmentLoader = environmentLoader ?? _loadEnvironment,
       _now = now ?? DateTime.now,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _enabled = ValueNotifier<bool>(
         preferences.getBool(_enabledKey) ?? false,
       ),
       _consentPromptCompleted = ValueNotifier<bool>(
         preferences.getBool(_consentPromptCompletedKey) ??
             preferences.containsKey(_enabledKey),
       );

  static const _enabledKey = 'anonymousAnalyticsEnabled';
  static const _consentPromptCompletedKey =
      'anonymousAnalyticsConsentPromptCompletedV1';
  static const _queueKey = 'anonymousAnalyticsQueueV1';
  static const _schemaVersion = 1;
  static const _maxQueueLength = 200;
  static const _batchSize = 25;
  static const _maxEventAge = Duration(days: 7);
  static const _requestTimeout = Duration(seconds: 8);
  static const _retryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
    Duration(hours: 1),
  ];
  static final Uri? _configuredEndpoint = _parseConfiguredEndpoint();

  final SharedPreferences _preferences;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Uri? _endpoint;
  final Future<AnalyticsEnvironment> Function() _environmentLoader;
  final DateTime Function() _now;
  final String Function() _idGenerator;
  final ValueNotifier<bool> _enabled;
  final ValueNotifier<bool> _consentPromptCompleted;
  late final String _sessionId = _idGenerator();
  AnalyticsEnvironment? _environment;
  List<_QueuedAnalyticsEvent> _queue = [];
  Future<void>? _flushOperation;
  Timer? _retryTimer;
  bool _initialized = false;
  bool _performanceMonitoring = false;

  @override
  bool get enabled => _enabled.value;

  @override
  ValueListenable<bool> get enabledListenable => _enabled;

  @override
  bool get consentPromptCompleted => _consentPromptCompleted.value;

  @override
  ValueListenable<bool> get consentPromptCompletedListenable =>
      _consentPromptCompleted;

  @override
  int get pendingEventCount => _queue.length;

  @override
  Future<void> completeConsentPrompt({required bool enabled}) async {
    await setEnabled(enabled);
    await _preferences.setBool(_consentPromptCompletedKey, true);
    _consentPromptCompleted.value = true;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _environment = await _environmentLoader();
    } on Object {
      _environment = AnalyticsEnvironment(
        appVersion: '0.0.0',
        platform: Platform.operatingSystem,
        osMajor: _osMajor(Platform.operatingSystemVersion),
      );
    }
    try {
      _queue = _loadQueue();
      _pruneQueue();
      await _persistQueue();
    } on Object {
      _queue = [];
    }
    _initialized = true;
    try {
      _updatePerformanceMonitoring();
    } on Object {
      _performanceMonitoring = false;
    }
    if (enabled) {
      unawaited(flush());
    }
  }

  @override
  Future<void> setEnabled(bool value) async {
    if (_enabled.value == value) return;
    await _preferences.setBool(_enabledKey, value);
    _enabled.value = value;
    _updatePerformanceMonitoring();
    if (!value) {
      await deletePendingData();
      return;
    }
    unawaited(flush());
  }

  @override
  Future<void> deletePendingData() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _queue.clear();
    await _preferences.remove(_queueKey);
  }

  @override
  Future<void> record(AnalyticsRecord record) async {
    if (!enabled) return;
    if (!_initialized) await initialize();
    final event = _QueuedAnalyticsEvent(
      id: _idGenerator(),
      name: record.name.wireName,
      occurredAt: _now().toUtc(),
      attributes: Map<String, Object>.from(record.attributes),
    );
    if (!isSafeAnalyticsEvent(event.toPayloadJson())) {
      return;
    }
    if (_isRecentDuplicate(event)) return;
    _queue.add(event);
    _pruneQueue();
    await _persistQueue();
    unawaited(flush());
  }

  @override
  Future<void> flush() {
    final active = _flushOperation;
    if (active != null) return active;
    final operation = _flushImpl();
    _flushOperation = operation;
    return operation.whenComplete(() {
      if (identical(_flushOperation, operation)) {
        _flushOperation = null;
      }
    });
  }

  Future<void> _flushImpl() async {
    if (!enabled || !_initialized || _queue.isEmpty || _endpoint == null) {
      return;
    }
    if (!_isAllowedEndpoint(_endpoint)) return;
    final now = _now().toUtc();
    final ready = _queue
        .where(
          (event) =>
              event.nextAttemptAt == null || !event.nextAttemptAt!.isAfter(now),
        )
        .take(_batchSize)
        .toList(growable: false);
    if (ready.isEmpty) {
      _scheduleNextRetry();
      return;
    }

    final environment = _environment ?? await _environmentLoader();
    _environment = environment;
    try {
      final response = await _httpClient
          .post(
            _endpoint,
            headers: const {
              HttpHeaders.contentTypeHeader: 'application/json',
              'X-Daily-Analytics-Schema': '1',
            },
            body: jsonEncode({
              'schemaVersion': _schemaVersion,
              'sessionId': _sessionId,
              'environment': environment.toJson(),
              'events': ready.map((event) => event.toPayloadJson()).toList(),
            }),
          )
          .timeout(_requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final sentIds = ready.map((event) => event.id).toSet();
        _queue.removeWhere((event) => sentIds.contains(event.id));
      } else if (response.statusCode >= 400 &&
          response.statusCode < 500 &&
          response.statusCode != 408 &&
          response.statusCode != 429) {
        final rejectedIds = ready.map((event) => event.id).toSet();
        _queue.removeWhere((event) => rejectedIds.contains(event.id));
      } else {
        _markFailed(ready);
      }
    } on Object {
      _markFailed(ready);
    }
    await _persistQueue();
    if (_queue.isNotEmpty) {
      _scheduleNextRetry();
    }
  }

  void _markFailed(List<_QueuedAnalyticsEvent> events) {
    final now = _now().toUtc();
    for (final event in events) {
      event.attempts += 1;
      final retryIndex = (event.attempts - 1).clamp(0, _retryDelays.length - 1);
      event.nextAttemptAt = now.add(_retryDelays[retryIndex]);
    }
  }

  void _scheduleNextRetry() {
    _retryTimer?.cancel();
    if (!enabled || _queue.isEmpty || _endpoint == null) return;
    final now = _now().toUtc();
    final next = _queue
        .map((event) => event.nextAttemptAt ?? now)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final delay = next.difference(now);
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(flush());
    });
  }

  bool _isRecentDuplicate(_QueuedAnalyticsEvent candidate) {
    if (_queue.isEmpty) return false;
    final previous = _queue.last;
    return previous.name == candidate.name &&
        mapEquals(previous.attributes, candidate.attributes) &&
        candidate.occurredAt.difference(previous.occurredAt).abs() <
            const Duration(seconds: 1);
  }

  List<_QueuedAnalyticsEvent> _loadQueue() {
    final raw = _preferences.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => _QueuedAnalyticsEvent.fromQueueJson(
              Map<String, Object?>.from(item),
            ),
          )
          .whereType<_QueuedAnalyticsEvent>()
          .where((event) => isSafeAnalyticsEvent(event.toPayloadJson()))
          .toList(growable: true);
    } on Object {
      return [];
    }
  }

  void _pruneQueue() {
    final cutoff = _now().toUtc().subtract(_maxEventAge);
    _queue.removeWhere((event) => event.occurredAt.isBefore(cutoff));
    if (_queue.length > _maxQueueLength) {
      _queue = _queue.sublist(_queue.length - _maxQueueLength);
    }
  }

  Future<void> _persistQueue() {
    if (_queue.isEmpty) return _preferences.remove(_queueKey);
    return _preferences.setString(
      _queueKey,
      jsonEncode(_queue.map((event) => event.toQueueJson()).toList()),
    );
  }

  void _updatePerformanceMonitoring() {
    if (enabled && !_performanceMonitoring) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
      _performanceMonitoring = true;
    } else if (!enabled && _performanceMonitoring) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
      _performanceMonitoring = false;
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    final slow = timings
        .where((timing) => timing.totalSpan > const Duration(milliseconds: 32))
        .toList(growable: false);
    if (slow.isEmpty) return;
    final maxDuration = slow
        .map((timing) => timing.totalSpan.inMilliseconds)
        .reduce((left, right) => left > right ? left : right);
    unawaited(
      record(
        AnalyticsRecord.slowInteraction(
          interaction: 'frame_batch',
          durationMs: maxDuration,
          slowFrameCount: slow.length,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    if (_performanceMonitoring) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    }
    _enabled.dispose();
    _consentPromptCompleted.dispose();
    if (_ownsHttpClient) _httpClient.close();
  }

  static Uri? _parseConfiguredEndpoint() {
    const raw = String.fromEnvironment('DAILY_ANALYTICS_ENDPOINT');
    final configured = raw.trim();
    if (configured.isNotEmpty) return Uri.tryParse(configured);
    if (kReleaseMode) return Uri.parse(_productionEndpoint);
    return null;
  }

  static bool _isAllowedEndpoint(Uri endpoint) {
    if (endpoint.scheme == 'https') return true;
    return kDebugMode &&
        endpoint.scheme == 'http' &&
        (endpoint.host == 'localhost' || endpoint.host == '127.0.0.1');
  }

  static Future<AnalyticsEnvironment> _loadEnvironment() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return AnalyticsEnvironment(
      appVersion: packageInfo.version,
      platform: Platform.operatingSystem,
      osMajor: _osMajor(Platform.operatingSystemVersion),
    );
  }

  static int _osMajor(String version) {
    final match = RegExp(r'(\d+)').firstMatch(version);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}

class _QueuedAnalyticsEvent {
  _QueuedAnalyticsEvent({
    required this.id,
    required this.name,
    required this.occurredAt,
    required this.attributes,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final String id;
  final String name;
  final DateTime occurredAt;
  final Map<String, Object> attributes;
  int attempts;
  DateTime? nextAttemptAt;

  Map<String, Object> toPayloadJson() => {
    'eventId': id,
    'name': name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'attributes': attributes,
  };

  Map<String, Object?> toQueueJson() => {
    ...toPayloadJson(),
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
  };

  static _QueuedAnalyticsEvent? fromQueueJson(Map<String, Object?> json) {
    final occurredAt = DateTime.tryParse(json['occurredAt'] as String? ?? '');
    final rawAttributes = json['attributes'];
    if (occurredAt == null || rawAttributes is! Map) return null;
    return _QueuedAnalyticsEvent(
      id: json['eventId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      occurredAt: occurredAt.toUtc(),
      attributes: Map<String, Object>.from(rawAttributes),
      attempts: json['attempts'] as int? ?? 0,
      nextAttemptAt: DateTime.tryParse(
        json['nextAttemptAt'] as String? ?? '',
      )?.toUtc(),
    );
  }
}

bool isSafeAnalyticsBatch(Object? value) {
  if (value is! Map) return false;
  final json = Map<String, Object?>.from(value);
  if (json['schemaVersion'] != 1 || !_isUuid(json['sessionId'])) return false;
  final environment = json['environment'];
  final events = json['events'];
  if (environment is! Map ||
      events is! List ||
      events.isEmpty ||
      events.length > 25) {
    return false;
  }
  final env = Map<String, Object?>.from(environment);
  const platforms = {'ios', 'macos', 'android', 'windows', 'linux'};
  if (!platforms.contains(env['platform']) ||
      env['appVersion'] is! String ||
      !RegExp(
        r'^\d+\.\d+\.\d+(?:\.\d+)?$',
      ).hasMatch(env['appVersion'] as String) ||
      env['osMajor'] is! int) {
    return false;
  }
  return events.every(isSafeAnalyticsEvent);
}

bool isSafeAnalyticsEvent(Object? value) {
  if (value is! Map) return false;
  final json = Map<String, Object?>.from(value);
  if (!_isUuid(json['eventId']) ||
      DateTime.tryParse(json['occurredAt'] as String? ?? '') == null ||
      json['attributes'] is! Map) {
    return false;
  }
  final name = json['name'] as String?;
  final attributes = Map<String, Object?>.from(json['attributes'] as Map);
  final schema = _analyticsSchemas[name];
  if (schema == null ||
      !setEquals(attributes.keys.toSet(), schema.keys.toSet())) {
    return false;
  }
  for (final entry in attributes.entries) {
    if (!schema[entry.key]!(entry.value)) return false;
  }
  return true;
}

bool _isUuid(Object? value) {
  return value is String &&
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(value);
}

bool _enumValue<T extends Enum>(Object? value, List<T> values) {
  return value is String && values.any((item) => item.name == value);
}

bool _duration(Object? value) => value is int && value >= 0 && value <= 120000;
bool _frameCount(Object? value) => value is int && value >= 0 && value <= 120;

final _analyticsSchemas = <String, Map<String, bool Function(Object?)>>{
  AnalyticsEventName.appLoadCompleted.wireName: {'durationMs': _duration},
  AnalyticsEventName.screenView.wireName: {
    'screen': (value) => _enumValue(value, AnalyticsScreen.values),
  },
  AnalyticsEventName.calendarViewChanged.wireName: {
    'view': (value) => _enumValue(value, AnalyticsCalendarView.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
  },
  AnalyticsEventName.eventEditorOpened.wireName: {
    'mode': (value) => _enumValue(value, AnalyticsEditorMode.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
  },
  AnalyticsEventName.eventEditorCompleted.wireName: {
    'mode': (value) => _enumValue(value, AnalyticsEditorMode.values),
    'outcome': (value) => _enumValue(value, AnalyticsOutcome.values),
    'durationMs': _duration,
  },
  AnalyticsEventName.eventSaveSucceeded.wireName: {
    'operation': (value) => _enumValue(value, AnalyticsOperation.values),
    'durationMs': _duration,
  },
  AnalyticsEventName.eventSaveFailed.wireName: {
    'operation': (value) => _enumValue(value, AnalyticsOperation.values),
    'durationMs': _duration,
    'errorCode': (value) => _enumValue(value, AnalyticsErrorCode.values),
  },
  AnalyticsEventName.featureUsed.wireName: {
    'feature': (value) => _enumValue(value, AnalyticsFeature.values),
    'outcome': (value) => _enumValue(value, AnalyticsOutcome.values),
  },
  AnalyticsEventName.syncStarted.wireName: {
    'operation': (value) => _enumValue(value, AnalyticsSyncOperation.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
  },
  AnalyticsEventName.syncSucceeded.wireName: {
    'operation': (value) => _enumValue(value, AnalyticsSyncOperation.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
    'outcome': (value) => value == AnalyticsOutcome.succeeded.name,
    'durationMs': _duration,
  },
  AnalyticsEventName.syncFailed.wireName: {
    'operation': (value) => _enumValue(value, AnalyticsSyncOperation.values),
    'trigger': (value) => _enumValue(value, AnalyticsTrigger.values),
    'outcome': (value) =>
        value == AnalyticsOutcome.failed.name ||
        value == AnalyticsOutcome.canceled.name,
    'durationMs': _duration,
    'errorCode': (value) => _enumValue(value, AnalyticsErrorCode.values),
  },
  AnalyticsEventName.slowInteractionDetected.wireName: {
    'interaction': (value) => analyticsInteractionValues.contains(value),
    'durationMs': _duration,
    'slowFrameCount': _frameCount,
  },
};
