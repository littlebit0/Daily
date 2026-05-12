import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../events/domain/event_draft.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _controller = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffd8dce3))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '일정을 입력하세요',
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '등록',
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final selectedDate = ref.read(selectedDateProvider);
      final settings = ref.read(appSettingsProvider);
      final result = await ref
          .read(scheduleParserProvider)
          .parse(
            input,
            baseDate: DateTime.now(),
            selectedDate: selectedDate,
            defaultReminderMinutes: settings.defaultReminderMinutes,
          );

      if (!mounted) {
        return;
      }
      if (result.draft == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.question ?? '일정을 해석하지 못했습니다.')),
        );
        return;
      }

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (_) => _DraftConfirmationSheet(draft: result.draft!),
      );
      if (confirmed == true) {
        await ref.read(eventCommandServiceProvider).create(result.draft!);
        _controller.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _DraftConfirmationSheet extends StatelessWidget {
  const _DraftConfirmationSheet({required this.draft});

  final EventDraft draft;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy년 M월 d일').format(draft.startAt);
    final time = draft.allDay
        ? '종일'
        : '${DateFormat('HH:mm').format(draft.startAt)} - ${DateFormat('HH:mm').format(draft.endAt)}';
    final reminder = draft.reminderMinutesBefore == null
        ? '없음'
        : '${draft.reminderMinutesBefore}분 전';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 일정으로 등록할까요?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Color(
                  draft.colorValue ?? draft.category.colorValue,
                ).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Color(
                    draft.colorValue ?? draft.category.colorValue,
                  ).withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$date  $time'),
                  Text('분류: ${draft.category.label}'),
                  Text('알림: $reminder'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('등록'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
