import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/calendar_import/calendar_import_models.dart';
import '../../../core/calendar_import/google_calendar_source.dart';
import '../../../core/di/app_providers.dart';

class CalendarImportPage extends ConsumerStatefulWidget {
  const CalendarImportPage({super.key});

  @override
  ConsumerState<CalendarImportPage> createState() => _CalendarImportPageState();
}

class _CalendarImportPageState extends ConsumerState<CalendarImportPage> {
  final _calendars = <ImportableCalendar>[];
  final _selected = <String>{};
  var _nativeBusy = false;
  var _googleBusy = false;
  var _importBusy = false;
  String? _message;

  CalendarImportProvider? get _nativeProvider =>
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS => CalendarImportProvider.apple,
        TargetPlatform.android => CalendarImportProvider.samsung,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final nativeProvider = _nativeProvider;
    final selectedCalendars = _calendars
        .where((calendar) => _selected.contains(calendar.selectionKey))
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('캘린더 데이터 옮기기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          if (nativeProvider != null)
            _ImportSourceSection(
              title: nativeProvider.label,
              icon: nativeProvider == CalendarImportProvider.apple
                  ? Icons.apple
                  : Icons.calendar_month_outlined,
              busy: _nativeBusy,
              onLoad: _loadNativeCalendars,
              calendars: _calendars
                  .where((calendar) => calendar.provider == nativeProvider)
                  .toList(growable: false),
              selected: _selected,
              onChanged: _setSelected,
            ),
          const SizedBox(height: 14),
          _ImportSourceSection(
            title: CalendarImportProvider.google.label,
            icon: Icons.account_circle_outlined,
            busy: _googleBusy,
            onLoad: _loadGoogleCalendars,
            calendars: _calendars
                .where(
                  (calendar) =>
                      calendar.provider == CalendarImportProvider.google,
                )
                .toList(growable: false),
            selected: _selected,
            onChanged: _setSelected,
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: selectedCalendars.isEmpty || _importBusy
                ? null
                : () => _import(selectedCalendars),
            icon: _importBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.move_to_inbox_outlined),
            label: Text(
              _importBusy
                  ? '일정을 옮기는 중'
                  : '${selectedCalendars.length}개 캘린더 가져오기',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadNativeCalendars() async {
    setState(() {
      _nativeBusy = true;
      _message = null;
    });
    try {
      final values = await ref
          .read(calendarImportServiceProvider)
          .listNativeCalendars();
      _replaceProvider(_nativeProvider, values);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _nativeBusy = false);
      }
    }
  }

  Future<void> _loadGoogleCalendars() async {
    setState(() {
      _googleBusy = true;
      _message = null;
    });
    try {
      final values = await ref
          .read(calendarImportServiceProvider)
          .listGoogleCalendars();
      _replaceProvider(CalendarImportProvider.google, values);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _googleBusy = false);
      }
    }
  }

  void _replaceProvider(
    CalendarImportProvider? provider,
    List<ImportableCalendar> values,
  ) {
    if (!mounted || provider == null) {
      return;
    }
    setState(() {
      _calendars.removeWhere((calendar) => calendar.provider == provider);
      _calendars.addAll(values);
      _selected.removeWhere(
        (key) =>
            key.startsWith('${provider.name}:') &&
            !values.any((calendar) => calendar.selectionKey == key),
      );
      _message = values.isEmpty ? '가져올 수 있는 ${provider.label}가 없습니다.' : null;
    });
  }

  void _setSelected(ImportableCalendar calendar, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(calendar.selectionKey);
      } else {
        _selected.remove(calendar.selectionKey);
      }
    });
  }

  Future<void> _import(List<ImportableCalendar> calendars) async {
    setState(() {
      _importBusy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(calendarImportServiceProvider)
          .importCalendars(calendars);
      ref.read(appSettingsProvider.notifier).state = ref
          .read(settingsRepositoryProvider)
          .load();
      unawaited(
        ref.read(googleDriveSyncServiceProvider).backupNow().catchError((_) {}),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message =
            '가져오기 완료: ${result.imported}개 추가, '
            '${result.skipped}개 중복 제외, ${result.failed}개 실패';
      });
    } on CalendarImportException catch (error) {
      _showError(error);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _importBusy = false);
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    final message = switch (error) {
      CalendarImportException(:final message) => message,
      PlatformException(:final message) =>
        message ?? '캘린더 권한 또는 연결 상태를 확인해 주세요.',
      _ =>
        error
            .toString()
            .replaceFirst('PlatformException(', '')
            .split(',')
            .first,
    };
    setState(() => _message = message);
  }
}

class _ImportSourceSection extends StatelessWidget {
  const _ImportSourceSection({
    required this.title,
    required this.icon,
    required this.busy,
    required this.onLoad,
    required this.calendars,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final bool busy;
  final VoidCallback onLoad;
  final List<ImportableCalendar> calendars;
  final Set<String> selected;
  final void Function(ImportableCalendar calendar, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: '$title 불러오기',
              onPressed: busy ? null : onLoad,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        if (calendars.isEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('$title 불러오기'),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : onLoad,
          )
        else
          for (final calendar in calendars)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected.contains(calendar.selectionKey),
              title: Text(calendar.title),
              subtitle: calendar.accountName?.trim().isNotEmpty ?? false
                  ? Text(calendar.accountName!)
                  : null,
              secondary: calendar.colorValue == null
                  ? null
                  : Container(
                      width: 12,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(calendar.colorValue!),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
              onChanged: busy
                  ? null
                  : (value) => onChanged(calendar, value ?? false),
            ),
      ],
    );
  }
}
