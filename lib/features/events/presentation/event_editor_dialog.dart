import 'package:flutter/material.dart';

import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_draft.dart';
import '../domain/recurrence_rule.dart';

class EventEditorDialog extends StatefulWidget {
  const EventEditorDialog({
    super.key,
    required this.initialDate,
    this.event,
    this.categories = EventCategory.values,
    this.defaultReminderMinutes = 60,
  });

  final DateTime initialDate;
  final CalendarEvent? event;
  final List<EventCategory> categories;
  final int defaultReminderMinutes;

  @override
  State<EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<EventEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late final TextEditingController _locationController;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _allDay;
  late EventCategory _category;
  late int? _reminder;
  late RecurrenceFrequency _frequency;
  late bool _showDday;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _memoController = TextEditingController(text: event?.memo ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    final sourceDate = event?.startAt ?? widget.initialDate;
    _startDate = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
    final sourceEnd = event == null
        ? DateTime(
            widget.initialDate.year,
            widget.initialDate.month,
            widget.initialDate.day,
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
    _allDay = event?.allDay ?? false;
    final usableCategories = _usableCategories;
    _category = usableCategories.firstWhere(
      (category) => category.id == event?.category.id,
      orElse: () => usableCategories.first,
    );
    _reminder = event?.reminderMinutesBefore ?? widget.defaultReminderMinutes;
    _frequency = event?.recurrence.frequency ?? RecurrenceFrequency.none;
    _showDday = event?.showDday ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startDateLabel = _formatDate(_startDate);
    final endDateLabel = _formatDate(_endDate);
    final startTimeLabel = _startTime.format(context);
    final endTimeLabel = _endTime.format(context);

    return AlertDialog(
      title: Text(widget.event == null ? '일정 추가' : '일정 수정'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목'),
                autofocus: true,
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
                onChanged: (value) => setState(() => _allDay = value),
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
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey(_reminder),
                      initialValue: _reminder,
                      decoration: const InputDecoration(labelText: '알림'),
                      items: _reminderItems(),
                      onChanged: (value) => setState(() => _reminder = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: '알림 직접 입력',
                    onPressed: _pickCustomReminder,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
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
                    setState(() => _frequency = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _showDday,
                onChanged: (value) => setState(() => _showDday = value),
                title: const Text('D-day 표시'),
                subtitle: const Text('달력과 일정 목록에 D-day를 함께 표시합니다.'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: '장소'),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }

  List<DropdownMenuItem<int?>> _reminderItems() {
    final values = <int?>[null, 0, 10, 30, 60, 1440];
    if (_reminder != null && !values.contains(_reminder)) {
      values.add(_reminder);
    }
    return values
        .map(
          (value) => DropdownMenuItem(value: value, child: Text(_label(value))),
        )
        .toList();
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
      initialValue: _reminder ?? 0,
    );
    if (picked != null && picked >= 0) {
      setState(() => _reminder = picked);
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
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
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
      setState(
        () => _endDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종료일은 시작일 이후여야 합니다.')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종료 시간은 시작 이후여야 합니다.')));
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
      startAt: startAt,
      endAt: endAt,
      allDay: _allDay,
      category: _category,
      colorValue: _category.colorValue,
      reminderMinutesBefore: _reminder,
      recurrence: RecurrenceRule(frequency: _frequency),
      showDday: _showDday,
    );
    Navigator.of(context).pop(draft);
  }

  List<EventCategory> get _usableCategories {
    final categories = widget.categories
        .where((category) => category.id != EventCategory.holiday.id)
        .toList();
    return categories.isEmpty ? const [EventCategory.basic] : categories;
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
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
}) async {
  final controller = TextEditingController(text: '$initialValue');
  final result = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(controller.text.trim());
            Navigator.of(context).pop(value);
          },
          child: const Text('적용'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
