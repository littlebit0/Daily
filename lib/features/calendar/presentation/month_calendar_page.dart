import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../chat/presentation/chat_input_bar.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import '../../events/domain/event_draft.dart';
import '../../events/presentation/event_details_panel.dart';
import '../../events/presentation/event_editor_dialog.dart';
import '../../search/presentation/search_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../widgets/calendar_month_grid.dart';

class MonthCalendarPage extends ConsumerWidget {
  const MonthCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final month = ref.watch(visibleMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final eventsAsync = ref.watch(
      eventsInRangeProvider(_monthRangeFor(month, settings.weekStartsOnMonday)),
    );
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
                            weekStartsOnMonday: settings.weekStartsOnMonday,
                            showLunarDates: settings.showLunarDates,
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
                            color: Colors.white,
                            border: Border(
                              left: BorderSide(color: Color(0xffedf0f5)),
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
                      weekStartsOnMonday: settings.weekStartsOnMonday,
                      showLunarDates: settings.showLunarDates,
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
    _setVisibleMonth(
      ref,
      DateTime(currentMonth.year, currentMonth.month + delta),
      selectedDate,
    );
  }
}

class _MonthPageView extends StatefulWidget {
  const _MonthPageView({
    required this.month,
    required this.selectedDate,
    required this.weekStartsOnMonday,
    required this.showLunarDates,
    required this.onMonthDelta,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
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
          weekStartsOnMonday: widget.weekStartsOnMonday,
          showLunarDates: widget.showLunarDates,
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
    required this.weekStartsOnMonday,
    required this.showLunarDates,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final eventsAsync = ref.watch(
      eventsInRangeProvider(_monthRangeFor(month, weekStartsOnMonday)),
    );

    return eventsAsync.when(
      data: (events) => CalendarMonthGrid(
        month: month,
        selectedDate: selectedDate,
        events: events,
        weekStartsOnMonday: weekStartsOnMonday,
        showLunarDates: showLunarDates,
        onDateSelected: (date) {
          onDateSelected(date, _eventsForDay(events, date));
        },
        onDateRangeSelected: (start, end) => _addEventForRange(
          context,
          ref,
          start,
          end,
          settings.categories,
          settings.defaultReminderMinutes,
        ),
      ),
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => CalendarMonthGrid(
        month: month,
        selectedDate: selectedDate,
        events: const [],
        weekStartsOnMonday: weekStartsOnMonday,
        showLunarDates: showLunarDates,
        onDateSelected: (date) {
          onDateSelected(date, const <CalendarEvent>[]);
        },
        onDateRangeSelected: (start, end) => _addEventForRange(
          context,
          ref,
          start,
          end,
          settings.categories,
          settings.defaultReminderMinutes,
        ),
      ),
    );
  }

  Future<void> _addEventForRange(
    BuildContext context,
    WidgetRef ref,
    DateTime start,
    DateTime end,
    List<EventCategory> categories,
    int defaultReminderMinutes,
  ) async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialDate: start,
        initialEndDate: end,
        initialAllDay: true,
        categories: categories,
        defaultReminderMinutes: defaultReminderMinutes,
      ),
    );
    if (draft != null) {
      await ref.read(eventCommandServiceProvider).create(draft);
    }
  }
}

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader({required this.month, required this.selectedDate});

  final DateTime month;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = '${month.year}년 ${month.month}월';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _showMonthPicker(context, ref),
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
            label: Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xff111827),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
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
            onPressed: () => _goToday(ref),
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

  Future<void> _showMonthPicker(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initialMonth: month),
    );
    if (picked == null) {
      return;
    }
    _setVisibleMonth(ref, picked, selectedDate);
  }

  void _moveMonth(WidgetRef ref, int delta) {
    _setVisibleMonth(
      ref,
      DateTime(month.year, month.month + delta),
      selectedDate,
    );
  }

  void _goToday(WidgetRef ref) {
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
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
    _month = widget.initialMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('연월 선택'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '10년 전',
                  onPressed: () => setState(() => _year -= 10),
                  icon: const Icon(Icons.keyboard_double_arrow_left),
                ),
                IconButton(
                  tooltip: '1년 전',
                  onPressed: () => setState(() => _year -= 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_year년',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '1년 후',
                  onPressed: () => setState(() => _year += 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: '10년 후',
                  onPressed: () => setState(() => _year += 10),
                  icon: const Icon(Icons.keyboard_double_arrow_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final value = index + 1;
                final selected = value == _month;
                return FilledButton.tonal(
                  onPressed: () => setState(() => _month = value),
                  style: FilledButton.styleFrom(
                    backgroundColor: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : const Color(0xfff3f6fb),
                    foregroundColor: selected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : const Color(0xff1f2937),
                  ),
                  child: Text('$value월'),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(DateTime(_year, _month)),
          child: const Text('이동'),
        ),
      ],
    );
  }
}

void _setVisibleMonth(
  WidgetRef ref,
  DateTime nextMonth,
  DateTime selectedDate,
) {
  final month = DateTime(nextMonth.year, nextMonth.month);
  final lastDay = DateUtils.getDaysInMonth(month.year, month.month);
  final selectedDay = selectedDate.day > lastDay ? lastDay : selectedDate.day;

  ref.read(visibleMonthProvider.notifier).state = month;
  ref.read(selectedDateProvider.notifier).state = DateTime(
    month.year,
    month.month,
    selectedDay,
  );
}

CalendarRange _monthRangeFor(DateTime month, bool weekStartsOnMonday) {
  final first = DateTime(month.year, month.month);
  final leadingDays = weekStartsOnMonday
      ? first.weekday - 1
      : first.weekday % 7;
  final gridStart = first.subtract(Duration(days: leadingDays));
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
