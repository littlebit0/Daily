import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/alarms/alarm_service.dart';
import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_draft.dart';
import '../domain/recurrence_rule.dart';

enum _RecurrenceEndMode { never, until, count }

enum _ValidationTarget { title, date, time, recurrence }

class EventEditorDialog extends StatefulWidget {
  const EventEditorDialog({
    super.key,
    required this.initialDate,
    this.initialEndDate,
    this.initialAllDay,
    this.event,
    this.categories = EventCategory.values,
    this.defaultReminderMinutes = 60,
    this.defaultReminderMinutesList,
    this.alarmService = const UnsupportedAlarmService(),
  });

  final DateTime initialDate;
  final DateTime? initialEndDate;
  final bool? initialAllDay;
  final CalendarEvent? event;
  final List<EventCategory> categories;
  final int defaultReminderMinutes;
  final List<int>? defaultReminderMinutesList;
  final AlarmService alarmService;

  @override
  State<EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<EventEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late final TextEditingController _locationController;
  late final TextEditingController _urlController;
  late final TextEditingController _weatherController;
  late final FocusNode _titleFocusNode;
  late final ScrollController _scrollController;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _allDay;
  late EventCategory _category;
  late List<int> _reminders;
  late RecurrenceFrequency _frequency;
  late int _recurrenceInterval;
  late _RecurrenceEndMode _recurrenceEndMode;
  late DateTime? _recurrenceUntil;
  late int? _recurrenceCount;
  late bool _showDday;
  late bool _sensitive;
  late bool _alarmEnabled;
  late TimeOfDay _allDayAlarmTime;
  AlarmAuthorizationState _alarmState = AlarmAuthorizationState.unsupported;
  var _alarmStateLoading = true;
  String? _validationMessage;
  _ValidationTarget? _validationTarget;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _memoController = TextEditingController(text: event?.memo ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    _urlController = TextEditingController(text: event?.url ?? '');
    _weatherController = TextEditingController(text: event?.weather ?? '');
    _titleFocusNode = FocusNode();
    _scrollController = ScrollController();
    final sourceDate = event?.startAt ?? widget.initialDate;
    _startDate = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
    final initialEndDate = widget.initialEndDate ?? widget.initialDate;
    final sourceEnd = event == null
        ? DateTime(
            initialEndDate.year,
            initialEndDate.month,
            initialEndDate.day,
            10,
          )
        : event.allDay
        ? event.endAt.subtract(const Duration(days: 1))
        : event.endAt;
    _endDate = DateTime(sourceEnd.year, sourceEnd.month, sourceEnd.day);
    if (_endDate.isBefore(_startDate)) {
      _endDate = _startDate;
    }
    _startTime = TimeOfDay.fromDateTime(
      event?.startAt ??
          DateTime(
            widget.initialDate.year,
            widget.initialDate.month,
            widget.initialDate.day,
            9,
          ),
    );
    _endTime = TimeOfDay.fromDateTime(sourceEnd);
    _allDay = event?.allDay ?? widget.initialAllDay ?? false;
    final usableCategories = _usableCategories;
    _category = usableCategories.firstWhere(
      (category) => category.id == event?.category.id,
      orElse: () => usableCategories.first,
    );
    _reminders =
        event?.reminderMinutesBeforeList ??
        normalizeReminderMinutes(
          widget.defaultReminderMinutesList ?? [widget.defaultReminderMinutes],
        );
    _frequency = event?.recurrence.frequency ?? RecurrenceFrequency.none;
    _recurrenceInterval = event?.recurrence.interval ?? 1;
    _recurrenceUntil = event?.recurrence.until;
    _recurrenceCount = event?.recurrence.count;
    _recurrenceEndMode = _recurrenceUntil != null
        ? _RecurrenceEndMode.until
        : _recurrenceCount != null
        ? _RecurrenceEndMode.count
        : _RecurrenceEndMode.never;
    _showDday = event?.showDday ?? false;
    _sensitive = event?.sensitive ?? false;
    _alarmEnabled = event?.alarmEnabled ?? false;
    final allDayAlarmMinutes = event?.allDayAlarmMinutes ?? 9 * 60;
    _allDayAlarmTime = TimeOfDay(
      hour: allDayAlarmMinutes ~/ 60,
      minute: allDayAlarmMinutes % 60,
    );
    unawaited(_loadAlarmState());
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    _memoController.dispose();
    _locationController.dispose();
    _urlController.dispose();
    _weatherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startDateLabel = _formatDate(_startDate);
    final endDateLabel = _formatDate(_endDate);
    final startTimeLabel = _startTime.format(context);
    final endTimeLabel = _endTime.format(context);
    final contentMaxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return AlertDialog(
      title: Text(widget.event == null ? '일정 추가' : '일정 수정'),
      content: SizedBox(
        width: 430,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: contentMaxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_validationMessage != null) ...[
                _DialogValidationMessage(message: _validationMessage!),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        decoration: InputDecoration(
                          labelText: '제목',
                          errorText:
                              _validationTarget == _ValidationTarget.title
                              ? '제목을 입력하세요.'
                              : null,
                        ),
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_validationTarget == _ValidationTarget.title &&
                              _titleController.text.trim().isNotEmpty) {
                            _clearValidation();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _LabeledPickerButton(
                              label: '시작일',
                              icon: Icons.calendar_today_outlined,
                              value: startDateLabel,
                              onPressed: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _LabeledPickerButton(
                              label: '종료일',
                              icon: Icons.event_available_outlined,
                              value: endDateLabel,
                              onPressed: _pickEndDate,
                            ),
                          ),
                        ],
                      ),
                      if (!_allDay) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledPickerButton(
                                label: '시작 시간',
                                icon: Icons.schedule,
                                value: startTimeLabel,
                                onPressed: _pickStartTime,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _LabeledPickerButton(
                                label: '종료 시간',
                                icon: Icons.schedule,
                                value: endTimeLabel,
                                onPressed: _pickEndTime,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _allDay,
                        onChanged: (value) {
                          _clearValidation();
                          setState(() => _allDay = value);
                        },
                        title: const Text('종일'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      DropdownButtonFormField<EventCategory>(
                        key: ValueKey(_category.id),
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: '분류'),
                        items: _usableCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(category.colorValue),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category.label),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _clearValidation();
                            setState(() => _category = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(labelText: '알림'),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilterChip(
                              label: const Text('없음'),
                              selected: _reminders.isEmpty,
                              onSelected: (_) {
                                _clearValidation();
                                setState(() => _reminders = const <int>[]);
                              },
                            ),
                            for (final minutes in _reminderOptions())
                              FilterChip(
                                label: Text(_label(minutes)),
                                selected: _reminders.contains(minutes),
                                onSelected: (selected) =>
                                    _toggleReminder(minutes, selected),
                              ),
                            IconButton.outlined(
                              tooltip: '알림 직접 입력',
                              onPressed: _pickCustomReminder,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                      if (_allDay)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '종일 일정은 설정의 종일 알림 시간을 기준으로 예약됩니다.',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value:
                            _frequency == RecurrenceFrequency.none &&
                                _alarmCanBeEnabled
                            ? _alarmEnabled
                            : false,
                        onChanged:
                            _frequency != RecurrenceFrequency.none ||
                                !_alarmCanBeEnabled
                            ? null
                            : _toggleAlarm,
                        title: const Text('일정 알람'),
                        subtitle: Text(_alarmSubtitle),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_alarmEnabled &&
                          _allDay &&
                          _frequency == RecurrenceFrequency.none) ...[
                        const SizedBox(height: 4),
                        _LabeledPickerButton(
                          label: '종일 일정 알람 시각',
                          icon: Icons.alarm,
                          value: _allDayAlarmTime.format(context),
                          onPressed: _pickAllDayAlarmTime,
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<RecurrenceFrequency>(
                        initialValue: _frequency,
                        decoration: const InputDecoration(labelText: '반복'),
                        items: RecurrenceFrequency.values
                            .map(
                              (frequency) => DropdownMenuItem(
                                value: frequency,
                                child: Text(frequency.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _clearValidation();
                            setState(() {
                              _frequency = value;
                              if (value != RecurrenceFrequency.none) {
                                _alarmEnabled = false;
                              }
                            });
                          }
                        },
                      ),
                      if (_frequency != RecurrenceFrequency.none) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledPickerButton(
                                label: '반복 간격',
                                icon: Icons.repeat,
                                value:
                                    '$_recurrenceInterval${_frequencyUnitLabel()}마다',
                                onPressed: _pickRecurrenceInterval,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child:
                                  DropdownButtonFormField<_RecurrenceEndMode>(
                                    initialValue: _recurrenceEndMode,
                                    decoration: const InputDecoration(
                                      labelText: '반복 종료',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: _RecurrenceEndMode.never,
                                        child: Text('종료 없음'),
                                      ),
                                      DropdownMenuItem(
                                        value: _RecurrenceEndMode.until,
                                        child: Text('날짜까지'),
                                      ),
                                      DropdownMenuItem(
                                        value: _RecurrenceEndMode.count,
                                        child: Text('횟수만큼'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      _clearValidation();
                                      setState(() {
                                        _recurrenceEndMode = value;
                                        if (value == _RecurrenceEndMode.until &&
                                            _recurrenceUntil == null) {
                                          _recurrenceUntil =
                                              _endDate.isBefore(_startDate)
                                              ? _startDate
                                              : _endDate;
                                        }
                                        if (value == _RecurrenceEndMode.count &&
                                            _recurrenceCount == null) {
                                          _recurrenceCount = 10;
                                        }
                                      });
                                    },
                                  ),
                            ),
                          ],
                        ),
                        if (_recurrenceEndMode == _RecurrenceEndMode.until) ...[
                          const SizedBox(height: 8),
                          _LabeledPickerButton(
                            label: '반복 종료일',
                            icon: Icons.event_busy_outlined,
                            value: _formatDate(_recurrenceUntil ?? _endDate),
                            onPressed: _pickRecurrenceUntil,
                          ),
                        ],
                        if (_recurrenceEndMode == _RecurrenceEndMode.count) ...[
                          const SizedBox(height: 8),
                          _LabeledPickerButton(
                            label: '반복 횟수',
                            icon: Icons.format_list_numbered,
                            value: '${_recurrenceCount ?? 10}회',
                            onPressed: _pickRecurrenceCount,
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _showDday,
                        onChanged: (value) {
                          _clearValidation();
                          setState(() => _showDday = value);
                        },
                        title: const Text('D-day 표시'),
                        subtitle: const Text('달력과 일정 목록에 D-day를 함께 표시합니다.'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _sensitive,
                        onChanged: (value) {
                          _clearValidation();
                          setState(() => _sensitive = value);
                        },
                        title: const Text('민감 일정'),
                        subtitle: const Text('설정에 따라 제목을 비공개로 숨길 수 있습니다.'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(labelText: '장소'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'URL / 링크',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _weatherController,
                        decoration: const InputDecoration(
                          labelText: '날씨',
                          hintText: '예: 흐림',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _memoController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: '메모'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }

  List<int> _reminderOptions() {
    return normalizeReminderMinutes([0, 10, 30, 60, 1440, ..._reminders]);
  }

  void _toggleReminder(int minutes, bool selected) {
    _clearValidation();
    final values = _reminders.toSet();
    if (selected) {
      values.add(minutes);
    } else {
      values.remove(minutes);
    }
    setState(() => _reminders = normalizeReminderMinutes(values));
  }

  String _label(int? minutes) {
    if (minutes == null) {
      return '없음';
    }
    if (minutes == 0) {
      return '정시';
    }
    if (minutes < 60) {
      return '$minutes분 전';
    }
    if (minutes % 1440 == 0) {
      return '${minutes ~/ 1440}일 전';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60}시간 전';
    }
    return '$minutes분 전';
  }

  Future<void> _pickCustomReminder() async {
    final picked = await _showNumberDialog(
      context: context,
      title: '알림 직접 입력',
      label: '몇 분 전에 알릴까요?',
      initialValue: _reminders.isEmpty ? 0 : _reminders.first,
      minValue: 0,
    );
    if (picked != null) {
      _clearValidation();
      setState(
        () => _reminders = normalizeReminderMinutes([..._reminders, picked]),
      );
    }
  }

  Future<void> _pickRecurrenceInterval() async {
    final picked = await _showNumberDialog(
      context: context,
      title: '반복 간격',
      label: '몇 ${_frequencyUnitLabel()}마다 반복할까요?',
      initialValue: _recurrenceInterval,
      minValue: 1,
    );
    if (picked != null) {
      _clearValidation();
      setState(() => _recurrenceInterval = picked);
    }
  }

  Future<void> _pickRecurrenceUntil() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      initialDate: _recurrenceUntil ?? _endDate,
    );
    if (picked != null) {
      _clearValidation();
      setState(() {
        _recurrenceUntil = DateTime(picked.year, picked.month, picked.day);
        _recurrenceEndMode = _RecurrenceEndMode.until;
      });
    }
  }

  Future<void> _pickRecurrenceCount() async {
    final picked = await _showNumberDialog(
      context: context,
      title: '반복 횟수',
      label: '몇 회 반복할까요?',
      initialValue: _recurrenceCount ?? 10,
      minValue: 1,
    );
    if (picked != null) {
      _clearValidation();
      setState(() {
        _recurrenceCount = picked;
        _recurrenceEndMode = _RecurrenceEndMode.count;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _startDate,
    );
    if (picked != null) {
      _clearValidation();
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
        if (_recurrenceUntil != null &&
            _recurrenceUntil!.isBefore(_startDate)) {
          _recurrenceUntil = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
    );
    if (picked != null) {
      _clearValidation();
      setState(
        () => _endDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await _showTimePicker(_startTime);
    if (picked != null) {
      _clearValidation();
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await _showTimePicker(_endTime);
    if (picked != null) {
      _clearValidation();
      setState(() => _endTime = picked);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showValidation(
        '제목을 입력해야 일정을 저장할 수 있습니다.',
        target: _ValidationTarget.title,
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _showValidation(
        '종료일은 시작일과 같거나 이후여야 합니다.',
        target: _ValidationTarget.date,
      );
      return;
    }
    final startAt = _allDay
        ? _startDate
        : DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            _startTime.hour,
            _startTime.minute,
          );
    final endAt = _allDay
        ? _endDate.add(const Duration(days: 1))
        : DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            _endTime.hour,
            _endTime.minute,
          );
    if (!endAt.isAfter(startAt)) {
      _showValidation(
        '종료 시간은 시작 시간보다 늦어야 합니다.',
        target: _ValidationTarget.time,
      );
      return;
    }
    if (_frequency != RecurrenceFrequency.none && _recurrenceInterval < 1) {
      _showValidation(
        '반복 간격은 1 이상이어야 합니다.',
        target: _ValidationTarget.recurrence,
      );
      return;
    }
    final draft = EventDraft(
      title: title,
      memo: _memoController.text.trim().isEmpty
          ? null
          : _memoController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      url: _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim(),
      weather: _weatherController.text.trim().isEmpty
          ? null
          : _weatherController.text.trim(),
      startAt: startAt,
      endAt: endAt,
      allDay: _allDay,
      category: _category,
      colorValue: _category.colorValue,
      reminderMinutesBeforeList: _reminders,
      recurrence: RecurrenceRule(
        frequency: _frequency,
        interval: _frequency == RecurrenceFrequency.none
            ? 1
            : _recurrenceInterval,
        until:
            _frequency == RecurrenceFrequency.none ||
                _recurrenceEndMode != _RecurrenceEndMode.until
            ? null
            : _recurrenceUntil,
        count:
            _frequency == RecurrenceFrequency.none ||
                _recurrenceEndMode != _RecurrenceEndMode.count
            ? null
            : _recurrenceCount,
      ),
      showDday: _showDday,
      sensitive: _sensitive,
      alarmEnabled: _frequency == RecurrenceFrequency.none && _alarmEnabled,
      allDayAlarmMinutes: _allDayAlarmTime.hour * 60 + _allDayAlarmTime.minute,
    );
    Navigator.of(context).pop(draft);
  }

  void _showValidation(String message, {required _ValidationTarget target}) {
    setState(() {
      _validationMessage = message;
      _validationTarget = target;
    });
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
    if (target == _ValidationTarget.title) {
      _titleFocusNode.requestFocus();
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearValidation() {
    if (_validationMessage == null && _validationTarget == null) {
      return;
    }
    setState(() {
      _validationMessage = null;
      _validationTarget = null;
    });
  }

  bool get _alarmCanBeEnabled =>
      !_alarmStateLoading &&
      (_alarmState == AlarmAuthorizationState.authorized ||
          _alarmState == AlarmAuthorizationState.notDetermined);

  String get _alarmSubtitle {
    if (_frequency != RecurrenceFrequency.none) {
      return '반복 알람은 추후 루틴 기능에서 사용할 수 있습니다.';
    }
    if (_alarmStateLoading) {
      return '알람 지원 상태를 확인하고 있습니다.';
    }
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    return switch (_alarmState) {
      AlarmAuthorizationState.unsupported => '이 운영체제에서는 일정 알람을 사용할 수 없습니다.',
      AlarmAuthorizationState.denied => '시스템 설정에서 Daily의 알람 권한을 허용해야 합니다.',
      AlarmAuthorizationState.notDetermined =>
        isMacOS
            ? '켜면 macOS 알림 권한을 요청하고 시작 시각에 시스템 알림을 전달합니다.'
            : '켜면 시스템 알람 권한을 요청하고 정시 알림을 알람으로 대체합니다.',
      AlarmAuthorizationState.authorized =>
        isMacOS
            ? (_allDay
                  ? '선택한 시각에 소리와 다시 알림이 있는 macOS 시스템 알림을 전달합니다.'
                  : '시작 시각에 소리와 다시 알림이 있는 macOS 시스템 알림을 전달합니다.')
            : (_allDay
                  ? '선택한 시각에 시스템 알람이 울립니다.'
                  : '시작 시각의 정시 알림을 시스템 알람으로 대체합니다.'),
    };
  }

  Future<void> _loadAlarmState() async {
    final state = await widget.alarmService.authorizationState();
    if (!mounted) {
      return;
    }
    setState(() {
      _alarmState = state;
      _alarmStateLoading = false;
      if (state == AlarmAuthorizationState.unsupported ||
          state == AlarmAuthorizationState.denied) {
        _alarmEnabled = false;
      }
    });
  }

  Future<void> _toggleAlarm(bool enabled) async {
    var state = _alarmState;
    if (enabled && state == AlarmAuthorizationState.notDetermined) {
      state = await widget.alarmService.requestAuthorization();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _alarmState = state;
      _alarmEnabled = enabled && state == AlarmAuthorizationState.authorized;
    });
  }

  Future<void> _pickAllDayAlarmTime() async {
    final picked = await _showTimePicker(_allDayAlarmTime);
    if (picked != null) {
      setState(() => _allDayAlarmTime = picked);
    }
  }

  Future<TimeOfDay?> _showTimePicker(TimeOfDay initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (pickerContext, child) => MediaQuery(
        data: MediaQuery.of(
          pickerContext,
        ).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
  }

  List<EventCategory> get _usableCategories {
    final categories = widget.categories.toList();
    return categories.isEmpty ? const [EventCategory.basic] : categories;
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  String _frequencyUnitLabel() {
    return switch (_frequency) {
      RecurrenceFrequency.daily => '일',
      RecurrenceFrequency.weekly => '주',
      RecurrenceFrequency.monthly => '개월',
      RecurrenceFrequency.yearly => '년',
      RecurrenceFrequency.none => '번',
    };
  }
}

class _DialogValidationMessage extends StatelessWidget {
  const _DialogValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledPickerButton extends StatelessWidget {
  const _LabeledPickerButton({
    required this.label,
    required this.icon,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

Future<int?> _showNumberDialog({
  required BuildContext context,
  required String title,
  required String label,
  required int initialValue,
  required int minValue,
}) async {
  final controller = TextEditingController(text: '$initialValue');
  String? errorText;
  final result = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void submit() {
          final value = int.tryParse(controller.text.trim());
          if (value == null || value < minValue) {
            setState(() {
              errorText = minValue == 0
                  ? '0 이상의 숫자를 입력하세요.'
                  : '$minValue 이상의 숫자를 입력하세요.';
            });
            return;
          }
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: label, errorText: errorText),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(onPressed: submit, child: const Text('적용')),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return result;
}
