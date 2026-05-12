import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../chat/presentation/chat_input_bar.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/presentation/event_details_panel.dart';
import '../../search/presentation/search_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../widgets/calendar_month_grid.dart';

class MonthCalendarPage extends ConsumerWidget {
  const MonthCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(visibleMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final range = _monthRange(month);
    final eventsAsync = ref.watch(eventsInRangeProvider(range));
    final wide = MediaQuery.sizeOf(context).width >= 880;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CalendarHeader(month: month),
            Expanded(
              child: eventsAsync.when(
                data: (events) => wide
                    ? Row(
                        children: [
                          Expanded(
                            child: CalendarMonthGrid(
                              month: month,
                              selectedDate: selectedDate,
                              events: events,
                              onDateSelected: (date) {
                                ref.read(selectedDateProvider.notifier).state =
                                    date;
                              },
                            ),
                          ),
                          Container(
                            width: 360,
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Color(0xffd8dce3)),
                              ),
                            ),
                            child: EventDetailsPanel(
                              date: selectedDate,
                              events: _eventsForDay(events, selectedDate),
                            ),
                          ),
                        ],
                      )
                    : CalendarMonthGrid(
                        month: month,
                        selectedDate: selectedDate,
                        events: events,
                        onDateSelected: (date) {
                          ref.read(selectedDateProvider.notifier).state = date;
                          _showDaySheet(
                            context,
                            date,
                            _eventsForDay(events, date),
                          );
                        },
                      ),
                error: (error, stackTrace) => Center(child: Text('$error')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
            const ChatInputBar(),
          ],
        ),
      ),
    );
  }

  CalendarRange _monthRange(DateTime month) {
    final first = DateTime(month.year, month.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    return CalendarRange(gridStart, gridStart.add(const Duration(days: 42)));
  }

  List<CalendarEvent> _eventsForDay(List<CalendarEvent> events, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return events
        .where(
          (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  void _showDaySheet(
    BuildContext context,
    DateTime date,
    List<CalendarEvent> events,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.68,
        child: EventDetailsPanel(date: date, events: events),
      ),
    );
  }
}

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = DateFormat('yyyy년 M월').format(month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.headlineMedium),
          const Spacer(),
          IconButton(
            tooltip: '이전 달',
            onPressed: () => _moveMonth(ref, -1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: '다음 달',
            onPressed: () => _moveMonth(ref, 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: '오늘',
            onPressed: () {
              final now = DateTime.now();
              ref.read(visibleMonthProvider.notifier).state = DateTime(
                now.year,
                now.month,
              );
              ref.read(selectedDateProvider.notifier).state = DateTime(
                now.year,
                now.month,
                now.day,
              );
            },
            icon: const Icon(Icons.today_outlined),
          ),
          IconButton(
            tooltip: '검색',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: '설정',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  void _moveMonth(WidgetRef ref, int delta) {
    ref.read(visibleMonthProvider.notifier).state = DateTime(
      month.year,
      month.month + delta,
    );
  }
}
