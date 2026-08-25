# Anonymous Analytics Deployment

Daily ships a first-party, aggregate-only analytics receiver. It is optional;
without `DAILY_ANALYTICS_ENDPOINT`, the app sends no analytics network request.

## Ubuntu Receiver

Install a Dart SDK on the Ubuntu host, check out the same Daily revision, and
run:

```bash
DAILY_ANALYTICS_BIND=127.0.0.1 \
DAILY_ANALYTICS_PORT=8787 \
DAILY_ANALYTICS_DATA_DIR=/var/lib/daily-analytics \
dart run tool/analytics_receiver.dart
```

Run it under a dedicated unprivileged system user. Put an HTTPS reverse proxy
in front of `127.0.0.1:8787`, disable request-body and access logging for the
ingestion path, and expose only:

- `POST /v1/events`
- `GET /health`

The receiver limits a request to 64 KiB and 25 events, applies an in-memory
per-address rate limit, revalidates the allowlist, and never logs request
bodies. Daily aggregates are stored in `analytics-YYYY-MM-DD.json`; delivery
dedupe hashes are stored separately. Aggregate files expire after 90 days and
dedupe files after seven days.

## App Build

Use the public HTTPS ingestion URL only in a release build:

```bash
./tool/flutter.sh build ipa --release \
  --dart-define=DAILY_ANALYTICS_ENDPOINT=https://analytics.example.com/v1/events
```

Use the same `--dart-define` for the macOS build. A missing endpoint is a valid
privacy-safe configuration: consent can still be disabled or cleared, and no
network transmission occurs.

## Verification

1. Leave `익명 사용성 분석 허용` off and verify that no ingestion request is
   received.
2. Turn it on and use calendar views, event editing, search, filters, and manual
   sync.
3. Verify the receiver aggregate contains only allowlisted enums and numeric
   measurements.
4. Confirm that no aggregate or dedupe file contains a session ID, event ID,
   account, calendar content, search text, token, or network address.
5. Disconnect the receiver, create events, and verify calendar and Drive sync
   still succeed while the bounded analytics queue waits independently.
6. Turn analytics off or use `분석 데이터 삭제` and verify the local queue is
   removed.

Automated coverage for these boundaries is in:

- `test/core/analytics/privacy_analytics_service_test.dart`
- `test/core/analytics/analytics_receiver_test.dart`
