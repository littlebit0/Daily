import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_draft.dart';
import '../domain/recurrence_rule.dart';

class EventEditorDialog extends StatefulWidget {
  const EventEditorDialog({super.key, required this.initialDate, this.event});

  final DateTime initialDate;
  final CalendarEvent? event;

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
    _category = event?.category ?? EventCategory.other;
    _reminder = event?.reminderMinutesBefore ?? 60;
    _frequency = event?.recurrence.frequency ?? RecurrenceFrequency.none;
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
    final startDateLabel = DateFormat('yyyy년 M월 d일').format(_startDate);
    final endDateLabel = DateFormat('yyyy년 M월 d일').format(_endDate);
    final startTimeLabel = _startTime.format(context);
    final endTimeLabel = _endTime.format(context);

    return AlertDialog(
      title: Text(widget.event == null ? '일정 추가' : '일정 수정'),
      content: SizedBox(
        width: 420,
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
                initialValue: _category,
                decoration: const InputDecoration(labelText: '분류'),
                items: EventCategory.values
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
              DropdownButtonFormField<int?>(
                initialValue: _allDay ? null : _reminder,
                decoration: const InputDecoration(labelText: '알림'),
                items: const [
                  DropdownMenuItem<int?>(value: null, child: Text('없음')),
                  DropdownMenuItem(value: 10, child: Text('10분 전')),
                  DropdownMenuItem(value: 30, child: Text('30분 전')),
                  DropdownMenuItem(value: 60, child: Text('1시간 전')),
                  DropdownMenuItem(value: 1440, child: Text('하루 전')),
                ],
                onChanged: _allDay
                    ? null
                    : (value) => setState(() => _reminder = value),
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
      reminderMinutesBefore: _allDay ? null : _reminder,
      recurrence: RecurrenceRule(frequency: _frequency),
    );
    Navigator.of(context).pop(draft);
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
