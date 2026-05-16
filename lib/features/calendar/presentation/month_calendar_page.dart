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
    final eventsAsync = ref.watch(eventsInRangeProvider(_monthRangeFor(month)));
    final wide = MediaQuery.sizeOf(context).width >= 880;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CalendarHeader(month: month, selectedDate: selectedDate),
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        Expanded(
                          child: _MonthPageView(
                            month: month,
                            selectedDate: selectedDate,
                            onMonthDelta: (delta) =>
                                _moveMonth(ref, month, selectedDate, delta),
                            onDateSelected: (date, events) {
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
                          child: eventsAsync.when(
                            data: (events) => EventDetailsPanel(
                              date: selectedDate,
                              events: _eventsForDay(events, selectedDate),
                            ),
                            error: (error, stackTrace) =>
                                Center(child: Text('$error')),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _MonthPageView(
                      month: month,
                      selectedDate: selectedDate,
                      onMonthDelta: (delta) =>
                          _moveMonth(ref, month, selectedDate, delta),
                      onDateSelected: (date, events) {
                        ref.read(selectedDateProvider.notifier).state = date;
                        _showDaySheet(
                          context,
                          date,
                          _eventsForDay(events, date),
                        );
                      },
                    ),
            ),
            const ChatInputBar(),
          ],
        ),
      ),
    );
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

  void _moveMonth(
    WidgetRef ref,
    DateTime currentMonth,
    DateTime selectedDate,
    int delta,
  ) {
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + delta);
    final lastDay = DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month);
    final selectedDay = selectedDate.day > lastDay ? lastDay : selectedDate.day;

    ref.read(visibleMonthProvider.notifier).state = nextMonth;
    ref.read(selectedDateProvider.notifier).state = DateTime(
      nextMonth.year,
      nextMonth.month,
      selectedDay,
    );
  }
}

class _MonthPageView extends StatefulWidget {
  const _MonthPageView({
    required this.month,
    required this.selectedDate,
    required this.onMonthDelta,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final ValueChanged<int> onMonthDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  State<_MonthPageView> createState() => _MonthPageViewState();
}

class _MonthPageViewState extends State<_MonthPageView> {
  late final PageController _controller;
  var _resettingPage = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 1);
  }

  @override
  void didUpdateWidget(covariant _MonthPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameMonth(oldWidget.month, widget.month) || !_controller.hasClients) {
      return;
    }
    _resettingPage = true;
    _controller.jumpToPage(1);
    _resettingPage = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: 3,
      onPageChanged: (index) {
        if (_resettingPage || index == 1) {
          return;
        }
        widget.onMonthDelta(index - 1);
      },
      itemBuilder: (context, index) {
        final pageMonth = DateTime(
          widget.month.year,
          widget.month.month + index - 1,
        );
        return _CalendarMonthPage(
          month: pageMonth,
          selectedDate: widget.selectedDate,
          onDateSelected: widget.onDateSelected,
        );
      },
    );
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}

class _CalendarMonthPage extends ConsumerWidget {
  const _CalendarMonthPage({
    required this.month,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsInRangeProvider(_monthRangeFor(month)));

    return eventsAsync.when(
      data: (events) => CalendarMonthGrid(
        month: month,
        selectedDate: selectedDate,
        events: events,
        onDateSelected: (date) {
          onDateSelected(date, _eventsForDay(events, date));
        },
      ),
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => CalendarMonthGrid(
        month: month,
        selectedDate: selectedDate,
        events: const [],
        onDateSelected: (date) {
          onDateSelected(date, const <CalendarEvent>[]);
        },
      ),
    );
  }
}

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader({required this.month, required this.selectedDate});

  final DateTime month;
  final DateTime selectedDate;

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
            tooltip: '이전 월',
            onPressed: () => _moveMonth(ref, -1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: '다음 월',
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
    final nextMonth = DateTime(month.year, month.month + delta);
    final lastDay = DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month);
    final selectedDay = selectedDate.day > lastDay ? lastDay : selectedDate.day;

    ref.read(visibleMonthProvider.notifier).state = nextMonth;
    ref.read(selectedDateProvider.notifier).state = DateTime(
      nextMonth.year,
      nextMonth.month,
      selectedDay,
    );
  }
}

CalendarRange _monthRangeFor(DateTime month) {
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
