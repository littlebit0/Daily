import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show TextDirection;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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
import '../../settings/presentation/settings_page.dart';
import '../widgets/calendar_month_grid.dart';

enum _BottomCenterAction { quickAccess, calendar, ai }

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
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
    if (_quickAccessSelected) {
      setState(() => _quickAccessSelected = false);
    }
    if (!fromBottomBar) {
      _clearBottomAction();
    }
  }

  void _toggleAiPanel() {
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
      child: ChatInputBar(
        key: const ValueKey('inline-ai-input'),
        includeBottomSafeArea: false,
        onClose: _closeAiPanel,
      ),
      builder: (context, aiOpen, child) => AnimatedSize(
        key: const ValueKey('inline-ai-layout-panel'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: aiOpen
            ? child
            : const SizedBox(width: double.infinity, height: 0),
      ),
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
        child: ChatInputBar(
          key: const ValueKey('overlay-ai-input'),
          includeBottomSafeArea: false,
          onClose: _closeAiPanel,
        ),
        builder: (context, aiOpen, child) {
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
                  child: child,
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = _monthRangeFor(currentMonth, settings.weekStartsOnMonday);
    final eventsAsync = ref.watch(eventsInRangeProvider(range));

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
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
    final title = event.title;
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
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
    final date = DateFormat('yyyy년 M월 d일').format(event.startAt);
    final time = event.allDay
        ? '종일'
        : DateFormat('HH:mm').format(event.startAt);
    return ListTile(
      dense: true,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      leading: CircleAvatar(
        backgroundColor: Color(event.colorValue).withValues(alpha: 0.12),
        child: Icon(Icons.flag, color: Color(event.colorValue)),
      ),
      title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$date  $time'),
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
    if (!_isDesktopHorizontalPageScroll(context, event) ||
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
        duration: const Duration(milliseconds: 260),
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
    if (!_isDesktopHorizontalPageScroll(context, event) ||
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
        duration: const Duration(milliseconds: 260),
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

class _MonthPageView extends ConsumerStatefulWidget {
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
  final Map<int, RenderBox> _continuousGridBoxes = {};
  final ValueNotifier<(DateTime?, DateTime?)> _continuousRangeNotifier =
      ValueNotifier((null, null));
  DateTime? _continuousRangeStart;
  DateTime? _continuousRangeEnd;
  bool _continuousMouseRangeActive = false;

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

  void _handleContinuousPointerDown(PointerDownEvent event) {
    if ((event.kind != PointerDeviceKind.mouse &&
            event.kind != PointerDeviceKind.trackpad) ||
        (event.buttons != 0 && (event.buttons & kPrimaryMouseButton) == 0)) {
      return;
    }
    _continuousMouseRangeActive = false;
    _startContinuousRange(event.position, showImmediately: false);
  }

  void _handleContinuousPointerMove(PointerMoveEvent event) {
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
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
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
        '${month.month}월',
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
            '${month.month}월',
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

bool _isDesktopHorizontalPageScroll(
  BuildContext context,
  PointerSignalEvent event,
) {
  if (!_usesMacDesktopExperience(Theme.of(context).platform) ||
      event is! PointerScrollEvent) {
    return false;
  }
  final horizontal = event.scrollDelta.dx.abs();
  final vertical = event.scrollDelta.dy.abs();
  return horizontal >= 18 && horizontal > vertical;
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
          showAdjacentMonthDates:
              !continuous && settings.showAdjacentMonthDates,
          continuous: continuous,
          showWeekdayHeader: showWeekdayHeader,
          onRangeHitTestBoxChanged: onRangeHitTestBoxChanged,
          externalRangeStart: externalRangeStart,
          externalRangeEnd: externalRangeEnd,
          enableRangeGestures: enableRangeGestures,
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
        showAdjacentMonthDates: !continuous && settings.showAdjacentMonthDates,
        continuous: continuous,
        showWeekdayHeader: showWeekdayHeader,
        onRangeHitTestBoxChanged: onRangeHitTestBoxChanged,
        externalRangeStart: externalRangeStart,
        externalRangeEnd: externalRangeEnd,
        enableRangeGestures: enableRangeGestures,
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
}

Future<void> _openRangeEventEditor(
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
      alarmService: ref.read(alarmServiceProvider),
    ),
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
    // Android's compact toolbar reserves fixed-width navigation and utility
    // actions. Keep the period control to a single year there so its label and
    // tap target cannot be squeezed out in horizontal month navigation.
    final showYearOnly =
        monthNavigationMode == MonthNavigationMode.vertical ||
        (compact && !ios);
    final label = showYearOnly
        ? '${month.year}년'
        : '${month.year}년 ${month.month}월';
    final colorScheme = Theme.of(context).colorScheme;
    final monthButton = TextButton.icon(
      key: const ValueKey('calendar-period-button'),
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
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: ios ? const Size(0, 44) : null,
        maximumSize: ios ? const Size(120, 44) : null,
        tapTargetSize: ios
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
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
              ? colorScheme.primaryContainer
              : Colors.transparent,
          foregroundColor: quickAccessSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
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
            const expandedViewWidth = 96.0;
            const collapsedViewWidth = 76.0;
            const expandedViewHeight = 48.0;
            const collapsedViewHeight = 40.0;
            const minimumViewWidth = 60.0;
            const maximumCenterWidth = 152.0;
            final centerLeft = (constraints.maxWidth - maximumCenterWidth) / 2;
            final desiredViewWidth = calendarViewControlSelected
                ? expandedViewWidth
                : collapsedViewWidth;
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
    final colorScheme = Theme.of(context).colorScheme;
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
          color: colorScheme.surfaceContainerHighest,
          shape: StadiumBorder(
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        clipBehavior: Clip.none,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(3),
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
                              color: colorScheme.primaryContainer,
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
                              message: '${mode.label} 보기',
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
                                    switch (mode) {
                                      CalendarViewMode.week => '주',
                                      CalendarViewMode.month => '월',
                                      CalendarViewMode.day => '일',
                                    },
                                    style: TextStyle(
                                      color: mode == _visibleMode
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
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
            color: colorScheme.surfaceContainerHighest,
            shape: StadiumBorder(
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          clipBehavior: Clip.none,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(3),
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
                                color: colorScheme.primaryContainer,
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
                            tooltip: '빠른 보기',
                            icon: Icons.dashboard_outlined,
                            selected: action == _BottomCenterAction.quickAccess,
                            onTapDown: () =>
                                _press(_BottomCenterAction.quickAccess),
                            onPressed: () =>
                                _selectPressed(_BottomCenterAction.quickAccess),
                            onTapCancel: _cancelPress,
                          ),
                          _BottomModeButton(
                            tooltip: '달력',
                            icon: Icons.calendar_month_outlined,
                            selected: action == _BottomCenterAction.calendar,
                            onTapDown: () =>
                                _press(_BottomCenterAction.calendar),
                            onPressed: () =>
                                _selectPressed(_BottomCenterAction.calendar),
                            onTapCancel: _cancelPress,
                          ),
                          _BottomModeButton(
                            tooltip: 'AI',
                            icon: Icons.auto_awesome_outlined,
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
    final colorScheme = Theme.of(context).colorScheme;
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
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
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
          tooltip: '닫기',
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
    return Semantics(
      label: '$year년 $month월',
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
    final monthPainter = _textPainter('$month월', monthStyle);
    monthPainter.paint(canvas, Offset(inset, inset));

    final weekdayTop = inset + monthPainter.height + 3;
    final weekdayHeight = _scaledFontHeight(weekdayStyle);
    final cellWidth = contentWidth / 7;
    final weekdays = weekStartsOnMonday
        ? const ['월', '화', '수', '목', '금', '토', '일']
        : const ['일', '월', '화', '수', '목', '금', '토'];
    for (var column = 0; column < 7; column++) {
      final color = column == 0
          ? sundayColor
          : column == 6
          ? saturdayColor
          : weekdayColor;
      final painter = _textPainter(
        weekdays[column],
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

class _CalendarWeekView extends StatelessWidget {
  const _CalendarWeekView({
    required this.selectedDate,
    required this.weekStartsOnMonday,
    required this.showLunarDates,
    required this.events,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
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
    required this.compact,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final List<CalendarEvent> events;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _weekdayColor(day, colorScheme);
    return Material(
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
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colorScheme.outline),
                )
              else if (compact)
                Column(
                  children: [
                    for (final event in events.take(4)) ...[
                      _WeekEventFlag(event: event),
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
                    itemBuilder: (context, index) =>
                        _WeekEventFlag(event: events[index]),
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

  Color _weekdayColor(DateTime day, ColorScheme colorScheme) {
    if (day.weekday == DateTime.sunday) {
      return const Color(0xffef4444);
    }
    if (day.weekday == DateTime.saturday) {
      return const Color(0xff2563eb);
    }
    return colorScheme.onSurface;
  }

  String _weekdayLabel(DateTime day) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[day.weekday - 1];
  }
}

class _WeekEventFlag extends StatelessWidget {
  const _WeekEventFlag({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final eventColor = Color(event.colorValue);
    final title = event.title;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.12),
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
