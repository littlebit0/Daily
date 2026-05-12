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
  late DateTime _date;
  late TimeOfDay _time;
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
    _date = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
    _time = TimeOfDay.fromDateTime(
      event?.startAt ??
          DateTime(
            widget.initialDate.year,
            widget.initialDate.month,
            widget.initialDate.day,
            9,
          ),
    );
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
    final dateLabel = DateFormat('yyyy년 M월 d일').format(_date);
    final timeLabel = _time.format(context);

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
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(dateLabel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _allDay ? null : _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(_allDay ? '종일' : timeLabel),
                    ),
                  ),
                ],
              ),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    final startAt = _allDay
        ? _date
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            _time.hour,
            _time.minute,
          );
    final draft = EventDraft(
      title: title,
      memo: _memoController.text.trim().isEmpty
          ? null
          : _memoController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      startAt: startAt,
      endAt: _allDay
          ? startAt.add(const Duration(days: 1))
          : startAt.add(const Duration(hours: 1)),
      allDay: _allDay,
      category: _category,
      colorValue: _category.colorValue,
      reminderMinutesBefore: _allDay ? null : _reminder,
      recurrence: RecurrenceRule(frequency: _frequency),
    );
    Navigator.of(context).pop(draft);
  }
}
