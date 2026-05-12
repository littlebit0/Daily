import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../../features/events/domain/event_repository.dart';
import '../../features/events/domain/recurrence_rule.dart';
import '../firebase/firebase_app_service.dart';
import '../firebase/firebase_auth_service.dart';
import '../notifications/notification_service.dart';
import 'sync_service.dart';

class FirestoreSyncService implements SyncService {
  FirestoreSyncService({
    required FirebaseAppService firebaseAppService,
    required FirebaseAuthService authService,
    required EventRepository eventRepository,
    required NotificationService notificationService,
    FirebaseFirestore? firestore,
  }) : _firebaseAppService = firebaseAppService,
       _authService = authService,
       _eventRepository = eventRepository,
       _notificationService = notificationService,
       _firestore = firestore;

  final FirebaseAppService _firebaseAppService;
  final FirebaseAuthService _authService;
  final EventRepository _eventRepository;
  final NotificationService _notificationService;
  final FirebaseFirestore? _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<Object?>? _authSubscription;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> start() async {
    final initialized = await _firebaseAppService.initialize();
    if (!initialized) {
      return;
    }

    await _subscription?.cancel();
    await _authSubscription?.cancel();
    _authSubscription = _authService.authStateChanges().listen((user) async {
      await _subscription?.cancel();
      if (user == null) {
        return;
      }

      await _flushPending(user.uid);
      _subscription = _eventsCollection(
        user.uid,
      ).snapshots().listen(_applyRemoteSnapshot);
    });
  }

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {
    final initialized = await _firebaseAppService.initialize();
    final user = _authService.currentUser;
    if (!initialized || user == null) {
      return;
    }

    await _eventsCollection(user.uid).doc(event.id).set(_toFirestore(event));
    await _eventRepository.markSynced(event.id);
  }

  @override
  Future<void> queueEventDelete(String eventId) async {
    final initialized = await _firebaseAppService.initialize();
    final user = _authService.currentUser;
    if (!initialized || user == null) {
      return;
    }

    await _eventsCollection(user.uid).doc(eventId).delete();
    await _eventRepository.hardDelete(eventId);
  }

  CollectionReference<Map<String, dynamic>> _eventsCollection(String userId) {
    return _db.collection('users').doc(userId).collection('events');
  }

  Future<void> _flushPending(String userId) async {
    final pending = await _eventRepository.pendingSyncEvents();
    for (final event in pending) {
      if (event.deletedAt != null || event.syncStatus == 'pending_delete') {
        await _eventsCollection(userId).doc(event.id).delete();
        await _eventRepository.hardDelete(event.id);
        continue;
      }

      await _eventsCollection(userId).doc(event.id).set(_toFirestore(event));
      await _eventRepository.markSynced(event.id);
    }
  }

  Future<void> _applyRemoteSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await _eventRepository.hardDelete(change.doc.id);
        await _notificationService.cancelEventReminder(change.doc.id);
        continue;
      }

      final event = _fromFirestore(change.doc.id, change.doc.data());
      if (event == null) {
        continue;
      }

      final synced = event.copyWith(syncStatus: 'synced');
      await _eventRepository.save(synced);
      await _notificationService.cancelEventReminder(synced.id);
      await _notificationService.scheduleEventReminder(synced);
    }
  }

  Map<String, Object?> _toFirestore(CalendarEvent event) {
    return {
      'title': event.title,
      'memo': event.memo,
      'location': event.location,
      'startAt': Timestamp.fromDate(event.startAt.toUtc()),
      'endAt': Timestamp.fromDate(event.endAt.toUtc()),
      'allDay': event.allDay,
      'category': event.category.name,
      'colorValue': event.colorValue,
      'reminderMinutesBefore': event.reminderMinutesBefore,
      'recurrenceFrequency': event.recurrence.frequency.name,
      'recurrenceInterval': event.recurrence.interval,
      'recurrenceUntil': event.recurrence.until == null
          ? null
          : Timestamp.fromDate(event.recurrence.until!.toUtc()),
      'recurrenceCount': event.recurrence.count,
      'createdAt': Timestamp.fromDate(event.createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(event.updatedAt.toUtc()),
      'deletedAt': event.deletedAt == null
          ? null
          : Timestamp.fromDate(event.deletedAt!.toUtc()),
      'deviceId': event.deviceId,
    };
  }

  CalendarEvent? _fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }

    final startAt = _readDate(data['startAt']);
    final endAt = _readDate(data['endAt']);
    final createdAt = _readDate(data['createdAt']);
    final updatedAt = _readDate(data['updatedAt']);
    if (startAt == null ||
        endAt == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    final category = EventCategory.fromName(data['category'] as String?);
    return CalendarEvent(
      id: id,
      title: data['title'] as String? ?? 'New event',
      memo: data['memo'] as String?,
      location: data['location'] as String?,
      startAt: startAt,
      endAt: endAt,
      allDay: data['allDay'] as bool? ?? false,
      category: category,
      colorValue: data['colorValue'] as int? ?? category.colorValue,
      reminderMinutesBefore: data['reminderMinutesBefore'] as int?,
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.fromName(
          data['recurrenceFrequency'] as String?,
        ),
        interval: data['recurrenceInterval'] as int? ?? 1,
        until: _readDate(data['recurrenceUntil']),
        count: data['recurrenceCount'] as int?,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: _readDate(data['deletedAt']),
      deviceId: data['deviceId'] as String? ?? '',
      syncStatus: 'synced',
    );
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
