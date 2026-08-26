import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show TextDirection;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/analytics/product_analytics.dart';
import '../../../core/calendar/calendar_event_ordering.dart';
import '../../../core/calendar/calendar_event_movement.dart';
import '../../../core/calendar/calendar_period_label.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/siri/signal_voice_service.dart';
import '../../../core/theme/daily_ui.dart';
import '../../../core/theme/event_completion_style.dart';
import '../../events/application/event_command_service.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import '../../events/domain/event_draft.dart';
import '../../events/domain/recurrence_rule.dart';
import '../../events/presentation/event_details_panel.dart';
import '../../events/presentation/event_editor_dialog.dart';
import '../../settings/presentation/settings_page.dart';
import '../widgets/calendar_event_drag_layer.dart';
import '../widgets/calendar_month_grid.dart';
import '../widgets/schedule_timeline_view.dart';

enum _BottomCenterAction { quickAccess, calendar, ai }

enum _RecurringDragScope { onlyThis, future, all }

int _calendarContentOrder(bool quickAccessSelected, CalendarViewMode viewMode) {
  if (quickAccessSelected) {
    return 0;
  }
  return switch (viewMode) {
    CalendarViewMode.week => 1,
    CalendarViewMode.month => 2,
    CalendarViewMode.day => 3,
  };
}

int quickTodoColumnCountForPlatform(TargetPlatform platform, double width) {
  if (platform == TargetPlatform.iOS) {
    return 2;
  }
  if (platform == TargetPlatform.macOS) {
    return ((width + 12) / 292).floor().clamp(1, 4).toInt();
  }
  return width >= 720 ? 2 : 1;
}

class _BottomBarUiState {
  const _BottomBarUiState({
    this.selectedAction,
    this.calendarViewControlSelected = false,
  });

  final _BottomCenterAction? selectedAction;
  final bool calendarViewControlSelected;
}

class MonthCalendarPage extends ConsumerStatefulWidget {
  const MonthCalendarPage({super.key});

  @override
  ConsumerState<MonthCalendarPage> createState() => _MonthCalendarPageState();
}

