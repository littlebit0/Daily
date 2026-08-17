import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../events/domain/calendar_event.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('검색'))),
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
                hintText: context.tr('제목, 메모, 장소 검색'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: context.tr('검색'),
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
                        context.tr('검색 결과가 없습니다.'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemBuilder: (context, index) => _SearchResultTile(
                      event: events[index],
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
  const _SearchResultTile({required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMMd(locale).format(event.startAt);
    final time = event.allDay
        ? context.tr('종일')
        : DateFormat.Hm(locale).format(event.startAt);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      leading: CircleAvatar(
        backgroundColor: Color(event.colorValue).withValues(alpha: 0.12),
        child: Icon(Icons.flag, color: Color(event.colorValue)),
      ),
      title: Text(context.l10n.eventTitle(event.title, holiday: event.holiday)),
      subtitle: Text('$date  $time'),
    );
  }
}
