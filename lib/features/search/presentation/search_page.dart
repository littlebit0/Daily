import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/presentation/sensitive_event_access.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Future<List<CalendarEvent>>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hideSensitive = !ref.watch(sensitiveEventsUnlockedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('검색')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '제목, 메모, 장소 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: '검색',
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<CalendarEvent>>(
                future: _results,
                builder: (context, snapshot) {
                  final events = snapshot.data ?? const <CalendarEvent>[];
                  if (_results == null) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (events.isEmpty) {
                    return Center(
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemBuilder: (context, index) => _SearchResultTile(
                      event: events[index],
                      hideSensitive: hideSensitive,
                      onTap: () {
                        final event = events[index];
                        ref.read(visibleMonthProvider.notifier).state =
                            DateTime(event.startAt.year, event.startAt.month);
                        ref
                            .read(selectedDateProvider.notifier)
                            .state = DateTime(
                          event.startAt.year,
                          event.startAt.month,
                          event.startAt.day,
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemCount: events.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _search() {
    setState(() {
      _results = ref
          .read(eventRepositoryProvider)
          .search(_controller.text.trim());
    });
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.event,
    required this.hideSensitive,
    required this.onTap,
  });

  final CalendarEvent event;
  final bool hideSensitive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hidden = hideSensitive && event.sensitive;
    final date = DateFormat('yyyy년 M월 d일').format(event.startAt);
    final time = event.allDay
        ? '종일'
        : DateFormat('HH:mm').format(event.startAt);
    return ListTile(
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
      title: Text(hidden ? '비공개 일정' : event.title),
      subtitle: Text(hidden ? date : '$date  $time'),
    );
  }
}