class _MonthCalendarPageState extends ConsumerState<MonthCalendarPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _bottomBarKey = GlobalKey();
  final _aiOpen = ValueNotifier(false);
  final _bottomBarUiState = ValueNotifier(const _BottomBarUiState());
  Timer? _searchDebounce;
  Future<List<CalendarEvent>>? _searchResults;
  var _searchOpen = false;
  var _quickAccessSelected = false;
  var _showAllDayScheduleEvents = true;
  var _dayPanelEventDragActive = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      _recordAnalytics(AnalyticsRecord.screenView(AnalyticsScreen.calendar));
      _recordAnalytics(
        AnalyticsRecord.calendarViewChanged(
          _analyticsCalendarView(ref.read(calendarViewModeProvider)),
          trigger: AnalyticsTrigger.startup,
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _aiOpen.dispose();
    _bottomBarUiState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storedSettings = ref.watch(appSettingsProvider);
    final settings = storedSettings;
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
    final platform = Theme.of(context).platform;
    final desktop = _usesMacDesktopExperience(platform);
    final showAndroidHorizontalMonthIndicator =
        platform == TargetPlatform.android &&
        viewMode == CalendarViewMode.month &&
        settings.monthNavigationMode == MonthNavigationMode.horizontal &&
        MediaQuery.sizeOf(context).width < 680;
    final inlineAi =
        platform == TargetPlatform.iOS &&
        settings.monthNavigationMode == MonthNavigationMode.horizontal;

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePagePointerDown,
        child: SafeArea(
          bottom: desktop,
          child: Stack(
            children: [
              Column(
                children: [
                  _CalendarHeader(
                    month: month,
                    selectedDate: selectedDate,
                    viewMode: viewMode,
                    monthNavigationMode: settings.monthNavigationMode,
                    searchQuery: searchQuery,
                    searchOpen: _searchOpen,
                    quickAccessSelected: _quickAccessSelected,
                    onSearchPressed: _toggleSearch,
                    onQuickAccessPressed: () {
                      _closeSearch();
                      setState(() => _quickAccessSelected = true);
                    },
                    onCalendarViewSelected: _selectCalendarView,
                    onLlmPressed: _toggleAiPanel,
                  ),
                  if (showAndroidHorizontalMonthIndicator)
                    _AndroidHorizontalMonthIndicator(month: month),
                  Expanded(
                    child: _OrderedCalendarSwitcher(
                      order: _calendarContentOrder(
                        _quickAccessSelected,
                        viewMode,
                      ),
                      child: Column(
                        key: ValueKey<int>(
                          _calendarContentOrder(_quickAccessSelected, viewMode),
                        ),
                        children: [
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
                            Expanded(
                              child: _PaintOnlySearchLayout(
                                searchOpen: _searchOpen,
                                searchPanel: _InlineSearchPanel(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  results: _searchResults,
                                  onChanged: _handleSearchChanged,
                                  onSubmitted: _runSearch,
                                  onClose: _closeSearch,
                                  onEventSelected: _selectSearchResult,
                                ),
                                child: RepaintBoundary(
                                  key: const ValueKey(
                                    'calendar-content-repaint-boundary',
                                  ),
                                  child: viewMode == CalendarViewMode.day
                                      ? _CalendarMainContent(
                                          month: month,
                                          selectedDate: selectedDate,
                                          viewMode: viewMode,
                                          settings: settings,
                                          searchQuery: searchQuery,
                                          showAllDayScheduleEvents:
                                              _showAllDayScheduleEvents,
                                          onShowAllDayScheduleEventsChanged:
                                              _setShowAllDayScheduleEvents,
                                          onMonthDelta: (delta) =>
                                              _moveVisibleRange(
                                                ref,
                                                viewMode,
                                                month,
                                                selectedDate,
                                                delta,
                                              ),
                                          onDateSelected: (date, events) {
                                            ref
                                                    .read(
                                                      selectedDateProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                date;
                                          },
                                          externalEventDragActive:
                                              _dayPanelEventDragActive,
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
                                                showAllDayScheduleEvents:
                                                    _showAllDayScheduleEvents,
                                                onShowAllDayScheduleEventsChanged:
                                                    _setShowAllDayScheduleEvents,
                                                onMonthDelta: (delta) =>
                                                    _moveVisibleRange(
                                                      ref,
                                                      viewMode,
                                                      month,
                                                      selectedDate,
                                                      delta,
                                                    ),
                                                onDateSelected: (date, events) {
                                                  ref
                                                          .read(
                                                            selectedDateProvider
                                                                .notifier,
                                                          )
                                                          .state =
                                                      date;
                                                },
                                                externalEventDragActive:
                                                    _dayPanelEventDragActive,
                                              ),
                                            ),
                                            Container(
                                              width: 360,
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                border: Border(
                                                  left: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant,
                                                  ),
                                                ),
                                              ),
                                              child: _MonthDetailsPanel(
                                                eventsAsync: eventsAsync,
                                                settings: settings,
                                                searchQuery: searchQuery,
                                                selectedDate: selectedDate,
                                                onEventDragStateChanged:
                                                    _setDayPanelEventDragActive,
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
                                          showAllDayScheduleEvents:
                                              _showAllDayScheduleEvents,
                                          onShowAllDayScheduleEventsChanged:
                                              _setShowAllDayScheduleEvents,
                                          onMonthDelta: (delta) =>
                                              _moveVisibleRange(
                                                ref,
                                                viewMode,
                                                month,
                                                selectedDate,
                                                delta,
                                              ),
                                          onDateSelected: (date, events) {
                                            ref
                                                    .read(
                                                      selectedDateProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                date;
                                            _showDaySheet(
                                              context,
                                              date,
                                              _eventsForDay(events, date),
                                            );
                                          },
                                          externalEventDragActive:
                                              _dayPanelEventDragActive,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (inlineAi) _buildInlineAiPanel(),
                  if (!desktop)
                    ValueListenableBuilder<bool>(
                      valueListenable: _aiOpen,
                      builder: (context, aiOpen, _) {
                        return ValueListenableBuilder<_BottomBarUiState>(
                          valueListenable: _bottomBarUiState,
                          builder: (context, bottomState, _) {
                            return _CalendarBottomBar(
                              key: _bottomBarKey,
                              viewMode: viewMode,
                              calendarActive: !_quickAccessSelected,
                              activeAction: aiOpen
                                  ? _BottomCenterAction.ai
                                  : _quickAccessSelected
                                  ? _BottomCenterAction.quickAccess
                                  : _BottomCenterAction.calendar,
                              selectedAction: bottomState.selectedAction,
                              calendarViewControlSelected:
                                  bottomState.calendarViewControlSelected,
                              onCalendarViewInteractionStarted:
                                  _markCalendarViewControlSelected,
                              onCalendarViewSelected: (mode) {
                                _selectCalendarView(mode, fromBottomBar: true);
                                _markCalendarViewControlSelected();
                              },
                              onCenterActionSelected: _selectBottomAction,
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
              _buildAiOverlay(context, desktop: desktop, inline: inlineAi),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSearch() {
    final opening = !_searchOpen;
    if (opening) {
      _closeAiPanel();
    }
    setState(() {
      _searchOpen = opening;
    });
    if (_searchOpen) {
      _recordAnalytics(
        AnalyticsRecord.featureUsed(
          AnalyticsFeature.search,
          outcome: AnalyticsOutcome.succeeded,
        ),
      );
      _recordAnalytics(AnalyticsRecord.screenView(AnalyticsScreen.search));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  void _setShowAllDayScheduleEvents(bool value) {
    if (_showAllDayScheduleEvents == value) return;
    setState(() => _showAllDayScheduleEvents = value);
  }

  void _setDayPanelEventDragActive(bool value) {
    if (_dayPanelEventDragActive == value || !mounted) return;
    setState(() => _dayPanelEventDragActive = value);
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    if (_searchOpen || _searchResults != null) {
      setState(() {
        _searchOpen = false;
        _searchResults = null;
      });
    }
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

  void _selectCalendarView(
    CalendarViewMode viewMode, {
    bool fromBottomBar = false,
  }) {
    ref.read(calendarViewModeProvider.notifier).state = viewMode;
    _recordAnalytics(
      AnalyticsRecord.calendarViewChanged(
        _analyticsCalendarView(viewMode),
        trigger: AnalyticsTrigger.manual,
      ),
    );
    if (_quickAccessSelected) {
      setState(() => _quickAccessSelected = false);
    }
    if (!fromBottomBar) {
      _clearBottomAction();
    }
  }

  void _toggleAiPanel() {
    _toggleInlineAiPanel();
  }

  void _toggleInlineAiPanel() {
    _closeSearch();
    final opening = !_aiOpen.value;
    if (_quickAccessSelected) {
      setState(() => _quickAccessSelected = false);
    }
    _aiOpen.value = opening;
    _bottomBarUiState.value = _BottomBarUiState(
      selectedAction: opening ? _BottomCenterAction.ai : null,
    );
  }

  void _closeAiPanel() {
    if (!_aiOpen.value) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _aiOpen.value = false;
    if (_bottomBarUiState.value.selectedAction == _BottomCenterAction.ai) {
      _bottomBarUiState.value = const _BottomBarUiState();
    }
  }

  void _markBottomAction(_BottomCenterAction action) {
    final current = _bottomBarUiState.value;
    if (current.selectedAction == action &&
        !current.calendarViewControlSelected) {
      return;
    }
    _bottomBarUiState.value = _BottomBarUiState(selectedAction: action);
  }

  void _markCalendarViewControlSelected() {
    final current = _bottomBarUiState.value;
    if (current.calendarViewControlSelected && current.selectedAction == null) {
      return;
    }
    _bottomBarUiState.value = const _BottomBarUiState(
      calendarViewControlSelected: true,
    );
  }

  void _clearBottomAction() {
    final current = _bottomBarUiState.value;
    if (current.selectedAction == null &&
        !current.calendarViewControlSelected) {
      return;
    }
    _bottomBarUiState.value = const _BottomBarUiState();
  }

  void _handlePagePointerDown(PointerDownEvent event) {
    final renderObject = _bottomBarKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final localPosition = renderObject.globalToLocal(event.position);
      final bounds = Offset.zero & renderObject.size;
      if (bounds.contains(localPosition)) {
        return;
      }
    }
    _clearBottomAction();
  }

  void _selectBottomAction(_BottomCenterAction action) {
    switch (action) {
      case _BottomCenterAction.quickAccess:
        _markBottomAction(action);
        _closeSearch();
        _aiOpen.value = false;
        if (mounted && !_quickAccessSelected) {
          setState(() => _quickAccessSelected = true);
        }
        _recordAnalytics(
          AnalyticsRecord.calendarViewChanged(
            AnalyticsCalendarView.quickView,
            trigger: AnalyticsTrigger.manual,
          ),
        );
        _recordAnalytics(AnalyticsRecord.screenView(AnalyticsScreen.quickView));
      case _BottomCenterAction.calendar:
        _markBottomAction(action);
        _aiOpen.value = false;
        if (_quickAccessSelected && mounted) {
          setState(() => _quickAccessSelected = false);
        }
      case _BottomCenterAction.ai:
        _toggleAiPanel();
    }
  }

  Widget _buildInlineAiPanel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _aiOpen,
      builder: (context, aiOpen, _) => AnimatedSize(
        key: const ValueKey('inline-ai-layout-panel'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: aiOpen
            ? _SignalVoicePanel(
                key: const ValueKey('inline-ai-input'),
                onClose: _closeAiPanel,
              )
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }

  AnalyticsCalendarView _analyticsCalendarView(CalendarViewMode viewMode) {
    return switch (viewMode) {
      CalendarViewMode.week => AnalyticsCalendarView.week,
      CalendarViewMode.month => AnalyticsCalendarView.month,
      CalendarViewMode.day => AnalyticsCalendarView.day,
    };
  }

  void _recordAnalytics(AnalyticsRecord record) {
    unawaited(
      ref.read(productAnalyticsProvider).record(record).catchError((_) {}),
    );
  }

  Widget _buildAiOverlay(
    BuildContext context, {
    required bool desktop,
    required bool inline,
  }) {
    if (inline) {
      return const SizedBox.shrink();
    }
    final bottomInset = desktop
        ? 0.0
        : 62.0 + math.max(MediaQuery.paddingOf(context).bottom, 6.0);
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: ValueListenableBuilder<bool>(
        valueListenable: _aiOpen,
        builder: (context, aiOpen, _) {
          return IgnorePointer(
            key: const ValueKey('inline-ai-panel-pointer'),
            ignoring: !aiOpen,
            child: ExcludeSemantics(
              excluding: !aiOpen,
              child: AnimatedOpacity(
                key: const ValueKey('inline-ai-panel-opacity'),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                opacity: aiOpen ? 1 : 0,
                child: AnimatedSlide(
                  key: const ValueKey('inline-ai-panel'),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: aiOpen ? Offset.zero : const Offset(0, 1.15),
                  child: aiOpen
                      ? _SignalVoicePanel(
                          key: const ValueKey('overlay-ai-input'),
                          onClose: _closeAiPanel,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
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
    final range = _monthRangeFor(currentMonth, settings.weekStartsOnMonday);
    final eventsAsync = ref.watch(eventsInRangeProvider(range));

    return ColoredBox(
      color: DailyUi.pageBackground(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DailyUi.isDesktop ? 24 : 16,
              DailyUi.isDesktop ? 22 : 16,
              DailyUi.isDesktop ? 24 : 16,
              18,
            ),
            child: eventsAsync.when(
              data: (events) {
                final visibleEvents = _filterVisibleEvents(
                  events,
                  settings,
                  query,
                );
                final groups = _quickTodoGroups(visibleEvents, settings);
                final monthLabel = DateFormat.yMMMM(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(currentMonth);
                return ListView(
                  key: const ValueKey('quick-view-list'),
                  children: [
                    DailyPageTitle(
                      title: context.tr('빠른 보기'),
                      subtitle: context.tr(
                        '{month} · 일정 {count}개',
                        args: {
                          'month': monthLabel,
                          'count': visibleEvents.length,
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (groups.isEmpty)
                      _QuickTodoEmptyState(message: context.tr('일정이 없습니다.'))
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 12.0;
                          final columns = _quickTodoColumnCount(
                            constraints.maxWidth,
                          );
                          final cardWidth =
                              (constraints.maxWidth - spacing * (columns - 1)) /
                              columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final group in groups)
                                SizedBox(
                                  width: cardWidth,
                                  child: _QuickTodoCategoryCard(
                                    group: group,
                                    onCompletedChanged: (event, completed) =>
                                        ref
                                            .read(eventCommandServiceProvider)
                                            .setCompleted(event, completed),
                                    onOpen: (event) =>
                                        _showQuickEventDetails(context, event),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                );
              },
              error: (error, stackTrace) => DailyInfoCallout(
                icon: Icons.error_outline_rounded,
                color: DailyUi.destructive,
                text: context.tr(
                  '일정을 불러오지 못했습니다. ({error})',
                  args: {'error': error},
                ),
              ),
              loading: () => const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_QuickTodoGroup> _quickTodoGroups(
    List<CalendarEvent> events,
    AppSettings settings,
  ) {
    final categoryOrder = settings.categories
        .map((category) => category.id)
        .toList(growable: false);
    final sorted = sortedCalendarEvents(
      events.where(
        (event) => !event.holiday && !event.readOnly && !event.systemEvent,
      ),
      priority: settings.calendarEventSortPriority,
      categoryOrder: categoryOrder,
    );
    final byCategory = <String, List<CalendarEvent>>{};
    final categories = <String, EventCategory>{
      for (final category in settings.categories) category.id: category,
    };
    for (final event in sorted) {
      categories.putIfAbsent(event.category.id, () => event.category);
      byCategory.putIfAbsent(event.category.id, () => []).add(event);
    }
    return [
      for (final category in categories.values)
        if (byCategory[category.id]?.isNotEmpty ?? false)
          _QuickTodoGroup(category, byCategory[category.id]!),
    ];
  }

  int _quickTodoColumnCount(double width) {
    return quickTodoColumnCountForPlatform(defaultTargetPlatform, width);
  }

  Future<void> _showQuickEventDetails(
    BuildContext context,
    CalendarEvent event,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EventDetailsPanel(
        date: event.startAt,
        events: [event],
        initialEvent: event,
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
          onEventDropped: (event, targetDate, targetIndex) =>
              _handleCalendarEventDrop(
                context,
                ref,
                event,
                targetDate,
                targetIndex,
              ),
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

class _OrderedCalendarSwitcher extends StatefulWidget {
  const _OrderedCalendarSwitcher({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  State<_OrderedCalendarSwitcher> createState() =>
      _OrderedCalendarSwitcherState();
}

class _OrderedCalendarSwitcherState extends State<_OrderedCalendarSwitcher> {
  var _direction = 1;

  @override
  void didUpdateWidget(covariant _OrderedCalendarSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order != oldWidget.order) {
      _direction = widget.order > oldWidget.order ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey<int>(widget.order);
    return ClipRect(
      child: AnimatedSwitcher(
        key: const ValueKey('calendar-content-switcher'),
        duration: const Duration(milliseconds: 260),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          final entering = child.key == currentKey;
          final offset = Offset(
            (entering ? _direction : -_direction).toDouble(),
            0,
          );
          return SlideTransition(
            position: animation.drive(Tween(begin: offset, end: Offset.zero)),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _PaintOnlySearchLayout extends StatefulWidget {
  const _PaintOnlySearchLayout({
    required this.searchOpen,
    required this.searchPanel,
    required this.child,
  });

  final bool searchOpen;
  final Widget searchPanel;
  final Widget child;

  @override
  State<_PaintOnlySearchLayout> createState() => _PaintOnlySearchLayoutState();
}

class _PaintOnlySearchLayoutState extends State<_PaintOnlySearchLayout>
    with SingleTickerProviderStateMixin {
  static const _fallbackPanelExtent = 66.0;

  late final AnimationController _controller;
  double _panelExtent = _fallbackPanelExtent;
  Widget? _retainedSearchPanel;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 160),
      value: widget.searchOpen ? 1 : 0,
    );
    _retainedSearchPanel = widget.searchOpen ? widget.searchPanel : null;
    _controller.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant _PaintOnlySearchLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchOpen) {
      _retainedSearchPanel = widget.searchPanel;
    }
    if (widget.searchOpen == oldWidget.searchOpen) {
      return;
    }
    if (widget.searchOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        !widget.searchOpen &&
        _retainedSearchPanel != null &&
        mounted) {
      setState(() => _retainedSearchPanel = null);
    }
  }

  void _handlePanelSize(Size size) {
    if (!mounted || size.height <= 0 || size.height == _panelExtent) {
      return;
    }
    setState(() => _panelExtent = size.height);
  }

  @override
  Widget build(BuildContext context) {
    final searchPanel = _retainedSearchPanel;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Stack(
      key: const ValueKey('paint-only-search-layout'),
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: _panelExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: widget.child,
          builder: (context, panelExtent, child) => AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) => Transform.translate(
              key: const ValueKey('search-calendar-translation'),
              offset: Offset(0, panelExtent * animation.value),
              child: child,
            ),
          ),
        ),
        if (searchPanel != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: animation,
                child: _SizeReporter(
                  onSizeChanged: _handlePanelSize,
                  child: searchPanel,
                ),
                builder: (context, child) => IgnorePointer(
                  ignoring: !widget.searchOpen,
                  child: ExcludeSemantics(
                    excluding: !widget.searchOpen,
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: animation.value,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSizeChanged, required super.child});

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReporterRenderObject(onSizeChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SizeReporterRenderObject renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _SizeReporterRenderObject extends RenderProxyBox {
  _SizeReporterRenderObject(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _reportedSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reportedSize) {
      return;
    }
    _reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSizeChanged(size));
  }
}

enum _SignalVoiceState {
  listening,
  processing,
  awaitingConfirmation,
  completed,
  failed,
}

class _SignalVoicePanel extends ConsumerStatefulWidget {
  const _SignalVoicePanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_SignalVoicePanel> createState() => _SignalVoicePanelState();
}

class _SignalVoicePanelState extends ConsumerState<_SignalVoicePanel>
    with WidgetsBindingObserver {
  final _voice = SignalVoiceService.instance;
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  _SignalVoiceState _state = _SignalVoiceState.listening;
  String _transcript = '';
  String _response = '';
  String _conversation = '';
  String _pendingCommand = '';
  bool _closing = false;
  bool _nativeListening = false;
  bool _showTextInput = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice.setHandlers(
      onTranscriptChanged: (transcript) {
        if (mounted) setState(() => _transcript = transcript);
      },
      onListeningStarted: () {
        if (mounted) setState(() => _nativeListening = true);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    _voice.setHandlers();
    _voice.cancelListening().catchError((_) {});
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_nativeListening || _closing) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _nativeListening = false;
      unawaited(_voice.cancelListening().catchError((_) {}));
      if (mounted) {
        setState(() {
          _response = context.tr('음성 듣기가 중단되었습니다.');
          _state = _SignalVoiceState.failed;
        });
      }
    }
  }

  Future<void> _listen() async {
    if (!mounted) return;
    setState(() {
      _state = _SignalVoiceState.listening;
      _transcript = '';
      _response = '';
      _pendingCommand = '';
      _showTextInput = false;
    });
    try {
      final spoken = await _voice.startListening();
      if (!mounted || _closing) return;
      _nativeListening = false;
      await _acceptCommand(spoken);
    } on PlatformException catch (error) {
      _nativeListening = false;
      if (!mounted || _closing || error.code == 'listening_cancelled') return;
      _showPlatformError(error);
    } catch (_) {
      _nativeListening = false;
      if (!mounted || _closing) return;
      setState(() {
        _response = context.tr('음성 명령을 처리하지 못했습니다.');
        _state = _SignalVoiceState.failed;
      });
    }
  }

  Future<void> _acceptCommand(String spoken) async {
    final command = [
      _conversation,
      spoken.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (command.isEmpty) return;
    setState(() => _transcript = spoken.trim());
    // Native parsing asks for missing required fields first. Once the command
    // is complete it returns signal_confirmation_required immediately before
    // the mutation, so users confirm exactly once at the correct point.
    await _execute(command, confirmed: false);
  }

  Future<void> _execute(String command, {required bool confirmed}) async {
    setState(() {
      _pendingCommand = '';
      _state = _SignalVoiceState.processing;
    });
    try {
      final result = await _voice.runSignal(command, confirmed: confirmed);
      if (!mounted || _closing) return;
      if (result.success) {
        ref.invalidate(eventsInRangeProvider);
        ref.invalidate(eventsForSelectedDateProvider);
        unawaited(ref.read(appleWidgetServiceProvider).refresh());
      }
      setState(() {
        _conversation = '';
        _response = result.message;
        _state = result.success
            ? _SignalVoiceState.completed
            : _SignalVoiceState.failed;
      });
      if (result.message.isNotEmpty) {
        await _voice.speak(result.message);
      }
    } on PlatformException catch (error) {
      if (!mounted || _closing) return;
      _showPlatformError(error, command: command);
    } catch (_) {
      if (!mounted || _closing) return;
      setState(() {
        _response = context.tr('음성 명령을 처리하지 못했습니다.');
        _state = _SignalVoiceState.failed;
      });
    }
  }

  void _showPlatformError(PlatformException error, {String? command}) {
    if (error.code == 'signal_confirmation_required') {
      final pending = command ?? _transcript;
      final message = context.tr('이 명령을 실행할까요?');
      setState(() {
        _pendingCommand = pending;
        _response = message;
        _state = _SignalVoiceState.awaitingConfirmation;
      });
      unawaited(_voice.speak(message));
      return;
    }
    final needsMoreInformation = error.code == 'signal_needs_input';
    final message = switch (error.code) {
      'signal_auth_cancelled' ||
      'signal_cancelled' => context.tr('인증 또는 작업이 취소되었습니다.'),
      'signal_auth_failed' => context.tr('기기 인증을 완료하지 못했습니다.'),
      'signal_execution_failed' =>
        error.message ?? context.tr('음성 명령을 처리하지 못했습니다.'),
      _ when needsMoreInformation => context.tr('필요한 정보를 이어서 말씀해 주세요.'),
      _ => error.message ?? context.tr('음성 명령을 처리하지 못했습니다.'),
    };
    setState(() {
      if (needsMoreInformation && (command ?? _transcript).trim().isNotEmpty) {
        _conversation = (command ?? _transcript).trim();
      }
      _response = message;
      _state = _SignalVoiceState.failed;
    });
    if (needsMoreInformation) unawaited(_voice.speak(message));
  }

  Future<void> _finishListening() async {
    try {
      await _voice.finishListening();
    } catch (_) {}
  }

  Future<void> _confirmCommand() async {
    final command = _pendingCommand;
    if (command.isEmpty) return;
    await _execute(command, confirmed: true);
  }

  void _cancelCommand() {
    setState(() {
      _pendingCommand = '';
      _conversation = '';
      _response = context.tr('작업을 취소했습니다.');
      _state = _SignalVoiceState.failed;
    });
  }

  Future<void> _toggleTextInput() async {
    if (_nativeListening) {
      _nativeListening = false;
      await _voice.cancelListening().catchError((_) {});
    }
    if (!mounted) return;
    setState(() => _showTextInput = !_showTextInput);
    if (_showTextInput) _textFocusNode.requestFocus();
  }

  Future<void> _submitTyped(String value) async {
    final input = value.trim();
    if (input.isEmpty) return;
    _textController.clear();
    await _acceptCommand(input);
  }

  @override
  Widget build(BuildContext context) {
    final listening = _state == _SignalVoiceState.listening;
    final processing = _state == _SignalVoiceState.processing;
    final awaitingConfirmation =
        _state == _SignalVoiceState.awaitingConfirmation;
    final status = switch (_state) {
      _SignalVoiceState.listening => context.tr('지금 듣는 중...'),
      _SignalVoiceState.processing => context.tr('시그널 처리 중...'),
      _SignalVoiceState.awaitingConfirmation => context.tr('실행 확인'),
      _SignalVoiceState.completed => context.tr('완료'),
      _SignalVoiceState.failed => context.tr('다시 말씀해 주세요'),
    };

    return Material(
      color: DailyUi.pageBackground(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Material(
            color: DailyUi.groupedSurface(context),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: DailyUi.separator(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton.filled(
                          tooltip: listening
                              ? context.tr('듣기 완료')
                              : context.tr('다시 듣기'),
                          onPressed: processing || awaitingConfirmation
                              ? null
                              : listening
                              ? _finishListening
                              : _listen,
                          style: IconButton.styleFrom(
                            backgroundColor: DailyUi.purple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: DailyUi.purple.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          icon: processing
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  listening
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                              if (_transcript.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _transcript,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              if (_response.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _response,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: DailyUi.primary,
                                        height: 1.35,
                                      ),
                                ),
                              ],
                              if (awaitingConfirmation) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    FilledButton(
                                      onPressed: _confirmCommand,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: DailyUi.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text(context.tr('실행')),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: _cancelCommand,
                                      child: Text(context.tr('취소')),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      DailyIconAction(
                        tooltip: context.tr('텍스트로 입력'),
                        onPressed: processing ? null : _toggleTextInput,
                        selected: _showTextInput,
                        icon: _showTextInput
                            ? Icons.keyboard_hide_rounded
                            : Icons.keyboard_alt_outlined,
                      ),
                      DailyIconAction(
                        tooltip: context.tr('AI 입력 닫기'),
                        onPressed: widget.onClose,
                        icon: Icons.close_rounded,
                      ),
                    ],
                  ),
                  if (_showTextInput) ...[
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('signal-text-input'),
                      controller: _textController,
                      focusNode: _textFocusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _submitTyped,
                      decoration: InputDecoration(
                        hintText: context.tr('Daily에 요청할 내용을 입력하세요.'),
                        prefixIcon: const Icon(Icons.keyboard_alt_outlined),
                        suffixIcon: DailyIconAction(
                          tooltip: context.tr('실행'),
                          onPressed: () => _submitTyped(_textController.text),
                          icon: Icons.arrow_upward_rounded,
                          size: 36,
                        ),
                        fillColor: DailyUi.elevatedSurface(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: DailyUi.separator(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: DailyUi.separator(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: DailyUi.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineSearchPanel extends StatelessWidget {
  const _InlineSearchPanel({
    required this.controller,
    required this.focusNode,
    required this.results,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
    required this.onEventSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<List<CalendarEvent>>? results;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClose;
  final ValueChanged<CalendarEvent> onEventSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: DailyUi.pageBackground(context),
        border: Border(bottom: BorderSide(color: DailyUi.separator(context))),
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
              hintText: context.tr('제목, 메모, 장소 검색'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DailyIconAction(
                    tooltip: context.tr('검색'),
                    onPressed: onSubmitted,
                    icon: Icons.arrow_forward_rounded,
                    size: 36,
                  ),
                  DailyIconAction(
                    tooltip: context.tr('닫기'),
                    onPressed: onClose,
                    icon: Icons.close_rounded,
                    size: 36,
                  ),
                ],
              ),
              fillColor: DailyUi.groupedSurface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: DailyUi.separator(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: DailyUi.separator(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: DailyUi.primary,
                  width: 1.5,
                ),
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
                      context.tr('검색 결과가 없습니다.'),
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
  const _InlineSearchResultTile({required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMMd(locale).format(event.startAt);
    final time = event.allDay
        ? context.tr('종일')
        : DateFormat.Hm(locale).format(event.startAt);
    final color = Color(event.colorValue);
    return Material(
      color: DailyUi.groupedSurface(context),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: DailyUi.separator(context)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        onTap: onTap,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.event_outlined, color: color, size: 19),
        ),
        title: Text(
          context.l10n.eventTitle(event.title, holiday: event.holiday),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: calendarEventCompletionStyle(
            context,
            Theme.of(context).textTheme.titleMedium,
            completed: event.completed,
          ),
        ),
        subtitle: Text('$date  $time'),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: DailyUi.tertiaryText(context),
          size: 20,
        ),
      ),
    );
  }
}

class _MonthDetailsPanel extends ConsumerWidget {
  const _MonthDetailsPanel({
    required this.eventsAsync,
    required this.settings,
    required this.searchQuery,
    required this.selectedDate,
    required this.onEventDragStateChanged,
  });

  final AsyncValue<List<CalendarEvent>> eventsAsync;
  final AppSettings settings;
  final String searchQuery;
  final DateTime selectedDate;
  final ValueChanged<bool> onEventDragStateChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return eventsAsync.when(
      data: (events) => _buildPanel(context, ref, events),
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => EventDetailsPanel(
        date: selectedDate,
        events: const <CalendarEvent>[],
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    WidgetRef ref,
    List<CalendarEvent> events,
  ) {
    return EventDetailsPanel(
      date: selectedDate,
      events: _eventsForDay(
        _filterVisibleEvents(events, settings, searchQuery),
        selectedDate,
      ),
      onEventDropped: (event, targetDate, targetIndex) =>
          _handleCalendarEventDrop(
            context,
            ref,
            event,
            targetDate,
            targetIndex,
          ),
      onEventDragStateChanged: onEventDragStateChanged,
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
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onMonthDelta,
    required this.onDateSelected,
    required this.externalEventDragActive,
  });

  final DateTime month;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final ValueChanged<int> onMonthDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;
  final bool externalEventDragActive;

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
        externalEventDragActive: externalEventDragActive,
      ),
      CalendarViewMode.week => _WeekPageView(
        selectedDate: selectedDate,
        settings: settings,
        searchQuery: searchQuery,
        showAllDayScheduleEvents: showAllDayScheduleEvents,
        onShowAllDayScheduleEventsChanged: onShowAllDayScheduleEventsChanged,
        onWeekDelta: onMonthDelta,
        onDateSelected: onDateSelected,
      ),
      CalendarViewMode.day => _DayPageView(
        selectedDate: selectedDate,
        settings: settings,
        searchQuery: searchQuery,
        showAllDayScheduleEvents: showAllDayScheduleEvents,
        onShowAllDayScheduleEventsChanged: onShowAllDayScheduleEventsChanged,
        onDayDelta: onMonthDelta,
        onDateSelected: (date) => onDateSelected(date, const []),
      ),
    };
  }
}

class _WeekPageView extends StatefulWidget {
  const _WeekPageView({
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onWeekDelta,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
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
  final _mouseWheelNavigation = _QueuedPointerPageNavigation();

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
        physics: _calendarPagePhysics(context),
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
            showAllDayScheduleEvents: widget.showAllDayScheduleEvents,
            onShowAllDayScheduleEventsChanged:
                widget.onShowAllDayScheduleEventsChanged,
            onDateSelected: widget.onDateSelected,
          );
        },
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    final navigationDelta = _desktopPageNavigationDelta(
      context,
      event,
      allowVerticalMouseWheel:
          widget.settings.weekDayLayoutMode == WeekDayLayoutMode.list,
    );
    if (navigationDelta == null || !_controller.hasClients) {
      return;
    }
    final scroll = event as PointerScrollEvent;
    final direction = navigationDelta > 0 ? 1 : -1;
    if (scroll.kind == PointerDeviceKind.mouse) {
      _mouseWheelNavigation.animate(
        controller: _controller,
        currentPage: _currentPage,
        direction: direction,
      );
      return;
    }
    final now = DateTime.now();
    final lastMoveAt = _lastPointerWeekMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerWeekMoveAt = now;
    final nextPage = _currentPage + direction;
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
    _mouseWheelNavigation.reset();
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
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _weekRangeFor(selectedDate, settings.weekStartsOnMonday);
    final eventsAsync = ref.watch(eventsInRangeProvider(range));
    return eventsAsync.when(
      data: (events) {
        final visibleEvents = _filterVisibleEvents(
          events,
          settings,
          searchQuery,
        );
        if (settings.weekDayLayoutMode == WeekDayLayoutMode.schedule) {
          final days = List.generate(
            7,
            (index) => range.start.add(Duration(days: index)),
          );
          return ScheduleTimelineView(
            days: days,
            events: visibleEvents,
            selectedDate: selectedDate,
            use24HourTime: settings.use24HourTime,
            showAllDayEvents: showAllDayScheduleEvents,
            holidayBackgroundEnabled: settings.calendarHolidayBackgroundEnabled,
            holidayColorValue: settings.holidayCategory.colorValue,
            centerEventTitles:
                settings.calendarEventTitleAlignment ==
                CalendarEventTitleAlignment.center,
            eventSortPriority: settings.calendarEventSortPriority,
            categoryOrder: settings.categories
                .map((category) => category.id)
                .toList(),
            weekStartsOnMonday: settings.weekStartsOnMonday,
            onEventDropped: (event, targetDate, targetIndex) =>
                _handleCalendarEventDrop(
                  context,
                  ref,
                  event,
                  targetDate,
                  targetIndex,
                ),
            onShowAllDayEventsChanged: onShowAllDayScheduleEventsChanged,
            onDateSelected: (date) =>
                onDateSelected(date, _eventsForDay(visibleEvents, date)),
          );
        }
        return _CalendarWeekView(
          selectedDate: selectedDate,
          weekStartsOnMonday: settings.weekStartsOnMonday,
          showLunarDates: settings.showLunarDates,
          centerEventTitles:
              settings.calendarEventTitleAlignment ==
              CalendarEventTitleAlignment.center,
          events: visibleEvents,
          onEventDropped: (event, targetDate, targetIndex) =>
              _handleCalendarEventDrop(
                context,
                ref,
                event,
                targetDate,
                targetIndex,
              ),
          onDateSelected: onDateSelected,
        );
      },
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
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onDayDelta,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final ValueChanged<int> onDayDelta;
  final ValueChanged<DateTime> onDateSelected;

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
  final _mouseWheelNavigation = _QueuedPointerPageNavigation();

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
        physics: _calendarPagePhysics(context),
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
            showAllDayScheduleEvents: widget.showAllDayScheduleEvents,
            onShowAllDayScheduleEventsChanged:
                widget.onShowAllDayScheduleEventsChanged,
            onDateSelected: widget.onDateSelected,
          );
        },
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    final navigationDelta = _desktopPageNavigationDelta(
      context,
      event,
      allowVerticalMouseWheel:
          widget.settings.weekDayLayoutMode == WeekDayLayoutMode.list,
    );
    if (navigationDelta == null || !_controller.hasClients) {
      return;
    }
    final scroll = event as PointerScrollEvent;
    final direction = navigationDelta > 0 ? 1 : -1;
    if (scroll.kind == PointerDeviceKind.mouse) {
      _mouseWheelNavigation.animate(
        controller: _controller,
        currentPage: _currentPage,
        direction: direction,
      );
      return;
    }
    final now = DateTime.now();
    final lastMoveAt = _lastPointerDayMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerDayMoveAt = now;
    final nextPage = _currentPage + direction;
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
    _mouseWheelNavigation.reset();
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
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onDateSelected,
  });

  final DateTime date;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsInRangeProvider(_dayRangeFor(date)));
    return eventsAsync.when(
      data: (events) {
        final visibleEvents = _eventsForDay(
          _filterVisibleEvents(events, settings, searchQuery),
          date,
        );
        if (settings.weekDayLayoutMode == WeekDayLayoutMode.schedule) {
          return ScheduleTimelineView(
            days: [date],
            events: visibleEvents,
            selectedDate: date,
            use24HourTime: settings.use24HourTime,
            showAllDayEvents: showAllDayScheduleEvents,
            holidayBackgroundEnabled: settings.calendarHolidayBackgroundEnabled,
            holidayColorValue: settings.holidayCategory.colorValue,
            centerEventTitles:
                settings.calendarEventTitleAlignment ==
                CalendarEventTitleAlignment.center,
            eventSortPriority: settings.calendarEventSortPriority,
            categoryOrder: settings.categories
                .map((category) => category.id)
                .toList(),
            weekStartsOnMonday: settings.weekStartsOnMonday,
            onEventDropped: (event, targetDate, targetIndex) =>
                _handleCalendarEventDrop(
                  context,
                  ref,
                  event,
                  targetDate,
                  targetIndex,
                ),
            onShowAllDayEventsChanged: onShowAllDayScheduleEventsChanged,
            onDateSelected: onDateSelected,
          );
        }
        return EventDetailsPanel(
          date: date,
          events: visibleEvents,
          onEventDropped: (event, targetDate, targetIndex) =>
              _handleCalendarEventDrop(
                context,
                ref,
                event,
                targetDate,
                targetIndex,
              ),
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MonthPageView extends ConsumerStatefulWidget {
  const _MonthPageView({
    required this.month,
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onMonthDelta,
    required this.onDateSelected,
    required this.externalEventDragActive,
  });

  final DateTime month;
  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final ValueChanged<int> onMonthDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;
  final bool externalEventDragActive;

  @override
  ConsumerState<_MonthPageView> createState() => _MonthPageViewState();
}

class _MonthPageViewState extends ConsumerState<_MonthPageView> {
  static const _initialPage = 12000;

  late final PageController _controller;
  _SmoothMouseWheelScrollController? _verticalController;
  double? _verticalItemExtent;
  Size? _verticalHostSize;
  double? _verticalStableItemExtent;
  late final DateTime _anchorMonth;
  var _currentPage = _initialPage;
  var _reportedPage = _initialPage;
  var _applyingExternalMonth = false;
  var _externalAnimationRevision = 0;
  var _verticalExtentRevision = 0;
  var _preservingVerticalExtent = false;
  DateTime? _lastPointerMonthMoveAt;
  final _mouseWheelNavigation = _QueuedPointerPageNavigation();
  final Map<int, RenderBox> _continuousGridBoxes = {};
  final ValueNotifier<(DateTime?, DateTime?)> _continuousRangeNotifier =
      ValueNotifier((null, null));
  DateTime? _continuousRangeStart;
  DateTime? _continuousRangeEnd;
  bool _continuousMouseRangeActive = false;
  bool _continuousEventDragActive = false;

  @override
  void initState() {
    super.initState();
    _anchorMonth = DateTime(widget.month.year, widget.month.month);
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _MonthPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeController =
        widget.settings.monthNavigationMode == MonthNavigationMode.vertical
        ? _verticalController
        : _controller;
    if (_sameMonth(_monthForPage(_currentPage), widget.month) ||
        activeController == null ||
        !activeController.hasClients) {
      return;
    }
    final targetPage =
        _currentPage + _monthDelta(_monthForPage(_currentPage), widget.month);
    _animateToExternalPage(targetPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    _verticalController?.dispose();
    _continuousRangeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settings.monthNavigationMode == MonthNavigationMode.vertical) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CalendarWeekdayHeader(
              weekStartsOnMonday: widget.settings.weekStartsOnMonday,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemExtent = _stableVerticalItemExtent(
                  context,
                  constraints,
                );
                final verticalController = _verticalControllerFor(itemExtent);
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification &&
                        !_applyingExternalMonth &&
                        !_preservingVerticalExtent) {
                      final index = (verticalController.offset / itemExtent)
                          .round();
                      _currentPage = index;
                    } else if (notification is ScrollEndNotification &&
                        !_applyingExternalMonth &&
                        !_preservingVerticalExtent) {
                      final index = (verticalController.offset / itemExtent)
                          .round();
                      _currentPage = index;
                      if (index != _reportedPage) {
                        final delta = index - _reportedPage;
                        _reportedPage = index;
                        widget.onMonthDelta(delta);
                      }
                    }
                    return false;
                  },
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _handleContinuousPointerDown,
                    onPointerMove: _handleContinuousPointerMove,
                    onPointerUp: _handleContinuousPointerUp,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      supportedDevices: const {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.invertedStylus,
                      },
                      onLongPressStart: (details) =>
                          _startContinuousRange(details.globalPosition),
                      onLongPressMoveUpdate: (details) =>
                          _updateContinuousRange(details.globalPosition),
                      onLongPressEnd: (details) {
                        if (_continuousDateAt(details.globalPosition) == null) {
                          _cancelContinuousRange();
                        } else {
                          _commitContinuousRange();
                        }
                      },
                      onLongPressCancel: _cancelContinuousRange,
                      child: ListView.builder(
                        key: const ValueKey('continuous-month-scroll'),
                        controller: verticalController,
                        itemExtent: itemExtent,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemBuilder: (context, index) {
                          final pageMonth = _monthForPage(index);
                          return Column(
                            key: ValueKey(
                              'continuous-month-${pageMonth.year}-${pageMonth.month}',
                            ),
                            children: [
                              _MonthBoundaryLabel(month: pageMonth),
                              Expanded(
                                child:
                                    ValueListenableBuilder<
                                      (DateTime?, DateTime?)
                                    >(
                                      valueListenable: _continuousRangeNotifier,
                                      builder: (context, range, _) =>
                                          _CalendarMonthPage(
                                            month: pageMonth,
                                            selectedDate: widget.selectedDate,
                                            settings: widget.settings,
                                            searchQuery: widget.searchQuery,
                                            continuous: true,
                                            showWeekdayHeader: false,
                                            onRangeHitTestBoxChanged: (box) {
                                              if (box == null) {
                                                _continuousGridBoxes.remove(
                                                  index,
                                                );
                                              } else {
                                                _continuousGridBoxes[index] =
                                                    box;
                                              }
                                            },
                                            externalRangeStart: range.$1,
                                            externalRangeEnd: range.$2,
                                            enableRangeGestures: false,
                                            onEventDragStateChanged:
                                                _setContinuousEventDragActive,
                                            externalEventDragActive:
                                                widget.externalEventDragActive,
                                            onDateSelected:
                                                widget.onDateSelected,
                                          ),
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
    return Listener(
      key: const ValueKey('month-pointer-navigation'),
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: PageView.builder(
        controller: _controller,
        allowImplicitScrolling: true,
        physics: _calendarPagePhysics(context),
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
            externalEventDragActive: widget.externalEventDragActive,
            onDateSelected: widget.onDateSelected,
          );
        },
      ),
    );
  }

  void _handleContinuousPointerDown(PointerDownEvent event) {
    if (_continuousEventDragActive) {
      return;
    }
    if ((event.kind != PointerDeviceKind.mouse &&
            event.kind != PointerDeviceKind.trackpad) ||
        (event.buttons != 0 && (event.buttons & kPrimaryMouseButton) == 0)) {
      return;
    }
    _continuousMouseRangeActive = false;
    _startContinuousRange(event.position, showImmediately: false);
  }

  void _handleContinuousPointerMove(PointerMoveEvent event) {
    if (_continuousEventDragActive) {
      return;
    }
    final start = _continuousRangeStart;
    if (start == null ||
        (event.kind != PointerDeviceKind.mouse &&
            event.kind != PointerDeviceKind.trackpad)) {
      return;
    }
    final target = _continuousDateAt(event.position);
    if (target == null || _sameDay(target, start)) {
      return;
    }
    _continuousMouseRangeActive = true;
    _updateContinuousRange(event.position);
  }

  void _handleContinuousPointerUp(PointerUpEvent event) {
    if (_continuousEventDragActive) {
      return;
    }
    if (event.kind != PointerDeviceKind.mouse &&
        event.kind != PointerDeviceKind.trackpad) {
      return;
    }
    if (_continuousMouseRangeActive &&
        _continuousDateAt(event.position) != null) {
      _commitContinuousRange();
    } else {
      _cancelContinuousRange();
    }
    _continuousMouseRangeActive = false;
  }

  void _startContinuousRange(
    Offset globalPosition, {
    bool showImmediately = true,
  }) {
    if (_continuousEventDragActive) {
      return;
    }
    final date = _continuousDateAt(globalPosition);
    if (date == null) {
      _cancelContinuousRange();
      return;
    }
    _continuousRangeStart = date;
    _continuousRangeEnd = showImmediately ? date : null;
    _publishContinuousRange();
  }

  void _updateContinuousRange(Offset globalPosition) {
    if (_continuousEventDragActive) {
      return;
    }
    final start = _continuousRangeStart;
    final end = _continuousRangeEnd;
    final date = _continuousDateAt(globalPosition);
    if (start == null || date == null || (end != null && _sameDay(date, end))) {
      return;
    }
    _continuousRangeEnd = date;
    _publishContinuousRange();
  }

  void _cancelContinuousRange() {
    if (_continuousRangeStart == null && _continuousRangeEnd == null) {
      return;
    }
    _continuousRangeStart = null;
    _continuousRangeEnd = null;
    _publishContinuousRange();
  }

  void _publishContinuousRange() {
    _continuousRangeNotifier.value = (
      _continuousRangeStart,
      _continuousRangeEnd,
    );
  }

  void _commitContinuousRange() {
    if (_continuousEventDragActive) {
      _cancelContinuousRange();
      return;
    }
    final start = _continuousRangeStart;
    final end = _continuousRangeEnd;
    _cancelContinuousRange();
    if (start == null || end == null || _sameDay(start, end)) {
      return;
    }
    final normalizedStart = start.isBefore(end) ? start : end;
    final normalizedEnd = start.isBefore(end) ? end : start;
    unawaited(
      _openRangeEventEditor(
        context,
        ref,
        normalizedStart,
        normalizedEnd,
        widget.settings.categories,
        widget.settings.defaultReminderMinutesList,
      ),
    );
  }

  DateTime? _continuousDateAt(Offset globalPosition) {
    for (final entry in _continuousGridBoxes.entries) {
      final renderObject = entry.value;
      if (!renderObject.hasSize || !renderObject.attached) {
        continue;
      }
      final local = renderObject.globalToLocal(globalPosition);
      if (local.dx < 0 ||
          local.dy < 0 ||
          local.dx >= renderObject.size.width ||
          local.dy >= renderObject.size.height) {
        continue;
      }
      final month = _monthForPage(entry.key);
      final first = DateTime(month.year, month.month);
      final leadingDays = widget.settings.weekStartsOnMonday
          ? first.weekday - 1
          : first.weekday % 7;
      final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
      final weekCount = ((leadingDays + daysInMonth) / 7).ceil();
      final column = (local.dx / (renderObject.size.width / 7)).floor();
      final row = (local.dy / (renderObject.size.height / weekCount)).floor();
      final date = first
          .subtract(Duration(days: leadingDays))
          .add(Duration(days: row * 7 + column));
      if (date.year != month.year || date.month != month.month) {
        return null;
      }
      return date;
    }
    return null;
  }

  void _setContinuousEventDragActive(bool active) {
    if (_continuousEventDragActive == active) {
      return;
    }
    _continuousEventDragActive = active;
    if (active) {
      _continuousMouseRangeActive = false;
      _cancelContinuousRange();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_usesMacDesktopExperience(Theme.of(context).platform) ||
        event is! PointerScrollEvent ||
        !_controller.hasClients) {
      return;
    }
    final primaryDelta =
        event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    final minimumDelta = event.kind == PointerDeviceKind.mouse ? 0.0 : 18.0;
    if (primaryDelta.abs() <= minimumDelta) {
      return;
    }
    final direction = primaryDelta > 0 ? 1 : -1;
    if (event.kind == PointerDeviceKind.mouse) {
      _mouseWheelNavigation.animate(
        controller: _controller,
        currentPage: _currentPage,
        direction: direction,
      );
      return;
    }
    final now = DateTime.now();
    final lastMoveAt = _lastPointerMonthMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerMonthMoveAt = now;
    final nextPage = _currentPage + direction;
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
    _mouseWheelNavigation.reset();
    final revision = ++_externalAnimationRevision;
    _applyingExternalMonth = true;
    _currentPage = targetPage;
    _reportedPage = targetPage;
    final animation =
        widget.settings.monthNavigationMode == MonthNavigationMode.vertical
        ? _verticalController!.animateTo(
            targetPage * _verticalItemExtent!,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
        : _controller.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
    unawaited(
      animation.whenComplete(() {
        if (mounted && revision == _externalAnimationRevision) {
          _applyingExternalMonth = false;
        }
      }),
    );
  }

  _SmoothMouseWheelScrollController _verticalControllerFor(double itemExtent) {
    final current = _verticalController;
    final previousExtent = _verticalItemExtent;
    if (current != null && previousExtent == itemExtent) {
      return current;
    }
    final logicalPage =
        current != null && previousExtent != null && current.hasClients
        ? current.offset / previousExtent
        : _currentPage.toDouble();
    final replacement = _SmoothMouseWheelScrollController(
      initialScrollOffset: logicalPage * itemExtent,
      keepScrollOffset: false,
    );
    final revision = ++_verticalExtentRevision;
    _preservingVerticalExtent = true;
    _verticalController = replacement;
    _verticalItemExtent = itemExtent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      current?.dispose();
      if (mounted && revision == _verticalExtentRevision) {
        if (replacement.hasClients) {
          replacement.jumpTo(logicalPage * itemExtent);
        }
        _preservingVerticalExtent = false;
      }
    });
    return replacement;
  }

  double _stableVerticalItemExtent(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final hostSize = MediaQuery.sizeOf(context);
    if (_verticalHostSize != hostSize) {
      _verticalHostSize = hostSize;
      _verticalStableItemExtent = constraints.maxHeight;
    } else if (_verticalStableItemExtent == null ||
        constraints.maxHeight > _verticalStableItemExtent!) {
      _verticalStableItemExtent = constraints.maxHeight;
    }
    return _verticalStableItemExtent!;
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

class _SmoothMouseWheelScrollController extends ScrollController {
  _SmoothMouseWheelScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothMouseWheelScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _QueuedPointerPageNavigation {
  int? _targetPage;
  var _animationRevision = 0;

  void animate({
    required PageController controller,
    required int currentPage,
    required int direction,
  }) {
    if (!controller.hasClients || direction == 0) {
      return;
    }
    final visiblePage = controller.page ?? currentPage.toDouble();
    final targetPage = (_targetPage ?? visiblePage.round()) + direction.sign;
    _targetPage = targetPage;
    final revision = ++_animationRevision;
    final pendingDistance = (targetPage - visiblePage).abs();
    final duration = Duration(
      milliseconds: (140 + math.min(pendingDistance, 4) * 20).round(),
    );
    unawaited(
      controller
          .animateToPage(
            targetPage,
            duration: duration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (revision == _animationRevision) {
              _targetPage = null;
            }
          }),
    );
  }

  void reset() {
    _animationRevision += 1;
    _targetPage = null;
  }
}

ScrollPhysics _calendarPagePhysics(BuildContext context) {
  return const _ResponsiveMonthPagePhysics();
}

class _SmoothMouseWheelScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothMouseWheelScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  double? _wheelTarget;
  var _animationRevision = 0;

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      super.pointerScroll(delta);
      return;
    }
    final baseTarget = _wheelTarget ?? pixels;
    final target = (baseTarget + delta).clamp(minScrollExtent, maxScrollExtent);
    if (target == pixels) {
      return;
    }
    final revision = ++_animationRevision;
    _wheelTarget = target;
    unawaited(
      animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      ).whenComplete(() {
        if (revision == _animationRevision) {
          _wheelTarget = null;
        }
      }),
    );
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

class _AndroidHorizontalMonthIndicator extends StatelessWidget {
  const _AndroidHorizontalMonthIndicator({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('android-horizontal-month-indicator'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        DateFormat.MMMM(
          Localizations.localeOf(context).toLanguageTag(),
        ).format(month),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MonthBoundaryLabel extends StatelessWidget {
  const _MonthBoundaryLabel({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
      child: Row(
        children: [
          Text(
            DateFormat.MMMM(
              Localizations.localeOf(context).toLanguageTag(),
            ).format(month),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}

double? _desktopPageNavigationDelta(
  BuildContext context,
  PointerSignalEvent event, {
  required bool allowVerticalMouseWheel,
}) {
  if (!_usesMacDesktopExperience(Theme.of(context).platform) ||
      event is! PointerScrollEvent) {
    return null;
  }
  final horizontal = event.scrollDelta.dx.abs();
  final vertical = event.scrollDelta.dy.abs();
  final minimumDelta = event.kind == PointerDeviceKind.mouse ? 0.0 : 18.0;
  if (horizontal > minimumDelta && horizontal > vertical) {
    return event.scrollDelta.dx;
  }
  if (allowVerticalMouseWheel &&
      event.kind == PointerDeviceKind.mouse &&
      vertical > minimumDelta &&
      vertical > horizontal) {
    return event.scrollDelta.dy;
  }
  return null;
}

bool _usesMacDesktopExperience(TargetPlatform platform) {
  return platform == TargetPlatform.macOS || platform == TargetPlatform.windows;
}

class _CalendarMonthPage extends ConsumerWidget {
  const _CalendarMonthPage({
    required this.month,
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onDateSelected,
    this.continuous = false,
    this.showWeekdayHeader = true,
    this.onRangeHitTestBoxChanged,
    this.externalRangeStart,
    this.externalRangeEnd,
    this.enableRangeGestures = true,
    this.onEventDragStateChanged,
    this.externalEventDragActive = false,
  });

  final DateTime month;
  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;
  final bool continuous;
  final bool showWeekdayHeader;
  final ValueChanged<RenderBox?>? onRangeHitTestBoxChanged;
  final DateTime? externalRangeStart;
  final DateTime? externalRangeEnd;
  final bool enableRangeGestures;
  final ValueChanged<bool>? onEventDragStateChanged;
  final bool externalEventDragActive;

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
          holidayBackgroundEnabled: settings.calendarHolidayBackgroundEnabled,
          holidayColorValue: settings.holidayCategory.colorValue,
          centerEventTitles:
              settings.calendarEventTitleAlignment ==
              CalendarEventTitleAlignment.center,
          eventSortPriority: settings.calendarEventSortPriority,
          categoryOrder: settings.categories
              .map((category) => category.id)
              .toList(),
          manualEventOrders: settings.calendarManualEventOrders,
          showAdjacentMonthDates:
              !continuous && settings.showAdjacentMonthDates,
          continuous: continuous,
          showWeekdayHeader: showWeekdayHeader,
          onRangeHitTestBoxChanged: onRangeHitTestBoxChanged,
          externalRangeStart: externalRangeStart,
          externalRangeEnd: externalRangeEnd,
          enableRangeGestures: enableRangeGestures,
          onEventDragStateChanged: onEventDragStateChanged,
          externalEventDragActive: externalEventDragActive,
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
          onEventDropped: (event, targetDate, targetIndex) => _handleEventDrop(
            context,
            ref,
            event,
            targetDate,
            targetIndex,
            visibleEvents,
            settings,
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
        holidayBackgroundEnabled: settings.calendarHolidayBackgroundEnabled,
        holidayColorValue: settings.holidayCategory.colorValue,
        centerEventTitles:
            settings.calendarEventTitleAlignment ==
            CalendarEventTitleAlignment.center,
        eventSortPriority: settings.calendarEventSortPriority,
        categoryOrder: settings.categories
            .map((category) => category.id)
            .toList(),
        manualEventOrders: settings.calendarManualEventOrders,
        showAdjacentMonthDates: !continuous && settings.showAdjacentMonthDates,
        continuous: continuous,
        showWeekdayHeader: showWeekdayHeader,
        onRangeHitTestBoxChanged: onRangeHitTestBoxChanged,
        externalRangeStart: externalRangeStart,
        externalRangeEnd: externalRangeEnd,
        enableRangeGestures: enableRangeGestures,
        externalEventDragActive: externalEventDragActive,
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
  ) => _openRangeEventEditor(
    context,
    ref,
    start,
    end,
    categories,
    defaultReminderMinutesList,
  );

  Future<void> _handleEventDrop(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    DateTime targetDate,
    int targetIndex,
    List<CalendarEvent> visibleEvents,
    AppSettings settings,
  ) async {
    if (event.readOnly || event.systemEvent || event.holiday) {
      return;
    }
    final sourceDate = _dateOnly(event.startAt);
    final normalizedTarget = _dateOnly(targetDate);
    var movedEvent = event;

    if (!_sameDay(sourceDate, normalizedTarget)) {
      if (event.isRecurring) {
        final scope = await _showRecurringDragScopeDialog(context);
        if (scope == null || !context.mounted) {
          return;
        }
        final result = await _moveRecurringEvent(
          ref,
          event,
          normalizedTarget,
          scope,
        );
        if (result == null) {
          return;
        }
        movedEvent = result;
      } else {
        movedEvent = shiftCalendarEventToDate(event, normalizedTarget);
        await ref.read(eventCommandServiceProvider).save(movedEvent);
      }
    }

    await _saveManualOrderAfterDrop(
      ref,
      sourceDate: sourceDate,
      targetDate: normalizedTarget,
      targetIndex: targetIndex,
      originalEvent: event,
      movedEvent: movedEvent,
      visibleEvents: visibleEvents,
      settings: settings,
    );
  }

  Future<CalendarEvent?> _moveRecurringEvent(
    WidgetRef ref,
    CalendarEvent occurrence,
    DateTime targetDate,
    _RecurringDragScope scope,
  ) async {
    final repository = ref.read(eventRepositoryProvider);
    final commandService = ref.read(eventCommandServiceProvider);
    final base = await repository.findById(occurrence.id);
    if (base == null) {
      return null;
    }
    final shiftedOccurrence = shiftCalendarEventToDate(occurrence, targetDate);

    switch (scope) {
      case _RecurringDragScope.onlyThis:
        await commandService.save(_excludeOccurrence(base, occurrence.startAt));
        return commandService.create(
          _eventDraftFrom(
            shiftedOccurrence,
            recurrence: const RecurrenceRule(),
          ),
        );
      case _RecurringDragScope.future:
        await commandService.save(_endBefore(base, occurrence.startAt));
        final futureRule = recurrenceRuleForMovedFuture(
          base: base,
          occurrence: occurrence,
          targetDate: targetDate,
        );
        final created = await commandService.create(
          _eventDraftFrom(shiftedOccurrence, recurrence: futureRule),
        );
        return created.copyWith(
          occurrenceId: '${created.id}@${created.startAt.toIso8601String()}',
        );
      case _RecurringDragScope.all:
        final dayDelta = calendarDayDifference(targetDate, occurrence.startAt);
        final shiftedBaseEvent = shiftCalendarEventToDate(
          base,
          shiftCalendarDateByDays(base.startAt, dayDelta),
        );
        final shiftedBase = shiftedBaseEvent.copyWith(
          recurrence: shiftRecurrenceRuleByDays(base.recurrence, dayDelta),
        );
        await commandService.save(shiftedBase);
        final shiftedStart = shiftCalendarDateByDays(
          occurrence.startAt,
          dayDelta,
        );
        return occurrence.copyWith(
          occurrenceId: '${base.id}@${shiftedStart.toIso8601String()}',
          startAt: shiftedStart,
          endAt: shiftedStart.add(occurrence.duration),
        );
    }
  }

  Future<void> _saveManualOrderAfterDrop(
    WidgetRef ref, {
    required DateTime sourceDate,
    required DateTime targetDate,
    required int targetIndex,
    required CalendarEvent originalEvent,
    required CalendarEvent movedEvent,
    required List<CalendarEvent> visibleEvents,
    required AppSettings settings,
  }) async {
    final sourceKey = calendarDateKey(sourceDate);
    final targetKey = calendarDateKey(targetDate);
    final originalOrderKey = calendarEventOrderKey(originalEvent);
    final movedOrderKey = calendarEventOrderKey(movedEvent);
    final categoryOrder = settings.categories
        .map((category) => category.id)
        .toList();
    final manualOrders = <String, CalendarManualEventOrder>{
      ...settings.calendarManualEventOrders,
    };
    final deviceId = await ref.read(settingsRepositoryProvider).deviceId();
    final now = DateTime.now();

    if (sourceKey != targetKey) {
      final sourceEvents = _eventsForDay(visibleEvents, sourceDate)
          .where(
            (candidate) =>
                calendarEventOrderKey(candidate) != originalOrderKey &&
                candidate.id != originalEvent.id,
          )
          .toList();
      manualOrders[sourceKey] = CalendarManualEventOrder(
        eventKeys: sourceEvents.map(calendarEventOrderKey).toList(),
        updatedAt: now,
        deviceId: deviceId,
      );
    }

    final existingTarget = _eventsForDay(visibleEvents, targetDate)
        .where(
          (candidate) =>
              calendarEventOrderKey(candidate) != originalOrderKey &&
              calendarEventOrderKey(candidate) != movedOrderKey &&
              candidate.id != originalEvent.id,
        )
        .toList();
    final sortedTarget = sortedCalendarEvents(
      existingTarget,
      priority: settings.calendarEventSortPriority,
      categoryOrder: categoryOrder,
      manualOrder:
          settings.calendarManualEventOrders[targetKey]?.eventKeys ??
          const <String>[],
    );
    final insertionIndex = targetIndex.clamp(0, sortedTarget.length);
    sortedTarget.insert(insertionIndex, movedEvent);
    manualOrders[targetKey] = CalendarManualEventOrder(
      eventKeys: sortedTarget.map(calendarEventOrderKey).toList(),
      updatedAt: now,
      deviceId: deviceId,
    );

    final updatedSettings = settings.copyWith(
      calendarManualEventOrders: manualOrders,
    );
    await ref.read(settingsRepositoryProvider).save(updatedSettings);
    ref.read(appSettingsProvider.notifier).state = updatedSettings;
    await ref.read(syncServiceProvider).queueSettingsBackup();
  }

  EventDraft _eventDraftFrom(
    CalendarEvent event, {
    required RecurrenceRule recurrence,
  }) {
    return EventDraft(
      title: event.title,
      memo: event.memo,
      location: event.location,
      url: event.url,
      weather: event.weather,
      startAt: event.startAt,
      endAt: event.endAt,
      allDay: event.allDay,
      category: event.category,
      colorValue: event.colorValue,
      reminderMinutesBeforeList: event.reminderMinutesBeforeList,
      recurrence: recurrence,
      showDday: event.showDday,
      alarmEnabled: event.alarmEnabled,
      allDayAlarmMinutes: event.allDayAlarmMinutes,
    );
  }

  CalendarEvent _excludeOccurrence(CalendarEvent base, DateTime occurrence) {
    final excludedDate = _dateOnly(occurrence);
    final excluded = {
      ...base.recurrence.excludedDates.map(_dateOnly),
      excludedDate,
    }.toList()..sort();
    return base.copyWith(
      recurrence: base.recurrence.copyWith(excludedDates: excluded),
    );
  }

  CalendarEvent _endBefore(CalendarEvent base, DateTime occurrence) {
    return base.copyWith(
      recurrence: base.recurrence.copyWith(
        until: _dateOnly(occurrence).subtract(const Duration(days: 1)),
        clearCount: true,
      ),
    );
  }

  Future<_RecurringDragScope?> _showRecurringDragScopeDialog(
    BuildContext context,
  ) {
    return showDialog<_RecurringDragScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('반복 일정 이동')),
        content: Text(context.tr('이 반복 일정의 어느 범위를 이동할까요?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('취소')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringDragScope.onlyThis),
            child: Text(context.tr('이 일정만')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringDragScope.future),
            child: Text(context.tr('이후 일정')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_RecurringDragScope.all),
            child: Text(context.tr('전체 반복')),
          ),
        ],
      ),
    );
  }
}

Future<void> _handleCalendarEventDrop(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
  DateTime targetDate,
  int targetIndex,
) async {
  if (!calendarEventCanMove(event)) {
    return;
  }
  final sourceDate = _dateOnly(event.startAt);
  final normalizedTarget = _dateOnly(targetDate);
  final rangeStart = sourceDate.isBefore(normalizedTarget)
      ? sourceDate
      : normalizedTarget;
  final rangeLastDate = sourceDate.isAfter(normalizedTarget)
      ? sourceDate
      : normalizedTarget;
  final rangeEnd = rangeLastDate.add(const Duration(days: 1));
  final settings = ref.read(appSettingsProvider);
  final repository = ref.read(eventRepositoryProvider);
  final storedEvents = await repository.eventsInRange(rangeStart, rangeEnd);
  final holidayEvents = ref
      .read(koreanHolidayServiceProvider)
      .holidayEventsInRange(
        rangeStart,
        rangeEnd,
        category: settings.holidayCategory,
      );
  final visibleEvents = _filterVisibleEvents(
    [...storedEvents, ...holidayEvents],
    settings,
    '',
  );
  if (!context.mounted) {
    return;
  }

  var movedEvent = event;
  if (!_sameDay(sourceDate, normalizedTarget)) {
    if (event.isRecurring) {
      final scope = await _showCalendarRecurringDragScopeDialog(context);
      if (scope == null || !context.mounted) {
        return;
      }
      final result = await _moveRecurringCalendarEvent(
        ref,
        event,
        normalizedTarget,
        scope,
      );
      if (result == null) {
        return;
      }
      movedEvent = result;
    } else {
      movedEvent = shiftCalendarEventToDate(event, normalizedTarget);
      await ref.read(eventCommandServiceProvider).save(movedEvent);
    }
  }

  await _saveCalendarManualOrderAfterDrop(
    ref,
    sourceDate: sourceDate,
    targetDate: normalizedTarget,
    targetIndex: targetIndex,
    originalEvent: event,
    movedEvent: movedEvent,
    visibleEvents: visibleEvents,
    settings: settings,
  );
}

Future<CalendarEvent?> _moveRecurringCalendarEvent(
  WidgetRef ref,
  CalendarEvent occurrence,
  DateTime targetDate,
  _RecurringDragScope scope,
) async {
  final repository = ref.read(eventRepositoryProvider);
  final commandService = ref.read(eventCommandServiceProvider);
  final base = await repository.findById(occurrence.id);
  if (base == null) {
    return null;
  }
  final shiftedOccurrence = shiftCalendarEventToDate(occurrence, targetDate);

  switch (scope) {
    case _RecurringDragScope.onlyThis:
      await commandService.save(
        _excludeCalendarOccurrence(base, occurrence.startAt),
      );
      return _createMovedCalendarOccurrence(
        commandService,
        shiftedOccurrence,
        const RecurrenceRule(),
      );
    case _RecurringDragScope.future:
      await commandService.save(
        _endCalendarRecurrenceBefore(base, occurrence.startAt),
      );
      final futureRule = recurrenceRuleForMovedFuture(
        base: base,
        occurrence: occurrence,
        targetDate: targetDate,
      );
      final created = await _createMovedCalendarOccurrence(
        commandService,
        shiftedOccurrence,
        futureRule,
      );
      return created.copyWith(
        occurrenceId: '${created.id}@${created.startAt.toIso8601String()}',
      );
    case _RecurringDragScope.all:
      final dayDelta = calendarDayDifference(targetDate, occurrence.startAt);
      final shiftedBaseEvent = shiftCalendarEventToDate(
        base,
        shiftCalendarDateByDays(base.startAt, dayDelta),
      );
      final shiftedBase = shiftedBaseEvent.copyWith(
        recurrence: shiftRecurrenceRuleByDays(base.recurrence, dayDelta),
      );
      await commandService.save(shiftedBase);
      final shiftedStart = shiftCalendarDateByDays(
        occurrence.startAt,
        dayDelta,
      );
      return occurrence.copyWith(
        occurrenceId: '${base.id}@${shiftedStart.toIso8601String()}',
        startAt: shiftedStart,
        endAt: shiftedStart.add(occurrence.duration),
      );
  }
}

Future<CalendarEvent> _createMovedCalendarOccurrence(
  EventCommandService commandService,
  CalendarEvent event,
  RecurrenceRule recurrence,
) async {
  final created = await commandService.create(
    _calendarEventDraftFrom(event, recurrence: recurrence),
  );
  if (!event.completed) {
    return created;
  }
  final completed = created.copyWith(completed: true);
  await commandService.save(completed);
  return completed;
}

Future<void> _saveCalendarManualOrderAfterDrop(
  WidgetRef ref, {
  required DateTime sourceDate,
  required DateTime targetDate,
  required int targetIndex,
  required CalendarEvent originalEvent,
  required CalendarEvent movedEvent,
  required List<CalendarEvent> visibleEvents,
  required AppSettings settings,
}) async {
  final sourceKey = calendarDateKey(sourceDate);
  final targetKey = calendarDateKey(targetDate);
  final originalOrderKey = calendarEventOrderKey(originalEvent);
  final movedOrderKey = calendarEventOrderKey(movedEvent);
  final categoryOrder = settings.categories
      .map((category) => category.id)
      .toList();
  final manualOrders = <String, CalendarManualEventOrder>{
    ...settings.calendarManualEventOrders,
  };
  final deviceId = await ref.read(settingsRepositoryProvider).deviceId();
  final now = DateTime.now();

  if (sourceKey != targetKey) {
    final sourceEvents = _eventsForDay(visibleEvents, sourceDate)
        .where(
          (candidate) =>
              calendarEventOrderKey(candidate) != originalOrderKey &&
              candidate.id != originalEvent.id,
        )
        .toList();
    manualOrders[sourceKey] = CalendarManualEventOrder(
      eventKeys: sourceEvents.map(calendarEventOrderKey).toList(),
      updatedAt: now,
      deviceId: deviceId,
    );
  }

  final existingTarget = _eventsForDay(visibleEvents, targetDate)
      .where(
        (candidate) =>
            calendarEventOrderKey(candidate) != originalOrderKey &&
            calendarEventOrderKey(candidate) != movedOrderKey &&
            candidate.id != originalEvent.id,
      )
      .toList();
  final sortedTarget = sortedCalendarEvents(
    existingTarget,
    priority: settings.calendarEventSortPriority,
    categoryOrder: categoryOrder,
    manualOrder:
        settings.calendarManualEventOrders[targetKey]?.eventKeys ??
        const <String>[],
  );
  final insertionIndex = targetIndex.clamp(0, sortedTarget.length);
  sortedTarget.insert(insertionIndex, movedEvent);
  manualOrders[targetKey] = CalendarManualEventOrder(
    eventKeys: sortedTarget.map(calendarEventOrderKey).toList(),
    updatedAt: now,
    deviceId: deviceId,
  );

  final updatedSettings = settings.copyWith(
    calendarManualEventOrders: manualOrders,
  );
  await ref.read(settingsRepositoryProvider).save(updatedSettings);
  ref.read(appSettingsProvider.notifier).state = updatedSettings;
  await ref.read(syncServiceProvider).queueSettingsBackup();
}

EventDraft _calendarEventDraftFrom(
  CalendarEvent event, {
  required RecurrenceRule recurrence,
}) {
  return EventDraft(
    title: event.title,
    memo: event.memo,
    location: event.location,
    url: event.url,
    weather: event.weather,
    startAt: event.startAt,
    endAt: event.endAt,
    allDay: event.allDay,
    category: event.category,
    colorValue: event.colorValue,
    reminderMinutesBeforeList: event.reminderMinutesBeforeList,
    recurrence: recurrence,
    showDday: event.showDday,
    alarmEnabled: event.alarmEnabled,
    allDayAlarmMinutes: event.allDayAlarmMinutes,
  );
}

CalendarEvent _excludeCalendarOccurrence(
  CalendarEvent base,
  DateTime occurrence,
) {
  final excludedDate = _dateOnly(occurrence);
  final excluded = {
    ...base.recurrence.excludedDates.map(_dateOnly),
    excludedDate,
  }.toList()..sort();
  return base.copyWith(
    recurrence: base.recurrence.copyWith(excludedDates: excluded),
  );
}

CalendarEvent _endCalendarRecurrenceBefore(
  CalendarEvent base,
  DateTime occurrence,
) {
  return base.copyWith(
    recurrence: base.recurrence.copyWith(
      until: _dateOnly(occurrence).subtract(const Duration(days: 1)),
      clearCount: true,
    ),
  );
}

Future<_RecurringDragScope?> _showCalendarRecurringDragScopeDialog(
  BuildContext context,
) {
  return showDialog<_RecurringDragScope>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('반복 일정 이동')),
      content: Text(context.tr('이 반복 일정의 어느 범위를 이동할까요?')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('취소')),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_RecurringDragScope.onlyThis),
          child: Text(context.tr('이 일정만')),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_RecurringDragScope.future),
          child: Text(context.tr('이후 일정')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_RecurringDragScope.all),
          child: Text(context.tr('전체 반복')),
        ),
      ],
    ),
  );
}

Future<void> _openRangeEventEditor(
  BuildContext context,
  WidgetRef ref,
  DateTime start,
  DateTime end,
  List<EventCategory> categories,
  List<int> defaultReminderMinutesList,
) async {
  final analytics = ref.read(productAnalyticsProvider);
  final stopwatch = Stopwatch()..start();
  unawaited(
    analytics
        .record(
          AnalyticsRecord.eventEditorOpened(
            AnalyticsEditorMode.create,
            trigger: AnalyticsTrigger.manual,
          ),
        )
        .catchError((_) {}),
  );
  final draft = await showDialog<EventDraft>(
    context: context,
    builder: (_) => EventEditorDialog(
      initialDate: start,
      initialEndDate: end,
      initialAllDay: true,
      categories: categories,
      defaultReminderMinutesList: defaultReminderMinutesList,
      alarmService: ref.read(alarmServiceProvider),
    ),
  );
  unawaited(
    analytics
        .record(
          AnalyticsRecord.eventEditorCompleted(
            AnalyticsEditorMode.create,
            outcome: draft == null
                ? AnalyticsOutcome.canceled
                : AnalyticsOutcome.succeeded,
            durationMs: stopwatch.elapsedMilliseconds,
          ),
        )
        .catchError((_) {}),
  );
  if (draft != null) {
    await ref.read(eventCommandServiceProvider).create(draft);
  }
}

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader({
    required this.month,
    required this.selectedDate,
    required this.viewMode,
    required this.monthNavigationMode,
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
  final MonthNavigationMode monthNavigationMode;
  final String searchQuery;
  final bool searchOpen;
  final bool quickAccessSelected;
  final VoidCallback onSearchPressed;
  final VoidCallback onQuickAccessPressed;
  final ValueChanged<CalendarViewMode> onCalendarViewSelected;
  final VoidCallback onLlmPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 680;
    final platform = Theme.of(context).platform;
    final ios = platform == TargetPlatform.iOS;
    final desktop = _usesMacDesktopExperience(platform);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final settings = ref.watch(appSettingsProvider);
    final label = calendarPeriodLabel(
      visibleMonth: month,
      selectedDate: selectedDate,
      viewMode: viewMode,
      navigationMode: monthNavigationMode,
      locale: locale,
      weekStartsOnMonday: settings.weekStartsOnMonday,
      // Android's compact toolbar reserves fixed-width navigation and utility
      // actions, so horizontal navigation keeps its existing year-only label.
      compactHorizontalYearOnly: compact && !ios,
    );
    final periodLabelMaxWidth =
        ios &&
            monthNavigationMode == MonthNavigationMode.vertical &&
            viewMode == CalendarViewMode.week
        ? 164.0
        : 126.0;
    final colorScheme = Theme.of(context).colorScheme;
    final monthButton = TextButton.icon(
      key: const ValueKey('calendar-period-button'),
      onPressed: () => _showMonthPicker(context, ref),
      icon: const Icon(Icons.date_range_rounded, size: 20),
      label: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ios ? periodLabelMaxWidth : double.infinity,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            style: compact
                ? Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 18)
                : Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: ios ? const Size(0, 44) : null,
        maximumSize: ios ? Size(periodLabelMaxWidth + 44, 44) : null,
        tapTargetSize: ios
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    final navigationActions = [
      DailyIconAction(
        tooltip: context.tr('이전'),
        onPressed: () => _moveVisibleRange(ref, -1),
        icon: Icons.arrow_back_ios_new_rounded,
        borderless: true,
      ),
      DailyIconAction(
        tooltip: context.tr('다음'),
        onPressed: () => _moveVisibleRange(ref, 1),
        icon: Icons.arrow_forward_ios_rounded,
        borderless: true,
      ),
      DailyIconAction(
        tooltip: context.tr('오늘'),
        onPressed: () => _goToday(ref),
        icon: Icons.calendar_today_rounded,
        borderless: true,
      ),
    ];
    final utilityActions = [
      DailyIconAction(
        tooltip: context.tr(searchOpen ? '검색 닫기' : '검색'),
        onPressed: onSearchPressed,
        selected: searchOpen,
        icon: Icons.search_rounded,
        borderless: true,
      ),
      DailyIconAction(
        tooltip: context.tr('검색/필터'),
        onPressed: () => _showFilterSheet(context, ref),
        selected: searchQuery.isNotEmpty,
        icon: Icons.tune_rounded,
        borderless: true,
      ),
      DailyIconAction(
        tooltip: context.tr('설정'),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        icon: Icons.settings_rounded,
        borderless: true,
      ),
    ];

    if (desktop) {
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
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : colorScheme.onSurfaceVariant,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? DailyUi.primary
                : DailyUi.groupedSurface(context),
          ),
          side: WidgetStateProperty.all(BorderSide.none),
        ),
        segments: [
          ButtonSegment(
            value: CalendarViewMode.week,
            label: Text(
              context.l10n.compactCalendarViewName(CalendarViewMode.week),
            ),
          ),
          ButtonSegment(
            value: CalendarViewMode.month,
            label: Text(
              context.l10n.compactCalendarViewName(CalendarViewMode.month),
            ),
          ),
          ButtonSegment(
            value: CalendarViewMode.day,
            label: Text(
              context.l10n.compactCalendarViewName(CalendarViewMode.day),
            ),
          ),
        ],
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onCalendarViewSelected(selection.first);
          }
        },
      );
      final quickAccessButton = DailyIconAction(
        tooltip: context.tr('빠른 보기'),
        selected: quickAccessSelected,
        onPressed: onQuickAccessPressed,
        icon: Icons.view_agenda_outlined,
        selectedIcon: Icons.view_agenda_rounded,
        borderless: true,
      );
      final llmButton = DailyIconAction(
        tooltip: 'LLM',
        onPressed: onLlmPressed,
        icon: Icons.stars_rounded,
        accentColor: DailyUi.purple,
        borderless: true,
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
        key: ios ? const ValueKey('ios-calendar-toolbar') : null,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (ios) ...[
              monthButton,
              const Expanded(
                child: SizedBox(
                  key: ValueKey('ios-calendar-header-reserved-space'),
                ),
              ),
            ] else ...[
              Expanded(child: monthButton),
              ...navigationActions.take(2),
            ],
            navigationActions[2],
            utilityActions[0],
            utilityActions[1],
            utilityActions[2],
          ],
        ),
      );
    }

    return Padding(
      key: ios ? const ValueKey('ios-calendar-toolbar') : null,
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
    final picked = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _YearOverviewPage(
          initialMonth: month,
          navigationMode: monthNavigationMode,
        ),
      ),
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
      showDragHandle: false,
      backgroundColor: DailyUi.pageBackground(context),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final viewInsets = MediaQuery.viewInsetsOf(context);
          final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  DailyUi.isDesktop ? 24 : 16,
                  10,
                  DailyUi.isDesktop ? 24 : 16,
                  20,
                ),
                shrinkWrap: true,
                children: [
                  const DailySheetHandle(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const DailySettingsIcon(icon: Icons.filter_alt_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('검색/필터'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      DailyIconAction(
                        tooltip: context.tr('닫기'),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).pop();
                        },
                        icon: Icons.close_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: queryController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('현재 보기에서 검색'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      fillColor: DailyUi.groupedSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: DailyUi.separator(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: DailyUi.separator(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: DailyUi.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (value) =>
                        ref.read(calendarSearchQueryProvider.notifier).state =
                            value.trim(),
                  ),
                  const SizedBox(height: 4),
                  DailyGroupedSection(
                    label: context.tr('표시 옵션'),
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        secondary: const Icon(Icons.flag_outlined),
                        value: ddayOnly,
                        title: Text(context.tr('D-day 일정만 보기')),
                        onChanged: (value) async {
                          setState(() => ddayOnly = value);
                          final updated = ref
                              .read(appSettingsProvider)
                              .copyWith(calendarDdayOnly: value);
                          await ref
                              .read(settingsRepositoryProvider)
                              .save(updated);
                          ref.read(appSettingsProvider.notifier).state =
                              updated;
                        },
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        secondary: const Icon(Icons.celebration_outlined),
                        value: showHolidays,
                        title: Text(context.tr('공휴일 표시')),
                        onChanged: (value) async {
                          setState(() => showHolidays = value);
                          final updated = ref
                              .read(appSettingsProvider)
                              .copyWith(calendarShowHolidays: value);
                          await ref
                              .read(settingsRepositoryProvider)
                              .save(updated);
                          ref.read(appSettingsProvider.notifier).state =
                              updated;
                        },
                      ),
                    ],
                  ),
                  DailySectionLabel(context.tr('분류 표시')),
                  Material(
                    color: DailyUi.groupedSurface(context),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: DailyUi.separator(context)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in settings.categories)
                            FilterChip(
                              avatar: CircleAvatar(
                                radius: 5,
                                backgroundColor: Color(category.colorValue),
                              ),
                              label: Text(
                                context.l10n.categoryName(
                                  id: category.id,
                                  label: category.label,
                                ),
                              ),
                              selected: !hidden.contains(category.id),
                              selectedColor: DailyUi.primary.withValues(
                                alpha:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.28
                                    : 0.13,
                              ),
                              checkmarkColor: DailyUi.primary,
                              shape: const StadiumBorder(),
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
                                    .copyWith(
                                      hiddenCategoryIds: hidden.toList(),
                                    );
                                await ref
                                    .read(settingsRepositoryProvider)
                                    .save(updated);
                                ref.read(appSettingsProvider.notifier).state =
                                    updated;
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            queryController.clear();
                            ref
                                    .read(calendarSearchQueryProvider.notifier)
                                    .state =
                                '';
                          },
                          icon: const Icon(Icons.clear_rounded),
                          label: Text(context.tr('검색어 지우기')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: DailyUi.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(context.tr('완료')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      unawaited(
        ref
            .read(productAnalyticsProvider)
            .record(
              AnalyticsRecord.featureUsed(
                AnalyticsFeature.filter,
                outcome: AnalyticsOutcome.succeeded,
              ),
            )
            .catchError((_) {}),
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => queryController.dispose(),
      );
    });
  }
}

class _CalendarBottomBar extends StatelessWidget {
  const _CalendarBottomBar({
    super.key,
    required this.viewMode,
    required this.calendarActive,
    required this.activeAction,
    required this.selectedAction,
    required this.calendarViewControlSelected,
    required this.onCalendarViewInteractionStarted,
    required this.onCalendarViewSelected,
    required this.onCenterActionSelected,
  });

  final CalendarViewMode viewMode;
  final bool calendarActive;
  final _BottomCenterAction activeAction;
  final _BottomCenterAction? selectedAction;
  final bool calendarViewControlSelected;
  final VoidCallback onCalendarViewInteractionStarted;
  final ValueChanged<CalendarViewMode> onCalendarViewSelected;
  final ValueChanged<_BottomCenterAction> onCenterActionSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        key: const ValueKey('calendar-bottom-bar'),
        height: 62,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const horizontalInset = 16.0;
            const gap = 8.0;
            const expandedViewHeight = 48.0;
            const collapsedViewHeight = 40.0;
            const minimumViewWidth = 60.0;
            final centerExpanded = selectedAction != null;
            final centerWidth = centerExpanded ? 152.0 : 124.0;
            final centerLeft = (constraints.maxWidth - centerWidth) / 2;
            final desiredViewWidth = _preferredCalendarViewWidth(
              context,
              expanded: calendarViewControlSelected,
            );
            final desiredViewHeight = calendarViewControlSelected
                ? expandedViewHeight
                : collapsedViewHeight;
            final viewWidth = (centerLeft - horizontalInset - gap).clamp(
              minimumViewWidth,
              desiredViewWidth,
            );
            final viewHeight =
                desiredViewHeight * (viewWidth / desiredViewWidth);
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (calendarActive)
                  Positioned(
                    left: horizontalInset,
                    top: (62 - viewHeight) / 2,
                    child: _CalendarViewButton(
                      width: viewWidth,
                      expanded: calendarViewControlSelected,
                      viewMode: viewMode,
                      onInteractionStarted: onCalendarViewInteractionStarted,
                      onChanged: onCalendarViewSelected,
                    ),
                  ),
                Align(
                  alignment: Alignment.center,
                  child: _BottomModeSwitcher(
                    activeAction: activeAction,
                    selectedAction: selectedAction,
                    onChanged: onCenterActionSelected,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

double _preferredCalendarViewWidth(
  BuildContext context, {
  required bool expanded,
}) {
  final fontSize = expanded ? 13.0 : 11.0;
  final fontWeight = expanded ? FontWeight.w800 : FontWeight.w600;
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);
  var labelsWidth = 0.0;
  for (final mode in CalendarViewMode.values) {
    final painter = TextPainter(
      text: TextSpan(
        text: context.l10n.compactCalendarViewName(mode),
        style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    labelsWidth += painter.width;
  }
  final baseWidth = expanded ? 96.0 : 76.0;
  const horizontalPaddingPerLabel = 8.0;
  return math.max(
    baseWidth,
    labelsWidth + horizontalPaddingPerLabel * CalendarViewMode.values.length,
  );
}

class _CalendarViewButton extends StatefulWidget {
  const _CalendarViewButton({
    required this.width,
    required this.expanded,
    required this.viewMode,
    required this.onInteractionStarted,
    required this.onChanged,
  });

  final double width;
  final bool expanded;
  final CalendarViewMode viewMode;
  final VoidCallback onInteractionStarted;
  final ValueChanged<CalendarViewMode> onChanged;

  @override
  State<_CalendarViewButton> createState() => _CalendarViewButtonState();
}

class _CalendarViewButtonState extends State<_CalendarViewButton> {
  CalendarViewMode? _dragMode;
  CalendarViewMode? _pressedMode;

  CalendarViewMode get _visibleMode =>
      _dragMode ?? _pressedMode ?? widget.viewMode;

  @override
  Widget build(BuildContext context) {
    final preferredWidth = widget.expanded ? 96.0 : 76.0;
    final preferredHeight = widget.expanded ? 48.0 : 40.0;
    final preferredFontSize = widget.expanded ? 13.0 : 11.0;
    final scale = (widget.width / preferredWidth).clamp(0.625, 1.0);
    final height = preferredHeight * scale;
    final fontSize = (preferredFontSize * scale).clamp(9.0, 13.0);
    return GestureDetector(
      key: const ValueKey('calendar-view-button'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        setState(() => _pressedMode = null);
        widget.onInteractionStarted();
        _preview(details.localPosition.dx);
      },
      onHorizontalDragUpdate: (details) => _preview(details.localPosition.dx),
      onHorizontalDragEnd: (_) {
        final mode = _dragMode;
        setState(() => _dragMode = null);
        if (mode != null) {
          widget.onChanged(mode);
        }
      },
      onHorizontalDragCancel: () => setState(() => _dragMode = null),
      child: AnimatedContainer(
        key: const ValueKey('calendar-view-track'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: widget.width,
        height: height,
        decoration: ShapeDecoration(
          color: DailyUi.elevatedSurface(context),
          shape: const StadiumBorder(),
        ),
        clipBehavior: Clip.none,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, innerConstraints) {
                final thumbSize = innerConstraints.maxHeight;
                final segmentWidth = innerConstraints.maxWidth / 3;
                final thumbLeft =
                    _indexFor(_visibleMode) * segmentWidth +
                    (segmentWidth - thumbSize) / 2;
                return Stack(
                  key: const ValueKey('calendar-view-thumb-layer'),
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      key: const ValueKey('calendar-view-thumb'),
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOutCubic,
                      left: thumbLeft,
                      top: 0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 110),
                        curve: Curves.easeOutCubic,
                        scale: _pressedMode == null ? 1 : 0.90,
                        child: SizedBox.square(
                          key: const ValueKey('calendar-view-thumb-circle'),
                          dimension: thumbSize,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: DailyUi.primary,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1a0f172a),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final mode in CalendarViewMode.values)
                          Expanded(
                            child: Tooltip(
                              message: context.l10n.calendarViewName(mode),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) {
                                  widget.onInteractionStarted();
                                  setState(() => _pressedMode = mode);
                                },
                                onTap: () {
                                  setState(() => _pressedMode = null);
                                  widget.onChanged(mode);
                                },
                                onTapCancel: () =>
                                    setState(() => _pressedMode = null),
                                child: Center(
                                  child: Text(
                                    context.l10n.compactCalendarViewName(mode),
                                    style: TextStyle(
                                      color: mode == _visibleMode
                                          ? Colors.white
                                          : DailyUi.secondaryText(context),
                                      fontSize: fontSize,
                                      fontWeight: mode == _visibleMode
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _preview(double dx) {
    final index = (dx / (widget.width / 3)).floor().clamp(0, 2);
    final mode = CalendarViewMode.values[index];
    if (_dragMode != mode) {
      setState(() => _dragMode = mode);
    }
  }

  int _indexFor(CalendarViewMode mode) => switch (mode) {
    CalendarViewMode.week => 0,
    CalendarViewMode.month => 1,
    CalendarViewMode.day => 2,
  };
}

class _BottomModeSwitcher extends StatefulWidget {
  const _BottomModeSwitcher({
    required this.activeAction,
    required this.selectedAction,
    required this.onChanged,
  });

  final _BottomCenterAction activeAction;
  final _BottomCenterAction? selectedAction;
  final ValueChanged<_BottomCenterAction> onChanged;

  @override
  State<_BottomModeSwitcher> createState() => _BottomModeSwitcherState();
}

class _BottomModeSwitcherState extends State<_BottomModeSwitcher> {
  _BottomCenterAction? _dragAction;
  _BottomCenterAction? _pressedAction;

  _BottomCenterAction get _visibleAction =>
      _dragAction ??
      _pressedAction ??
      widget.selectedAction ??
      widget.activeAction;

  @override
  Widget build(BuildContext context) {
    const expandedWidth = 152.0;
    const collapsedWidth = 124.0;
    const expandedHeight = 48.0;
    const collapsedHeight = 40.0;
    final action = _visibleAction;
    final expanded =
        _dragAction != null ||
        _pressedAction != null ||
        widget.selectedAction != null;
    final width = expanded ? expandedWidth : collapsedWidth;
    final height = expanded ? expandedHeight : collapsedHeight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      child: GestureDetector(
        key: const ValueKey('bottom-mode-switcher'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          setState(() => _pressedAction = null);
          _updateDrag(details.localPosition.dx, width);
        },
        onHorizontalDragUpdate: (details) =>
            _updateDrag(details.localPosition.dx, width),
        onHorizontalDragEnd: (_) {
          final selected = _dragAction;
          setState(() => _dragAction = null);
          if (selected != null) {
            widget.onChanged(selected);
          }
        },
        onHorizontalDragCancel: () => setState(() => _dragAction = null),
        child: Container(
          key: const ValueKey('bottom-mode-track'),
          decoration: ShapeDecoration(
            color: DailyUi.elevatedSurface(context),
            shape: const StadiumBorder(),
          ),
          clipBehavior: Clip.none,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (context, innerConstraints) {
                  final thumbSize = innerConstraints.maxHeight;
                  final segmentWidth = innerConstraints.maxWidth / 3;
                  final thumbLeft =
                      _indexFor(action) * segmentWidth +
                      (segmentWidth - thumbSize) / 2;
                  return Stack(
                    key: const ValueKey('bottom-mode-thumb-layer'),
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        key: const ValueKey('bottom-mode-thumb'),
                        duration: const Duration(milliseconds: 170),
                        curve: Curves.easeOutCubic,
                        left: thumbLeft,
                        top: 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 110),
                          curve: Curves.easeOutCubic,
                          scale: _pressedAction == null ? 1 : 0.90,
                          child: SizedBox.square(
                            key: const ValueKey('bottom-mode-thumb-circle'),
                            dimension: thumbSize,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: DailyUi.primary,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1a0f172a),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _BottomModeButton(
                            tooltip: context.tr('빠른 보기'),
                            icon: Icons.view_agenda_outlined,
                            selected: action == _BottomCenterAction.quickAccess,
                            onTapDown: () =>
                                _press(_BottomCenterAction.quickAccess),
                            onPressed: () =>
                                _selectPressed(_BottomCenterAction.quickAccess),
                            onTapCancel: _cancelPress,
                          ),
                          _BottomModeButton(
                            tooltip: context.tr('달력'),
                            icon: Icons.date_range_rounded,
                            selected: action == _BottomCenterAction.calendar,
                            onTapDown: () =>
                                _press(_BottomCenterAction.calendar),
                            onPressed: () =>
                                _selectPressed(_BottomCenterAction.calendar),
                            onTapCancel: _cancelPress,
                          ),
                          _BottomModeButton(
                            tooltip: 'AI',
                            icon: Icons.stars_rounded,
                            selected: action == _BottomCenterAction.ai,
                            onTapDown: () => _press(_BottomCenterAction.ai),
                            onPressed: () =>
                                _selectPressed(_BottomCenterAction.ai),
                            onTapCancel: _cancelPress,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateDrag(double dx, double width) {
    final index = (dx / (width / 3)).floor().clamp(0, 2);
    final action = _BottomCenterAction.values[index];
    if (_dragAction != action) {
      setState(() => _dragAction = action);
    }
  }

  void _press(_BottomCenterAction action) {
    setState(() => _pressedAction = action);
  }

  void _selectPressed(_BottomCenterAction fallback) {
    final action = _pressedAction ?? fallback;
    setState(() => _pressedAction = null);
    widget.onChanged(action);
  }

  void _cancelPress() {
    if (_pressedAction != null) {
      setState(() => _pressedAction = null);
    }
  }

  int _indexFor(_BottomCenterAction action) => switch (action) {
    _BottomCenterAction.quickAccess => 0,
    _BottomCenterAction.calendar => 1,
    _BottomCenterAction.ai => 2,
  };
}

class _BottomModeButton extends StatelessWidget {
  const _BottomModeButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTapDown,
    required this.onPressed,
    required this.onTapCancel,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTapDown;
  final VoidCallback onPressed;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => onTapDown(),
          onTap: onPressed,
          onTapCancel: onTapCancel,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : DailyUi.secondaryText(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTodoGroup {
  const _QuickTodoGroup(this.category, this.events);

  final EventCategory category;
  final List<CalendarEvent> events;
}

class _QuickTodoEmptyState extends StatelessWidget {
  const _QuickTodoEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DailyUi.groupedSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DailyUi.separator(context).withValues(alpha: 0.78),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: DailyUi.tertiaryText(context),
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DailyUi.secondaryText(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTodoCategoryCard extends StatelessWidget {
  const _QuickTodoCategoryCard({
    required this.group,
    required this.onCompletedChanged,
    required this.onOpen,
  });

  final _QuickTodoGroup group;
  final Future<void> Function(CalendarEvent event, bool completed)
  onCompletedChanged;
  final ValueChanged<CalendarEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(group.category.colorValue);
    return Material(
      key: ValueKey('quick-todo-category-${group.category.id}'),
      color: DailyUi.groupedSurface(context),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: DailyUi.separator(context).withValues(alpha: 0.78),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              color: categoryColor.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.16
                    : 0.09,
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.categoryName(
                        id: group.category.id,
                        label: group.category.label,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Text(
                    '${group.events.where((event) => event.completed).length}/${group.events.length}',
                    style: TextStyle(
                      color: DailyUi.secondaryText(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < group.events.length; index++) ...[
              _QuickTodoRow(
                event: group.events[index],
                onCompletedChanged: onCompletedChanged,
                onOpen: onOpen,
              ),
              if (index != group.events.length - 1)
                Divider(
                  height: 1,
                  indent: 46,
                  color: DailyUi.separator(context),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickTodoRow extends StatelessWidget {
  const _QuickTodoRow({
    required this.event,
    required this.onCompletedChanged,
    required this.onOpen,
  });

  final CalendarEvent event;
  final Future<void> Function(CalendarEvent event, bool completed)
  onCompletedChanged;
  final ValueChanged<CalendarEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat.Md(locale).format(event.startAt);
    final timeLabel = event.allDay
        ? context.tr('종일')
        : DateFormat.Hm(locale).format(event.startAt);
    final titleStyle = calendarEventCompletionStyle(
      context,
      Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      completed: event.completed,
    );
    final eventKey = event.occurrenceId ?? event.id;
    return Row(
      children: [
        Checkbox(
          key: ValueKey('quick-todo-checkbox-$eventKey'),
          value: event.completed,
          shape: const CircleBorder(),
          side: BorderSide(color: DailyUi.tertiaryText(context), width: 1.8),
          activeColor: DailyUi.success,
          onChanged: (value) {
            if (value != null) {
              unawaited(onCompletedChanged(event, value));
            }
          },
        ),
        Expanded(
          child: InkWell(
            key: ValueKey('quick-todo-open-$eventKey'),
            onTap: () => onOpen(event),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 11, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      context.l10n.eventTitle(
                        event.title,
                        holiday: event.holiday,
                      ),
                      textAlign: TextAlign.start,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle.copyWith(
                        fontSize: 14,
                        height: 1.25,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      '$dateLabel · $timeLabel',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: DailyUi.secondaryText(context),
                        fontSize: 11,
                        height: 1.25,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _YearOverviewPage extends StatefulWidget {
  const _YearOverviewPage({
    required this.initialMonth,
    required this.navigationMode,
  });

  final DateTime initialMonth;
  final MonthNavigationMode navigationMode;

  @override
  State<_YearOverviewPage> createState() => _YearOverviewPageState();
}

class _YearOverviewPageState extends State<_YearOverviewPage> {
  static const _initialPage = 12000;
  static const _yearBuffer = 200;

  late final PageController _horizontalController;
  late final ScrollController _verticalController;
  final _verticalCenterKey = GlobalKey();
  late final int _anchorYear;
  double _verticalYearExtent = 1;
  DateTime? _lastPointerYearMoveAt;

  @override
  void initState() {
    super.initState();
    _anchorYear = widget.initialMonth.year;
    _horizontalController = PageController(initialPage: _initialPage);
    _verticalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.navigationMode == MonthNavigationMode.vertical;
    final desktop = _usesMacDesktopExperience(Theme.of(context).platform);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.tr('닫기'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = desktop && constraints.maxWidth >= 1000 ? 2 : 1;
          final horizontalRows = desktop && constraints.maxHeight >= 1040
              ? 2
              : 1;
          return vertical
              ? _buildVerticalYears(
                  columns: columns,
                  desktop: desktop,
                  viewportHeight: constraints.maxHeight,
                )
              : _buildHorizontalYears(columns: columns, rows: horizontalRows);
        },
      ),
    );
  }

  Widget _buildHorizontalYears({required int columns, required int rows}) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent || !_horizontalController.hasClients) {
          return;
        }
        final primaryDelta =
            event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()
            ? event.scrollDelta.dx
            : event.scrollDelta.dy;
        if (primaryDelta.abs() < 8) {
          return;
        }
        final now = DateTime.now();
        if (_lastPointerYearMoveAt != null &&
            now.difference(_lastPointerYearMoveAt!) <
                const Duration(milliseconds: 300)) {
          return;
        }
        _lastPointerYearMoveAt = now;
        final currentPage = _horizontalController.page?.round() ?? _initialPage;
        unawaited(
          _horizontalController.animateToPage(
            currentPage + (primaryDelta > 0 ? 1 : -1),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          ),
        );
      },
      child: PageView.builder(
        key: const ValueKey('year-overview-page-view'),
        controller: _horizontalController,
        physics: const _ResponsiveMonthPagePhysics(),
        itemBuilder: (context, page) => _yearGrid(
          firstYear: _yearForPage(page),
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  Widget _buildVerticalYears({
    required int columns,
    required bool desktop,
    required double viewportHeight,
  }) {
    _verticalYearExtent = desktop
        ? math.min(viewportHeight, 680)
        : viewportHeight;
    return CustomScrollView(
      key: const ValueKey('year-overview-continuous-scroll'),
      controller: _verticalController,
      center: _verticalCenterKey,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverList.builder(
          itemCount: _yearBuffer,
          itemBuilder: (context, index) => SizedBox(
            height: _verticalYearExtent,
            child: _yearGrid(
              firstYear: _anchorYear - (index + 1) * columns,
              columns: columns,
              rows: 1,
            ),
          ),
        ),
        SliverList.builder(
          key: _verticalCenterKey,
          itemBuilder: (context, index) => SizedBox(
            height: _verticalYearExtent,
            child: _yearGrid(
              firstYear: _anchorYear + index * columns,
              columns: columns,
              rows: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _yearPage(int year) {
    return _YearCalendarPage(
      year: year,
      weekStartsOnMonday: false,
      onMonthSelected: (month) =>
          Navigator.of(context).pop(DateTime(year, month)),
    );
  }

  Widget _yearGrid({
    required int firstYear,
    required int columns,
    required int rows,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _yearPage(firstYear + row * columns + column),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _yearForPage(int page) => _anchorYear + page - _initialPage;
}

class _YearCalendarPage extends StatelessWidget {
  const _YearCalendarPage({
    required this.year,
    required this.weekStartsOnMonday,
    required this.onMonthSelected,
  });

  final int year;
  final bool weekStartsOnMonday;
  final ValueChanged<int> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : 3;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '$year년',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildMonthGrid(width, columns)),
          ],
        );
      },
    );
  }

  Widget _buildMonthGrid(double width, int columns) {
    final spacing = width < 500 ? 8.0 : 14.0;
    final rowCount = (12 / columns).ceil();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        width < 500 ? 10 : 20,
        0,
        width < 500 ? 10 : 20,
        18,
      ),
      child: Column(
        children: [
          for (var row = 0; row < rowCount; row++) ...[
            if (row > 0) SizedBox(height: spacing),
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) SizedBox(width: spacing),
                    Expanded(
                      child: row * columns + column < 12
                          ? _MiniMonthCalendar(
                              year: year,
                              month: row * columns + column + 1,
                              weekStartsOnMonday: weekStartsOnMonday,
                              onTap: () =>
                                  onMonthSelected(row * columns + column + 1),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMonthCalendar extends StatelessWidget {
  const _MiniMonthCalendar({
    required this.year,
    required this.month,
    required this.weekStartsOnMonday,
    required this.onTap,
  });

  final int year;
  final int month;
  final bool weekStartsOnMonday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthDate = DateTime(year, month);
    final monthLabel = DateFormat.MMMM(locale).format(monthDate);
    return Semantics(
      label: DateFormat.yMMMM(locale).format(monthDate),
      button: true,
      child: InkWell(
        key: ValueKey('mini-month-$year-$month'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox.expand(
          child: CustomPaint(
            key: ValueKey('mini-month-canvas-$year-$month'),
            painter: _MiniMonthPainter(
              year: year,
              month: month,
              monthLabel: monthLabel,
              weekdayLabels: _localizedWeekdayLabels(
                context,
                weekStartsOnMonday: weekStartsOnMonday,
              ),
              weekStartsOnMonday: weekStartsOnMonday,
              today: DateTime(now.year, now.month, now.day),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              monthStyle: (theme.textTheme.labelLarge ?? const TextStyle())
                  .copyWith(fontWeight: FontWeight.w800),
              weekdayStyle: (theme.textTheme.labelSmall ?? const TextStyle())
                  .copyWith(fontSize: 8),
              dayStyle: TextStyle(
                fontSize: 8,
                height: 1,
                color: colorScheme.onSurface,
              ),
              sundayColor: colorScheme.error,
              saturdayColor: colorScheme.primary,
              weekdayColor: colorScheme.onSurfaceVariant,
              todayBackground: colorScheme.primary,
              todayForeground: colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMonthPainter extends CustomPainter {
  const _MiniMonthPainter({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.weekdayLabels,
    required this.weekStartsOnMonday,
    required this.today,
    required this.textDirection,
    required this.textScaler,
    required this.monthStyle,
    required this.weekdayStyle,
    required this.dayStyle,
    required this.sundayColor,
    required this.saturdayColor,
    required this.weekdayColor,
    required this.todayBackground,
    required this.todayForeground,
  });

  final int year;
  final int month;
  final String monthLabel;
  final List<String> weekdayLabels;
  final bool weekStartsOnMonday;
  final DateTime today;
  final ui.TextDirection textDirection;
  final TextScaler textScaler;
  final TextStyle monthStyle;
  final TextStyle weekdayStyle;
  final TextStyle dayStyle;
  final Color sundayColor;
  final Color saturdayColor;
  final Color weekdayColor;
  final Color todayBackground;
  final Color todayForeground;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 4.0;
    final contentWidth = math.max(0.0, size.width - inset * 2);
    final monthPainter = _textPainter(monthLabel, monthStyle);
    monthPainter.paint(canvas, Offset(inset, inset));

    final weekdayTop = inset + monthPainter.height + 3;
    final weekdayHeight = _scaledFontHeight(weekdayStyle);
    final cellWidth = contentWidth / 7;
    for (var column = 0; column < 7; column++) {
      final color = column == 0
          ? sundayColor
          : column == 6
          ? saturdayColor
          : weekdayColor;
      final painter = _textPainter(
        weekdayLabels[column],
        weekdayStyle.copyWith(color: color),
      );
      painter.paint(
        canvas,
        Offset(
          inset + column * cellWidth + (cellWidth - painter.width) / 2,
          weekdayTop + (weekdayHeight - painter.height) / 2,
        ),
      );
    }

    final gridTop = weekdayTop + weekdayHeight + 2;
    final gridHeight = math.max(0.0, size.height - gridTop - inset);
    final cellHeight = gridHeight / 6;
    final first = DateTime(year, month);
    final leading = weekStartsOnMonday ? first.weekday - 1 : first.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    for (var day = 1; day <= daysInMonth; day++) {
      final index = leading + day - 1;
      final row = index ~/ 7;
      final column = index % 7;
      final center = Offset(
        inset + (column + 0.5) * cellWidth,
        gridTop + (row + 0.5) * cellHeight,
      );
      final isToday =
          today.year == year && today.month == month && today.day == day;
      if (isToday) {
        canvas.drawCircle(
          center,
          math.min(8.5, math.min(cellWidth, cellHeight) / 2),
          Paint()..color = todayBackground,
        );
      }
      final painter = _textPainter(
        '$day',
        dayStyle.copyWith(
          color: isToday ? todayForeground : dayStyle.color,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
        ),
      );
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    }
  }

  TextPainter _textPainter(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
  }

  double _scaledFontHeight(TextStyle style) {
    final painter = _textPainter('월', style);
    return painter.height;
  }

  @override
  bool shouldRepaint(covariant _MiniMonthPainter oldDelegate) {
    return year != oldDelegate.year ||
        month != oldDelegate.month ||
        monthLabel != oldDelegate.monthLabel ||
        !listEquals(weekdayLabels, oldDelegate.weekdayLabels) ||
        weekStartsOnMonday != oldDelegate.weekStartsOnMonday ||
        today != oldDelegate.today ||
        textDirection != oldDelegate.textDirection ||
        textScaler != oldDelegate.textScaler ||
        monthStyle != oldDelegate.monthStyle ||
        weekdayStyle != oldDelegate.weekdayStyle ||
        dayStyle != oldDelegate.dayStyle ||
        sundayColor != oldDelegate.sundayColor ||
        saturdayColor != oldDelegate.saturdayColor ||
        weekdayColor != oldDelegate.weekdayColor ||
        todayBackground != oldDelegate.todayBackground ||
        todayForeground != oldDelegate.todayForeground;
  }
}

List<String> _localizedWeekdayLabels(
  BuildContext context, {
  required bool weekStartsOnMonday,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final firstDay = weekStartsOnMonday ? DateTime.monday : DateTime.sunday;
  return List.generate(
    DateTime.daysPerWeek,
    (index) => DateFormat.E(
      locale,
    ).format(DateTime(2024, 1, 1 + (firstDay - 1 + index) % 7)),
  );
}

class _CalendarWeekView extends StatelessWidget {
  const _CalendarWeekView({
    required this.selectedDate,
    required this.weekStartsOnMonday,
    required this.showLunarDates,
    required this.centerEventTitles,
    required this.events,
    required this.onEventDropped,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final bool centerEventTitles;
  final List<CalendarEvent> events;
  final CalendarEventDropCallback onEventDropped;
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
            centerEventTitles: centerEventTitles,
            compact: true,
            onEventDropped: onEventDropped,
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
                  centerEventTitles: centerEventTitles,
                  compact: false,
                  onEventDropped: onEventDropped,
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
    required this.centerEventTitles,
    required this.compact,
    required this.onEventDropped,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final List<CalendarEvent> events;
  final bool centerEventTitles;
  final bool compact;
  final CalendarEventDropCallback onEventDropped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _weekdayColor(day, colorScheme);
    return CalendarEventDateDropTarget(
      date: day,
      onEventDropped: onEventDropped,
      borderRadius: BorderRadius.circular(10),
      child: Material(
        key: ValueKey('week-day-panel-${day.year}-${day.month}-${day.day}'),
        color: colorScheme.surface,
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
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat.E(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(day),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${day.month}/${day.day}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (events.isEmpty)
                  Text(
                    context.tr('일정 없음'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                  )
                else if (compact)
                  Column(
                    children: [
                      for (final event in events.take(4)) ...[
                        CalendarEventDraggable(
                          event: event,
                          child: _WeekEventFlag(
                            event: event,
                            centerTitle: centerEventTitles,
                          ),
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
                      itemBuilder: (context, index) => CalendarEventDraggable(
                        event: events[index],
                        child: _WeekEventFlag(
                          event: events[index],
                          centerTitle: centerEventTitles,
                        ),
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
      ),
    );
  }

  Color _weekdayColor(DateTime day, ColorScheme colorScheme) {
    if (day.weekday == DateTime.sunday) {
      return const Color(0xffef4444);
    }
    if (day.weekday == DateTime.saturday) {
      return const Color(0xff2563eb);
    }
    return colorScheme.onSurface;
  }
}

class _WeekEventFlag extends StatelessWidget {
  const _WeekEventFlag({required this.event, required this.centerTitle});

  final CalendarEvent event;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(event.colorValue);
    final eventColor = calendarEventAccentColor(
      context,
      categoryColor,
      completed: event.completed,
    );
    final backgroundColor = calendarEventBackgroundColor(
      context,
      categoryColor,
      completed: event.completed,
    );
    final title = context.l10n.eventTitle(event.title, holiday: event.holiday);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              event.allDay
                  ? title
                  : '$title  ${DateFormat('HH:mm').format(event.startAt)}',
              maxLines: 2,
              textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              overflow: TextOverflow.ellipsis,
              style: calendarEventCompletionStyle(
                context,
                TextStyle(
                  color: eventColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                completed: event.completed,
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
  final filtered = events.where((event) {
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
  });
  return sortedCalendarEvents(
    filtered,
    priority: settings.calendarEventSortPriority,
    categoryOrder: settings.categories.map((category) => category.id).toList(),
  );
}

List<CalendarEvent> _eventsForDay(List<CalendarEvent> events, DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return events
      .where(
        (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
      )
      .toList();
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
