import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../chat/presentation/chat_input_bar.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import '../../events/domain/event_draft.dart';
import '../../events/presentation/event_details_panel.dart';
import '../../events/presentation/event_editor_dialog.dart';
import '../../events/presentation/sensitive_event_access.dart';
import '../../settings/presentation/settings_page.dart';
import '../widgets/calendar_month_grid.dart';

class MonthCalendarPage extends ConsumerStatefulWidget {
  const MonthCalendarPage({super.key});

  @override
  ConsumerState<MonthCalendarPage> createState() => _MonthCalendarPageState();
}

class _MonthCalendarPageState extends ConsumerState<MonthCalendarPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  Future<List<CalendarEvent>>? _searchResults;
  var _searchOpen = false;
  var _quickAccessSelected = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storedSettings = ref.watch(appSettingsProvider);
    final sensitiveEventsUnlocked = ref.watch(sensitiveEventsUnlockedProvider);
    final settings = storedSettings.copyWith(
      hideSensitiveEvents: !sensitiveEventsUnlocked,
    );
    final month = ref.watch(visibleMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(calendarViewModeProvider);
    final searchQuery = ref.watch(calendarSearchQueryProvider);
    final range = switch (viewMode) {
      CalendarViewMode.week => _weekRangeFor(
        selectedDate,
        settings.weekStartsOnMonday,
      ),
      CalendarViewMode.month => _monthRangeFor(
        month,
        settings.weekStartsOnMonday,
      ),
      CalendarViewMode.day => _dayRangeFor(selectedDate),
    };
    final eventsAsync = ref.watch(eventsInRangeProvider(range));
    final wide = MediaQuery.sizeOf(context).width >= 880;
    final macOS = Theme.of(context).platform == TargetPlatform.macOS;

    return Scaffold(
      body: SafeArea(
        bottom: macOS,
        child: Column(
          children: [
            if (macOS || !_quickAccessSelected)
              _CalendarHeader(
                month: month,
                selectedDate: selectedDate,
                viewMode: viewMode,
                searchQuery: searchQuery,
                searchOpen: _searchOpen,
                quickAccessSelected: _quickAccessSelected,
                onSearchPressed: _toggleSearch,
                onQuickAccessPressed: () {
                  _closeSearch();
                  setState(() => _quickAccessSelected = true);
                },
                onCalendarViewSelected: _selectCalendarView,
                onLlmPressed: () => _showLlmSheet(context),
              ),
            if (_quickAccessSelected)
              Expanded(
                child: _buildQuickAccessPage(
                  context,
                  ref,
                  settings,
                  searchQuery,
                  month,
                ),
              )
            else ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _searchOpen
                    ? _InlineSearchPanel(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        results: _searchResults,
                        hideSensitiveEvents: settings.hideSensitiveEvents,
                        onChanged: _handleSearchChanged,
                        onSubmitted: _runSearch,
                        onClose: _closeSearch,
                        onEventSelected: _selectSearchResult,
                      )
                    : const SizedBox(width: double.infinity),
              ),
              Expanded(
                child: viewMode == CalendarViewMode.day
                    ? _CalendarMainContent(
                        month: month,
                        selectedDate: selectedDate,
                        viewMode: viewMode,
                        settings: settings,
                        searchQuery: searchQuery,
                        onMonthDelta: (delta) => _moveVisibleRange(
                          ref,
                          viewMode,
                          month,
                          selectedDate,
                          delta,
                        ),
                        onDateSelected: (date, events) {
                          ref.read(selectedDateProvider.notifier).state = date;
                        },
                      )
                    : wide
                    ? Row(
                        children: [
                          Expanded(
                            child: _CalendarMainContent(
                              month: month,
                              selectedDate: selectedDate,
                              viewMode: viewMode,
                              settings: settings,
                              searchQuery: searchQuery,
                              onMonthDelta: (delta) => _moveVisibleRange(
                                ref,
                                viewMode,
                                month,
                                selectedDate,
                                delta,
                              ),
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
                            child: _MonthDetailsPanel(
                              eventsAsync: eventsAsync,
                              settings: settings,
                              searchQuery: searchQuery,
                              selectedDate: selectedDate,
                            ),
                          ),
                        ],
                      )
                    : _CalendarMainContent(
                        month: month,
                        selectedDate: selectedDate,
                        viewMode: viewMode,
                        settings: settings,
                        searchQuery: searchQuery,
                        onMonthDelta: (delta) => _moveVisibleRange(
                          ref,
                          viewMode,
                          month,
                          selectedDate,
                          delta,
                        ),
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
            ],
            if (!macOS)
              _CalendarBottomBar(
                viewMode: viewMode,
                quickAccessSelected: _quickAccessSelected,
                onQuickAccessPressed: () {
                  _closeSearch();
                  setState(() => _quickAccessSelected = true);
                },
                onCalendarViewSelected: _selectCalendarView,
                onLlmPressed: () => _showLlmSheet(context),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchOpen = false;
      _searchResults = null;
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      _runSearch();
    });
  }

  void _runSearch() {
    final query = _searchController.text.trim();
    setState(() {
      _searchResults = query.isEmpty
          ? null
          : ref.read(eventRepositoryProvider).search(query);
    });
  }

  void _selectSearchResult(CalendarEvent event) {
    ref.read(visibleMonthProvider.notifier).state = DateTime(
      event.startAt.year,
      event.startAt.month,
    );
    ref.read(selectedDateProvider.notifier).state = DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
    _closeSearch();
  }

  void _selectCalendarView(CalendarViewMode viewMode) {
    ref.read(calendarViewModeProvider.notifier).state = viewMode;
    if (_quickAccessSelected) {
      setState(() => _quickAccessSelected = false);
    }
  }

  void _showLlmSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const ChatInputBar(),
      ),
    );
  }

  Widget _buildQuickAccessPage(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    String query,
    DateTime currentMonth,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = _monthRangeFor(currentMonth, settings.weekStartsOnMonday);
    final eventsAsync = ref.watch(eventsInRangeProvider(range));

    return ColoredBox(
      color: const Color(0xfff8fafc),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: eventsAsync.when(
          data: (events) {
            final visibleEvents = _filterVisibleEvents(events, settings, query);
            final todayEvents = _eventsForDay(visibleEvents, today);
            final ddayEvents =
                visibleEvents.where((event) => event.showDday).toList()
                  ..sort((a, b) => a.startAt.compareTo(b.startAt));
            return ListView(
              children: [
                Text(
                  '빠른 보기',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _QuickAccessCard(
                  icon: Icons.calendar_month_outlined,
                  title: '월간 미니 캘린더',
                  subtitle: '${currentMonth.year}년 ${currentMonth.month}월',
                  items: _monthSummary(visibleEvents),
                  onTap: () => _selectCalendarView(CalendarViewMode.month),
                ),
                const SizedBox(height: 10),
                _QuickAccessCard(
                  icon: Icons.today_outlined,
                  title: '오늘 일정',
                  subtitle: '${today.month}월 ${today.day}일',
                  items: todayEvents.isEmpty
                      ? const ['일정 없음']
                      : todayEvents
                            .take(4)
                            .map((event) => _eventPreview(event, settings))
                            .toList(),
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).state = today;
                    ref.read(visibleMonthProvider.notifier).state = DateTime(
                      today.year,
                      today.month,
                    );
                    _selectCalendarView(CalendarViewMode.day);
                  },
                ),
                const SizedBox(height: 10),
                _QuickAccessCard(
                  icon: Icons.flag_outlined,
                  title: 'D-day',
                  subtitle: '중요한 날짜',
                  items: ddayEvents.isEmpty
                      ? const ['D-day 일정 없음']
                      : ddayEvents
                            .take(4)
                            .map((event) => _eventPreview(event, settings))
                            .toList(),
                  onTap: () async {
                    final updated = settings.copyWith(calendarDdayOnly: true);
                    await ref.read(settingsRepositoryProvider).save(updated);
                    if (!context.mounted) {
                      return;
                    }
                    ref.read(appSettingsProvider.notifier).state = updated;
                    _selectCalendarView(CalendarViewMode.month);
                  },
                ),
              ],
            );
          },
          error: (error, stackTrace) => Text('$error'),
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  List<String> _monthSummary(List<CalendarEvent> events) {
    final normalCount = events.where((event) => !event.holiday).length;
    final ddayCount = events.where((event) => event.showDday).length;
    return [
      '일정 $normalCount개',
      'D-day $ddayCount개',
      '공휴일 ${events.where((event) => event.holiday).length}개',
    ];
  }

  String _eventPreview(CalendarEvent event, AppSettings settings) {
    final hidden = settings.hideSensitiveEvents && event.sensitive;
    final title = hidden ? '비공개 일정' : event.title;
    if (hidden) {
      return title;
    }
    if (event.allDay) {
      return title;
    }
    return '$title  ${DateFormat('HH:mm').format(event.startAt)}';
  }

  void _showDaySheet(
    BuildContext context,
    DateTime date,
    List<CalendarEvent> events,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        minChildSize: 0.4,
        maxChildSize: 0.96,
        snap: true,
        snapSizes: const [0.68],
        builder: (context, scrollController) => EventDetailsPanel(
          date: date,
          events: events,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _moveVisibleRange(
    WidgetRef ref,
    CalendarViewMode viewMode,
    DateTime currentMonth,
    DateTime selectedDate,
    int delta,
  ) {
    switch (viewMode) {
      case CalendarViewMode.month:
        _setVisibleMonth(
          ref,
          DateTime(currentMonth.year, currentMonth.month + delta),
          selectedDate,
        );
      case CalendarViewMode.week:
        final next = selectedDate.add(Duration(days: delta * 7));
        ref.read(selectedDateProvider.notifier).state = next;
        ref.read(visibleMonthProvider.notifier).state = DateTime(
          next.year,
          next.month,
        );
      case CalendarViewMode.day:
        final next = selectedDate.add(Duration(days: delta));
        ref.read(selectedDateProvider.notifier).state = next;
        ref.read(visibleMonthProvider.notifier).state = DateTime(
          next.year,
          next.month,
        );
    }
  }
}

class _InlineSearchPanel extends StatelessWidget {
  const _InlineSearchPanel({
    required this.controller,
    required this.focusNode,
    required this.results,
    required this.hideSensitiveEvents,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
    required this.onEventSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<List<CalendarEvent>>? results;
  final bool hideSensitiveEvents;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClose;
  final ValueChanged<CalendarEvent> onEventSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffedf0f5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              hintText: '제목, 메모, 장소 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '검색',
                    onPressed: onSubmitted,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          FutureBuilder<List<CalendarEvent>>(
            future: results,
            builder: (context, snapshot) {
              if (results == null) {
                return const SizedBox.shrink();
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              final events = snapshot.data ?? const <CalendarEvent>[];
              if (events.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '검색 결과가 없습니다.',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 10),
                  itemBuilder: (context, index) => _InlineSearchResultTile(
                    event: events[index],
                    hideSensitive: hideSensitiveEvents,
                    onTap: () => onEventSelected(events[index]),
                  ),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: events.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InlineSearchResultTile extends StatelessWidget {
  const _InlineSearchResultTile({
    required this.event,
    required this.hideSensitive,
    required this.onTap,
  });

  final CalendarEvent event;
  final bool hideSensitive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy년 M월 d일').format(event.startAt);
    final hidden = hideSensitive && event.sensitive;
    final time = event.allDay
        ? '종일'
        : DateFormat('HH:mm').format(event.startAt);
    return ListTile(
      dense: true,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xffedf0f5)),
      ),
      leading: CircleAvatar(
        backgroundColor: hidden
            ? const Color(0xffeef0f3)
            : Color(event.colorValue).withValues(alpha: 0.12),
        child: Icon(
          hidden ? Icons.lock_outline : Icons.flag,
          color: hidden ? const Color(0xff64748b) : Color(event.colorValue),
        ),
      ),
      title: Text(
        hidden ? '비공개 일정' : event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(hidden ? date : '$date  $time'),
    );
  }
}

class _MonthDetailsPanel extends StatelessWidget {
  const _MonthDetailsPanel({
    required this.eventsAsync,
    required this.settings,
    required this.searchQuery,
    required this.selectedDate,
  });

  final AsyncValue<List<CalendarEvent>> eventsAsync;
  final AppSettings settings;
  final String searchQuery;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    return eventsAsync.when(
      data: _buildPanel,
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => EventDetailsPanel(
        date: selectedDate,
        events: const <CalendarEvent>[],
      ),
    );
  }

  Widget _buildPanel(List<CalendarEvent> events) {
    return EventDetailsPanel(
      date: selectedDate,
      events: _eventsForDay(
        _filterVisibleEvents(events, settings, searchQuery),
        selectedDate,
      ),
    );
  }
}

class _CalendarMainContent extends StatelessWidget {
  const _CalendarMainContent({
    required this.month,
    required this.selectedDate,
    required this.viewMode,
    required this.settings,
    required this.searchQuery,
    required this.onMonthDelta,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final AppSettings settings;
  final String searchQuery;
  final ValueChanged<int> onMonthDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  Widget build(BuildContext context) {
    return switch (viewMode) {
      CalendarViewMode.month => _MonthPageView(
        month: month,
        selectedDate: selectedDate,
        settings: settings,
        searchQuery: searchQuery,
        onMonthDelta: onMonthDelta,
        onDateSelected: onDateSelected,
      ),
      CalendarViewMode.week => _WeekPageView(
        selectedDate: selectedDate,
        settings: settings,
        searchQuery: searchQuery,
        onWeekDelta: onMonthDelta,
        onDateSelected: onDateSelected,
      ),
      CalendarViewMode.day => _DayPageView(
        selectedDate: selectedDate,
        settings: settings,
        searchQuery: searchQuery,
        onDayDelta: onMonthDelta,
      ),
    };
  }
}

class _WeekPageView extends StatefulWidget {
  const _WeekPageView({
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onWeekDelta,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final ValueChanged<int> onWeekDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  State<_WeekPageView> createState() => _WeekPageViewState();
}

class _WeekPageViewState extends State<_WeekPageView> {
  static const _initialPage = 12000;

  late final PageController _controller;
  late final DateTime _anchorDate;
  var _currentPage = _initialPage;
  var _applyingExternalDate = false;
  var _externalAnimationRevision = 0;
  DateTime? _lastPointerWeekMoveAt;

  @override
  void initState() {
    super.initState();
    _anchorDate = _dateOnly(widget.selectedDate);
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _WeekPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.hasClients) {
      return;
    }
    final targetPage =
        _initialPage + _weekDelta(_anchorDate, widget.selectedDate);
    if (targetPage == _currentPage) {
      return;
    }
    _animateToExternalPage(targetPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey('week-pointer-navigation'),
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: PageView.builder(
        controller: _controller,
        allowImplicitScrolling: true,
        physics: const _ResponsiveMonthPagePhysics(),
        onPageChanged: (index) {
          if (_applyingExternalDate || index == _currentPage) {
            return;
          }
          final delta = index - _currentPage;
          _currentPage = index;
          widget.onWeekDelta(delta);
        },
        itemBuilder: (context, index) {
          final pageDate = _anchorDate.add(
            Duration(days: (index - _initialPage) * 7),
          );
          return _CalendarWeekPage(
            selectedDate: pageDate,
            settings: widget.settings,
            searchQuery: widget.searchQuery,
            onDateSelected: widget.onDateSelected,
          );
        },
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_isMacHorizontalPageScroll(context, event) ||
        !_controller.hasClients) {
      return;
    }
    final now = DateTime.now();
    final lastMoveAt = _lastPointerWeekMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerWeekMoveAt = now;
    final scroll = event as PointerScrollEvent;
    final nextPage = _currentPage + (scroll.scrollDelta.dx > 0 ? 1 : -1);
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
    final revision = ++_externalAnimationRevision;
    _applyingExternalDate = true;
    _currentPage = targetPage;
    unawaited(
      _controller
          .animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && revision == _externalAnimationRevision) {
              _applyingExternalDate = false;
            }
          }),
    );
  }

  int _weekDelta(DateTime from, DateTime to) {
    final fromStart = _weekRangeFor(
      from,
      widget.settings.weekStartsOnMonday,
    ).start;
    final toStart = _weekRangeFor(to, widget.settings.weekStartsOnMonday).start;
    return toStart.difference(fromStart).inDays ~/ 7;
  }
}

class _CalendarWeekPage extends ConsumerWidget {
  const _CalendarWeekPage({
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _weekRangeFor(selectedDate, settings.weekStartsOnMonday);
    final eventsAsync = ref.watch(eventsInRangeProvider(range));
    return eventsAsync.when(
      data: (events) => _CalendarWeekView(
        selectedDate: selectedDate,
        weekStartsOnMonday: settings.weekStartsOnMonday,
        showLunarDates: settings.showLunarDates,
        hideSensitiveEvents: settings.hideSensitiveEvents,
        events: _filterVisibleEvents(events, settings, searchQuery),
        onDateSelected: onDateSelected,
      ),
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DayPageView extends StatefulWidget {
  const _DayPageView({
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onDayDelta,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final ValueChanged<int> onDayDelta;

  @override
  State<_DayPageView> createState() => _DayPageViewState();
}

class _DayPageViewState extends State<_DayPageView> {
  static const _initialPage = 12000;

  late final PageController _controller;
  late final DateTime _anchorDate;
  var _currentPage = _initialPage;
  var _applyingExternalDate = false;
  var _externalAnimationRevision = 0;
  DateTime? _lastPointerDayMoveAt;

  @override
  void initState() {
    super.initState();
    _anchorDate = _dateOnly(widget.selectedDate);
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _DayPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.hasClients) {
      return;
    }
    final targetPage =
        _initialPage + _dayDelta(_anchorDate, widget.selectedDate);
    if (targetPage == _currentPage) {
      return;
    }
    _animateToExternalPage(targetPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey('day-pointer-navigation'),
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: PageView.builder(
        controller: _controller,
        allowImplicitScrolling: true,
        physics: const _ResponsiveMonthPagePhysics(),
        onPageChanged: (index) {
          if (_applyingExternalDate || index == _currentPage) {
            return;
          }
          final delta = index - _currentPage;
          _currentPage = index;
          widget.onDayDelta(delta);
        },
        itemBuilder: (context, index) {
          final pageDate = _anchorDate.add(
            Duration(days: index - _initialPage),
          );
          return _CalendarDayPage(
            date: pageDate,
            settings: widget.settings,
            searchQuery: widget.searchQuery,
          );
        },
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_isMacHorizontalPageScroll(context, event) ||
        !_controller.hasClients) {
      return;
    }
    final now = DateTime.now();
    final lastMoveAt = _lastPointerDayMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerDayMoveAt = now;
    final scroll = event as PointerScrollEvent;
    final nextPage = _currentPage + (scroll.scrollDelta.dx > 0 ? 1 : -1);
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
    final revision = ++_externalAnimationRevision;
    _applyingExternalDate = true;
    _currentPage = targetPage;
    unawaited(
      _controller
          .animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && revision == _externalAnimationRevision) {
              _applyingExternalDate = false;
            }
          }),
    );
  }

  int _dayDelta(DateTime from, DateTime to) {
    return _dateOnly(to).difference(_dateOnly(from)).inDays;
  }
}

class _CalendarDayPage extends ConsumerWidget {
  const _CalendarDayPage({
    required this.date,
    required this.settings,
    required this.searchQuery,
  });

  final DateTime date;
  final AppSettings settings;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsInRangeProvider(_dayRangeFor(date)));
    return eventsAsync.when(
      data: (events) => EventDetailsPanel(
        date: date,
        events: _eventsForDay(
          _filterVisibleEvents(events, settings, searchQuery),
          date,
        ),
      ),
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MonthPageView extends StatefulWidget {
  const _MonthPageView({
    required this.month,
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onMonthDelta,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final ValueChanged<int> onMonthDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  State<_MonthPageView> createState() => _MonthPageViewState();
}

class _MonthPageViewState extends State<_MonthPageView> {
  static const _initialPage = 12000;

  late final PageController _controller;
  late final DateTime _anchorMonth;
  var _currentPage = _initialPage;
  var _applyingExternalMonth = false;
  var _externalAnimationRevision = 0;
  DateTime? _lastPointerMonthMoveAt;

  @override
  void initState() {
    super.initState();
    _anchorMonth = DateTime(widget.month.year, widget.month.month);
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _MonthPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameMonth(_monthForPage(_currentPage), widget.month) ||
        !_controller.hasClients) {
      return;
    }
    final targetPage =
        _currentPage + _monthDelta(_monthForPage(_currentPage), widget.month);
    _animateToExternalPage(targetPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey('month-pointer-navigation'),
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: PageView.builder(
        controller: _controller,
        allowImplicitScrolling: true,
        physics: const _ResponsiveMonthPagePhysics(),
        onPageChanged: (index) {
          if (_applyingExternalMonth || index == _currentPage) {
            return;
          }
          final delta = index - _currentPage;
          _currentPage = index;
          widget.onMonthDelta(delta);
        },
        itemBuilder: (context, index) {
          final pageMonth = _monthForPage(index);
          return _CalendarMonthPage(
            month: pageMonth,
            selectedDate: widget.selectedDate,
            settings: widget.settings,
            searchQuery: widget.searchQuery,
            onDateSelected: widget.onDateSelected,
          );
        },
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (Theme.of(context).platform != TargetPlatform.macOS ||
        event is! PointerScrollEvent ||
        !_controller.hasClients) {
      return;
    }
    final primaryDelta =
        event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (primaryDelta.abs() < 18) {
      return;
    }
    final now = DateTime.now();
    final lastMoveAt = _lastPointerMonthMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerMonthMoveAt = now;
    final nextPage = _currentPage + (primaryDelta > 0 ? 1 : -1);
    _controller.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _animateToExternalPage(int targetPage) {
    final revision = ++_externalAnimationRevision;
    _applyingExternalMonth = true;
    _currentPage = targetPage;
    unawaited(
      _controller
          .animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && revision == _externalAnimationRevision) {
              _applyingExternalMonth = false;
            }
          }),
    );
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  DateTime _monthForPage(int page) {
    return DateTime(
      _anchorMonth.year,
      _anchorMonth.month + page - _initialPage,
    );
  }

  int _monthDelta(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + to.month - from.month;
  }
}

class _ResponsiveMonthPagePhysics extends PageScrollPhysics {
  const _ResponsiveMonthPagePhysics({super.parent});

  @override
  _ResponsiveMonthPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _ResponsiveMonthPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.75,
    stiffness: 520,
    ratio: 1.05,
  );
}

bool _isMacHorizontalPageScroll(
  BuildContext context,
  PointerSignalEvent event,
) {
  if (Theme.of(context).platform != TargetPlatform.macOS ||
      event is! PointerScrollEvent) {
    return false;
  }
  final horizontal = event.scrollDelta.dx.abs();
  final vertical = event.scrollDelta.dy.abs();
  return horizontal >= 18 && horizontal > vertical;
}

class _CalendarMonthPage extends ConsumerWidget {
  const _CalendarMonthPage({
    required this.month,
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(
      eventsInRangeProvider(_monthRangeFor(month, settings.weekStartsOnMonday)),
    );

    return eventsAsync.when(
      data: (events) {
        final visibleEvents = _filterVisibleEvents(
          events,
          settings,
          searchQuery,
        );
        return CalendarMonthGrid(
          month: month,
          selectedDate: selectedDate,
          events: visibleEvents,
          weekStartsOnMonday: settings.weekStartsOnMonday,
          showLunarDates: settings.showLunarDates,
          hideSensitiveEvents: settings.hideSensitiveEvents,
          onDateSelected: (date) {
            onDateSelected(date, _eventsForDay(visibleEvents, date));
          },
          onDateRangeSelected: (start, end) => _addEventForRange(
            context,
            ref,
            start,
            end,
            settings.categories,
            settings.defaultReminderMinutesList,
          ),
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => CalendarMonthGrid(
        month: month,
        selectedDate: selectedDate,
        events: const [],
        weekStartsOnMonday: settings.weekStartsOnMonday,
        showLunarDates: settings.showLunarDates,
        hideSensitiveEvents: settings.hideSensitiveEvents,
        onDateSelected: (date) {
          onDateSelected(date, const <CalendarEvent>[]);
        },
        onDateRangeSelected: (start, end) => _addEventForRange(
          context,
          ref,
          start,
          end,
          settings.categories,
          settings.defaultReminderMinutesList,
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
    List<int> defaultReminderMinutesList,
  ) async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialDate: start,
        initialEndDate: end,
        initialAllDay: true,
        categories: categories,
        defaultReminderMinutesList: defaultReminderMinutesList,
      ),
    );
    if (draft != null) {
      await ref.read(eventCommandServiceProvider).create(draft);
    }
  }
}

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader({
    required this.month,
    required this.selectedDate,
    required this.viewMode,
    required this.searchQuery,
    required this.searchOpen,
    required this.quickAccessSelected,
    required this.onSearchPressed,
    required this.onQuickAccessPressed,
    required this.onCalendarViewSelected,
    required this.onLlmPressed,
  });

  final DateTime month;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final String searchQuery;
  final bool searchOpen;
  final bool quickAccessSelected;
  final VoidCallback onSearchPressed;
  final VoidCallback onQuickAccessPressed;
  final ValueChanged<CalendarViewMode> onCalendarViewSelected;
  final VoidCallback onLlmPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = '${month.year}년 ${month.month}월';
    final compact = MediaQuery.sizeOf(context).width < 680;
    final platform = Theme.of(context).platform;
    final ios = platform == TargetPlatform.iOS;
    final macOS = platform == TargetPlatform.macOS;
    final monthButton = TextButton.icon(
      onPressed: () => _showMonthPicker(context, ref),
      icon: const Icon(Icons.calendar_month_outlined, size: 20),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: compact
            ? Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)
            : Theme.of(context).textTheme.headlineMedium,
      ),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xff111827),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    final navigationActions = [
      IconButton(
        tooltip: '이전',
        onPressed: () => _moveVisibleRange(ref, -1),
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: '다음',
        onPressed: () => _moveVisibleRange(ref, 1),
        icon: const Icon(Icons.chevron_right),
      ),
      IconButton(
        tooltip: '오늘',
        onPressed: () => _goToday(ref),
        icon: const Icon(Icons.today_outlined),
      ),
    ];
    final utilityActions = [
      IconButton(
        tooltip: searchOpen ? '검색 닫기' : '검색',
        onPressed: onSearchPressed,
        icon: Icon(searchOpen ? Icons.search_off : Icons.search),
      ),
      IconButton(
        tooltip: '검색/필터',
        onPressed: () => _showFilterSheet(context, ref),
        icon: Icon(searchQuery.isEmpty ? Icons.filter_list : Icons.filter_alt),
      ),
      IconButton(
        tooltip: '설정',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        icon: const Icon(Icons.settings_outlined),
      ),
    ];

    if (macOS) {
      final viewSwitch = SegmentedButton<CalendarViewMode>(
        selected: quickAccessSelected ? const {} : {viewMode},
        emptySelectionAllowed: quickAccessSelected,
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8),
          ),
          minimumSize: WidgetStateProperty.all(const Size(38, 34)),
        ),
        segments: const [
          ButtonSegment(value: CalendarViewMode.week, label: Text('주')),
          ButtonSegment(value: CalendarViewMode.month, label: Text('월')),
          ButtonSegment(value: CalendarViewMode.day, label: Text('일')),
        ],
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onCalendarViewSelected(selection.first);
          }
        },
      );
      final quickAccessButton = IconButton(
        tooltip: '빠른 보기',
        isSelected: quickAccessSelected,
        style: IconButton.styleFrom(
          backgroundColor: quickAccessSelected
              ? const Color(0xffdbeafe)
              : Colors.transparent,
          foregroundColor: quickAccessSelected
              ? const Color(0xff1d4ed8)
              : const Color(0xff475569),
        ),
        onPressed: onQuickAccessPressed,
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
      );
      final llmButton = IconButton(
        tooltip: 'LLM',
        onPressed: onLlmPressed,
        icon: const Icon(Icons.auto_awesome_outlined),
      );

      return Padding(
        key: const ValueKey('macos-calendar-toolbar'),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            monthButton,
            const Spacer(),
            quickAccessButton,
            const SizedBox(width: 6),
            viewSwitch,
            const SizedBox(width: 6),
            ...navigationActions,
            ...utilityActions,
            llmButton,
          ],
        ),
      );
    }

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: monthButton),
            if (!ios) ...navigationActions.take(2),
            navigationActions[2],
            utilityActions[0],
            utilityActions[1],
            utilityActions[2],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          monthButton,
          const Spacer(),
          if (!ios) ...navigationActions.take(2),
          navigationActions[2],
          const SizedBox(width: 6),
          ...utilityActions,
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

  void _moveVisibleRange(WidgetRef ref, int delta) {
    switch (viewMode) {
      case CalendarViewMode.month:
        _setVisibleMonth(
          ref,
          DateTime(month.year, month.month + delta),
          selectedDate,
        );
      case CalendarViewMode.week:
        final next = selectedDate.add(Duration(days: delta * 7));
        ref.read(selectedDateProvider.notifier).state = next;
        ref.read(visibleMonthProvider.notifier).state = DateTime(
          next.year,
          next.month,
        );
      case CalendarViewMode.day:
        final next = selectedDate.add(Duration(days: delta));
        ref.read(selectedDateProvider.notifier).state = next;
        ref.read(visibleMonthProvider.notifier).state = DateTime(
          next.year,
          next.month,
        );
    }
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

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    final queryController = TextEditingController(
      text: ref.read(calendarSearchQueryProvider),
    );
    var hidden = settings.hiddenCategoryIds.toSet();
    var showHolidays = settings.calendarShowHolidays;
    var ddayOnly = settings.calendarDdayOnly;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final viewInsets = MediaQuery.viewInsetsOf(context);
          final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                shrinkWrap: true,
                children: [
                  Text('검색/필터', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: queryController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '현재 보기에서 검색',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        ref.read(calendarSearchQueryProvider.notifier).state =
                            value.trim(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: ddayOnly,
                    title: const Text('D-day 일정만 보기'),
                    onChanged: (value) async {
                      setState(() => ddayOnly = value);
                      final updated = ref
                          .read(appSettingsProvider)
                          .copyWith(calendarDdayOnly: value);
                      await ref.read(settingsRepositoryProvider).save(updated);
                      ref.read(appSettingsProvider.notifier).state = updated;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: showHolidays,
                    title: const Text('공휴일 표시'),
                    onChanged: (value) async {
                      setState(() => showHolidays = value);
                      final updated = ref
                          .read(appSettingsProvider)
                          .copyWith(calendarShowHolidays: value);
                      await ref.read(settingsRepositoryProvider).save(updated);
                      ref.read(appSettingsProvider.notifier).state = updated;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('분류 표시', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final category in settings.categories)
                        FilterChip(
                          label: Text(category.label),
                          selected: !hidden.contains(category.id),
                          onSelected: (selected) async {
                            setState(() {
                              if (selected) {
                                hidden.remove(category.id);
                              } else {
                                hidden.add(category.id);
                              }
                            });
                            final updated = ref
                                .read(appSettingsProvider)
                                .copyWith(hiddenCategoryIds: hidden.toList());
                            await ref
                                .read(settingsRepositoryProvider)
                                .save(updated);
                            ref.read(appSettingsProvider.notifier).state =
                                updated;
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          queryController.clear();
                          ref.read(calendarSearchQueryProvider.notifier).state =
                              '';
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('검색어 지우기'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).pop();
                        },
                        child: const Text('완료'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(
      () => WidgetsBinding.instance.addPostFrameCallback(
        (_) => queryController.dispose(),
      ),
    );
  }
}

class _CalendarBottomBar extends StatelessWidget {
  const _CalendarBottomBar({
    required this.viewMode,
    required this.quickAccessSelected,
    required this.onQuickAccessPressed,
    required this.onCalendarViewSelected,
    required this.onLlmPressed,
  });

  final CalendarViewMode viewMode;
  final bool quickAccessSelected;
  final VoidCallback onQuickAccessPressed;
  final ValueChanged<CalendarViewMode> onCalendarViewSelected;
  final VoidCallback onLlmPressed;

  @override
  Widget build(BuildContext context) {
    const barSurface = Color(0xfff8fbff);
    return Container(
      key: const ValueKey('calendar-bottom-bar'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: barSurface,
        border: const Border(top: BorderSide(color: Color(0xffedf0f5))),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
          child: Container(
            height: 65,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: barSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BottomBarItem(
                  tooltip: '빠른 보기',
                  icon: Icons.dashboard_outlined,
                  selected: quickAccessSelected,
                  onPressed: onQuickAccessPressed,
                ),
                _BottomBarItem(
                  tooltip: '주간 보기',
                  label: '주',
                  selected:
                      !quickAccessSelected && viewMode == CalendarViewMode.week,
                  onPressed: () =>
                      onCalendarViewSelected(CalendarViewMode.week),
                ),
                _BottomBarItem(
                  tooltip: '월간 보기',
                  label: '월',
                  selected:
                      !quickAccessSelected &&
                      viewMode == CalendarViewMode.month,
                  onPressed: () =>
                      onCalendarViewSelected(CalendarViewMode.month),
                ),
                _BottomBarItem(
                  tooltip: '일간 보기',
                  label: '일',
                  selected:
                      !quickAccessSelected && viewMode == CalendarViewMode.day,
                  onPressed: () => onCalendarViewSelected(CalendarViewMode.day),
                ),
                _BottomBarItem(
                  tooltip: 'LLM',
                  icon: Icons.auto_awesome_outlined,
                  onPressed: onLlmPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.label,
    this.selected = false,
  }) : assert(icon != null || label != null);

  final String tooltip;
  final IconData? icon;
  final String? label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xff1d4ed8)
        : const Color(0xff64748b);
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: selected ? const Color(0xffdbeafe) : Colors.transparent,
              ),
              child: Transform.translate(
                offset: const Offset(0, -5),
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: 20, color: foreground)
                      : Text(
                          label!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: foreground,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffedf0f5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xff2563eb)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      title: const Text('연월 선택'),
      content: SizedBox(
        width: 370,
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
                childAspectRatio: 2.55,
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
                  child: Text(
                    '$value월',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
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

class _CalendarWeekView extends StatelessWidget {
  const _CalendarWeekView({
    required this.selectedDate,
    required this.weekStartsOnMonday,
    required this.showLunarDates,
    required this.hideSensitiveEvents,
    required this.events,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final bool hideSensitiveEvents;
  final List<CalendarEvent> events;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  Widget build(BuildContext context) {
    final range = _weekRangeFor(selectedDate, weekStartsOnMonday);
    final days = List.generate(
      7,
      (index) => range.start.add(Duration(days: index)),
    );
    final compact = MediaQuery.sizeOf(context).width < 720;

    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemBuilder: (context, index) {
          final day = days[index];
          return _WeekDayPanel(
            day: day,
            selected: _sameDay(day, selectedDate),
            events: _eventsForDay(events, day),
            hideSensitiveEvents: hideSensitiveEvents,
            compact: true,
            onTap: () => onDateSelected(day, _eventsForDay(events, day)),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemCount: days.length,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _WeekDayPanel(
                  day: day,
                  selected: _sameDay(day, selectedDate),
                  events: _eventsForDay(events, day),
                  hideSensitiveEvents: hideSensitiveEvents,
                  compact: false,
                  onTap: () => onDateSelected(day, _eventsForDay(events, day)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekDayPanel extends StatelessWidget {
  const _WeekDayPanel({
    required this.day,
    required this.selected,
    required this.events,
    required this.hideSensitiveEvents,
    required this.compact,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final List<CalendarEvent> events;
  final bool hideSensitiveEvents;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _weekdayColor(day);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xff2563eb)
                  : const Color(0xffedf0f5),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _weekdayLabel(day),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${day.month}/${day.day}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (events.isEmpty)
                Text(
                  '일정 없음',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xff9ca3af),
                  ),
                )
              else if (compact)
                Column(
                  children: [
                    for (final event in events.take(4)) ...[
                      _WeekEventFlag(
                        event: event,
                        hideSensitiveEvents: hideSensitiveEvents,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (events.length > 4)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+${events.length - 4}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                )
              else
                Expanded(
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) => _WeekEventFlag(
                      event: events[index],
                      hideSensitiveEvents: hideSensitiveEvents,
                    ),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemCount: events.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _weekdayColor(DateTime day) {
    if (day.weekday == DateTime.sunday) {
      return const Color(0xffef4444);
    }
    if (day.weekday == DateTime.saturday) {
      return const Color(0xff2563eb);
    }
    return const Color(0xff374151);
  }

  String _weekdayLabel(DateTime day) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[day.weekday - 1];
  }
}

class _WeekEventFlag extends StatelessWidget {
  const _WeekEventFlag({
    required this.event,
    required this.hideSensitiveEvents,
  });

  final CalendarEvent event;
  final bool hideSensitiveEvents;

  @override
  Widget build(BuildContext context) {
    final hidden = hideSensitiveEvents && event.sensitive;
    final eventColor = hidden
        ? const Color(0xff64748b)
        : Color(event.colorValue);
    final title = hidden ? '비공개 일정' : event.title;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (hidden) ...[
            const Icon(Icons.lock_outline, size: 13),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              hidden || event.allDay
                  ? title
                  : '$title  ${DateFormat('HH:mm').format(event.startAt)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: eventColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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

CalendarRange _weekRangeFor(DateTime date, bool weekStartsOnMonday) {
  final day = DateTime(date.year, date.month, date.day);
  final leadingDays = weekStartsOnMonday ? day.weekday - 1 : day.weekday % 7;
  final start = day.subtract(Duration(days: leadingDays));
  return CalendarRange(start, start.add(const Duration(days: 7)));
}

CalendarRange _dayRangeFor(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  return CalendarRange(start, start.add(const Duration(days: 1)));
}

List<CalendarEvent> _filterVisibleEvents(
  List<CalendarEvent> events,
  AppSettings settings,
  String searchQuery,
) {
  final hidden = settings.hiddenCategoryIds.toSet();
  final query = searchQuery.trim().toLowerCase();
  return events.where((event) {
    if (!settings.calendarShowHolidays && event.holiday) {
      return false;
    }
    if (hidden.contains(event.category.id)) {
      return false;
    }
    if (settings.calendarDdayOnly && !event.showDday) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    final searchable = [
      event.title,
      event.memo,
      event.location,
      event.url,
      event.weather,
      event.category.label,
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains(query);
  }).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
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

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
