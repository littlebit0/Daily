import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily/core/analytics/privacy_analytics_service.dart';

const _maxRequestBytes = 64 * 1024;
const _maxRequestsPerMinute = 120;

Future<void> main() async {
  final address = Platform.environment['DAILY_ANALYTICS_BIND'] ?? '127.0.0.1';
  final port =
      int.tryParse(Platform.environment['DAILY_ANALYTICS_PORT'] ?? '') ?? 8787;
  final dataDirectory = Directory(
    Platform.environment['DAILY_ANALYTICS_DATA_DIR'] ?? 'var/analytics',
  );
  final server = await AnalyticsReceiverServer.bind(
    address: address,
    port: port,
    aggregator: DailyAnalyticsAggregator(dataDirectory),
  );
  stdout.writeln(
    'Daily analytics receiver listening on ${server.address.address}:${server.port}',
  );

  final stopping = Completer<void>();
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) async {
      if (stopping.isCompleted) return;
      await server.close();
      stopping.complete();
    });
  }
  await stopping.future;
}

class AnalyticsReceiverServer {
  AnalyticsReceiverServer._(this._server, this._aggregator) {
    _subscription = _server.listen(_handleRequest);
  }

  final HttpServer _server;
  final DailyAnalyticsAggregator _aggregator;
  final _rateWindows = <String, _RateWindow>{};
  late final StreamSubscription<HttpRequest> _subscription;

  InternetAddress get address => _server.address;
  int get port => _server.port;

