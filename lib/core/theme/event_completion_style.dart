import 'package:flutter/material.dart';

Color calendarCompletedEventForegroundColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.colorScheme.onSurface.withValues(
    alpha: theme.brightness == Brightness.dark ? 0.94 : 0.86,
  );
}

Color calendarCompletedEventAccentColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? const Color(0xffc5cbd3)
      : const Color(0xff4b5563);
}

Color calendarCompletedEventBackgroundColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? const Color(0xff353b44)
      : const Color(0xffe1e5ea);
}

Color calendarEventAccentColor(
  BuildContext context,
  Color categoryColor, {
  required bool completed,
}) {
  return completed ? calendarCompletedEventAccentColor(context) : categoryColor;
}

Color calendarEventBackgroundColor(
  BuildContext context,
  Color categoryColor, {
  required bool completed,
  double categoryAlpha = 0.12,
}) {
  return completed
      ? calendarCompletedEventBackgroundColor(context)
      : categoryColor.withValues(alpha: categoryAlpha);
}

TextStyle calendarEventCompletionStyle(
  BuildContext context,
  TextStyle? base, {
  required bool completed,
}) {
  final style = base ?? const TextStyle();
  if (!completed) {
    return style;
  }
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final completedColor = calendarCompletedEventForegroundColor(context);
  final strikeColor = theme.colorScheme.onSurface.withValues(
    alpha: dark ? 0.98 : 0.90,
  );
  return style.copyWith(
    color: completedColor,
    decoration: TextDecoration.lineThrough,
    decorationStyle: TextDecorationStyle.double,
    decorationColor: strikeColor,
    decorationThickness: dark ? 2.0 : 2.2,
  );
}
