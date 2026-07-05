import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows missing title validation inside the event dialog', (
    tester,
  ) async {
    EventDraft? savedDraft;
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) =>
            EventEditorDialog(initialDate: DateTime(2026, 5, 28)),
        onSaved: (draft) => savedDraft = draft,
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('제목을 입력해야 일정을 저장할 수 있습니다.'), findsOneWidget);
    expect(find.text('제목을 입력하세요.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(savedDraft, isNull);
  });

  testWidgets('shows invalid time validation inside the event dialog', (
    tester,
  ) async {
    EventDraft? savedDraft;
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) => EventEditorDialog(
          initialDate: DateTime(2026, 5, 28, 10),
          event: _eventWithEndBeforeStart(),
        ),
        onSaved: (draft) => savedDraft = draft,
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('종료 시간은 시작 시간보다 늦어야 합니다.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(savedDraft, isNull);
  });

  testWidgets('keeps number picker open when recurrence input is invalid', (
    tester,
  ) async {
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) =>
            EventEditorDialog(initialDate: DateTime(2026, 5, 28)),
        onSaved: (_) {},
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('반복 없음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('반복 없음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('매일').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('1일마다'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1일마다'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(find.text('반복 간격'), findsWidgets);
    expect(find.text('1 이상의 숫자를 입력하세요.'), findsOneWidget);
  });

  testWidgets('saves multiple selected reminders from the event dialog', (
    tester,
  ) async {
    EventDraft? savedDraft;
    await tester.pumpWidget(
      _DialogHost(
        builder: (context) => EventEditorDialog(
          initialDate: DateTime(2026, 5, 28, 10),
          defaultReminderMinutes: 60,
        ),
        onSaved: (draft) => savedDraft = draft,
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '복수 알림 일정');
    await tester.ensureVisible(find.text('10분 전'));
    await tester.tap(find.text('10분 전'));
    await tester.tap(find.text('30분 전'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(savedDraft, isNotNull);
    expect(savedDraft!.reminderMinutesBeforeList, [10, 30, 60]);
  });
}

class _DialogHost extends StatelessWidget {
  const _DialogHost({required this.builder, required this.onSaved});

  final WidgetBuilder builder;
  final ValueChanged<EventDraft> onSaved;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final draft = await showDialog<EventDraft>(
                  context: context,
                  builder: builder,
                );
                if (draft != null) {
                  onSaved(draft);
                }
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
  }
}

CalendarEvent _eventWithEndBeforeStart() {
  final start = DateTime(2026, 5, 28, 10);
  return CalendarEvent(
    id: 'event-1',
    title: '회의',
    startAt: start,
    endAt: DateTime(2026, 5, 28, 9),
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: start,
    updatedAt: start,
  );
}