  static Future<AnalyticsReceiverServer> bind({
    required String address,
    required int port,
    required DailyAnalyticsAggregator aggregator,
  }) async {
    final server = await HttpServer.bind(address, port, shared: false);
    return AnalyticsReceiverServer._(server, aggregator);
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    if (request.method == 'GET' && request.uri.path == '/health') {
      request.response.statusCode = HttpStatus.ok;
      request.response.write('{"status":"ok"}');
      await request.response.close();
      return;
    }
    if (request.method != 'POST' || request.uri.path != '/v1/events') {
      await _respond(request, HttpStatus.notFound, 'not_found');
      return;
    }
    if (!_consumeRateLimit(
      request.connectionInfo?.remoteAddress.address ?? 'unknown',
    )) {
      await _respond(request, HttpStatus.tooManyRequests, 'rate_limited');
      return;
    }

    final bytes = <int>[];
    try {
      await for (final chunk in request) {
        bytes.addAll(chunk);
        if (bytes.length > _maxRequestBytes) {
          await _respond(
            request,
            HttpStatus.requestEntityTooLarge,
            'payload_too_large',
          );
          return;
        }
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (!isSafeAnalyticsBatch(decoded)) {
        await _respond(request, HttpStatus.badRequest, 'invalid_schema');
        return;
      }
      final accepted = await _aggregator.accept(
        Map<String, Object?>.from(decoded as Map),
      );
      request.response.statusCode = HttpStatus.accepted;
      request.response.write(jsonEncode({'accepted': accepted}));
      await request.response.close();
    } on FormatException {
      await _respond(request, HttpStatus.badRequest, 'invalid_json');
    } on Object {
      await _respond(request, HttpStatus.internalServerError, 'store_failed');
    }
  }

  bool _consumeRateLimit(String address) {
    final now = DateTime.now().toUtc();
    _rateWindows.removeWhere(
      (_, window) =>
          now.difference(window.startedAt) >= const Duration(minutes: 2),
    );
    final current = _rateWindows[address];
    if (current == null ||
        now.difference(current.startedAt) >= const Duration(minutes: 1)) {
      _rateWindows[address] = _RateWindow(now, 1);
      return true;
    }
    if (current.count >= _maxRequestsPerMinute) return false;
    current.count += 1;
    return true;
  }

  Future<void> _respond(HttpRequest request, int status, String code) async {
    request.response.statusCode = status;
    request.response.write(jsonEncode({'error': code}));
    await request.response.close();
  }
}

class DailyAnalyticsAggregator {
  DailyAnalyticsAggregator(this.directory, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _now;
  Future<void> _writeTail = Future<void>.value();

  Future<int> accept(Map<String, Object?> batch) {
    final completer = Completer<int>();
    _writeTail = _writeTail.then((_) async {
      try {
        completer.complete(await _acceptLocked(batch));
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<int> _acceptLocked(Map<String, Object?> batch) async {
    if (!isSafeAnalyticsBatch(batch)) {
      throw const FormatException('Unsafe analytics batch');
    }
    await directory.create(recursive: true);
    await _deleteExpiredFiles();

    final environment = Map<String, Object?>.from(batch['environment'] as Map);
    final events = (batch['events'] as List)
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList(growable: false);
    final day = _dayKey(_now().toUtc());
    final aggregateFile = File('${directory.path}/analytics-$day.json');
    final dedupeFile = File('${directory.path}/dedupe-$day.json');
    final aggregate = await _readAggregate(aggregateFile, day);
    final hashes = await _readHashes(dedupeFile);
    var accepted = 0;

    for (final event in events) {
      final eventHash = sha256
          .convert(utf8.encode(event['eventId'] as String))
          .toString();
      if (!hashes.add(eventHash)) continue;
      accepted += 1;
      final attributes = Map<String, Object?>.from(event['attributes'] as Map);
      final key = jsonEncode({
        'appVersion': environment['appVersion'],
        'platform': environment['platform'],
        'osMajor': environment['osMajor'],
        'name': event['name'],
        'attributes': _sortedMap(attributes),
      });
      final groups = Map<String, Object?>.from(aggregate['groups'] as Map);
      final current = groups[key] is Map
          ? Map<String, Object?>.from(groups[key] as Map)
          : <String, Object?>{
              'appVersion': environment['appVersion'],
              'platform': environment['platform'],
              'osMajor': environment['osMajor'],
              'name': event['name'],
              'attributes': _sortedMap(attributes),
              'count': 0,
              'durationTotalMs': 0,
              'durationMaxMs': 0,
            };
      current['count'] = (current['count'] as int) + 1;
      final duration = attributes['durationMs'] as int? ?? 0;
      current['durationTotalMs'] =
          (current['durationTotalMs'] as int) + duration;
      current['durationMaxMs'] = duration > (current['durationMaxMs'] as int)
          ? duration
          : current['durationMaxMs'] as int;
      groups[key] = current;
      aggregate['groups'] = groups;
    }

    aggregate['updatedAt'] = _now().toUtc().toIso8601String();
    await _writeJsonAtomically(aggregateFile, aggregate);
    await _writeJsonAtomically(dedupeFile, hashes.toList()..sort());
    return accepted;
  }

  Future<Map<String, Object?>> _readAggregate(File file, String day) async {
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) return Map<String, Object?>.from(decoded);
      } on Object {
        // Replace an unreadable aggregate rather than accepting malformed data.
      }
    }
    return {'schemaVersion': 1, 'date': day, 'groups': <String, Object?>{}};
  }

  Future<Set<String>> _readHashes(File file) async {
    if (!await file.exists()) return <String>{};
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is List ? decoded.whereType<String>().toSet() : <String>{};
    } on Object {
      return <String>{};
    }
  }

  Future<void> _writeJsonAtomically(File file, Object value) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<void> _deleteExpiredFiles() async {
    final now = _now().toUtc();
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      final match = RegExp(
        r'^(analytics|dedupe)-(\d{4}-\d{2}-\d{2})\.json$',
      ).firstMatch(name);
      if (match == null) continue;
      final date = DateTime.tryParse(match.group(2)!);
      if (date == null) continue;
      final retention = match.group(1) == 'analytics'
          ? const Duration(days: 90)
          : const Duration(days: 7);
      if (now.difference(date) > retention) await entity.delete();
    }
  }

  static Map<String, Object?> _sortedMap(Map<String, Object?> source) {
    final keys = source.keys.toList()..sort();
    return {for (final key in keys) key: source[key]};
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _RateWindow {
  _RateWindow(this.startedAt, this.count);

  final DateTime startedAt;
  int count;
}
