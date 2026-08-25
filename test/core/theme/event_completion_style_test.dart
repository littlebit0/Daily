import 'package:daily/core/theme/event_completion_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'completed event remains legible with a strong double strike in ${brightness.name} mode',
      (tester) async {
        late TextStyle completedStyle;
        late Color completedAccent;
        late Color completedBackground;
        const categoryColor = Color(0xffef4444);
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light ? ThemeData.light() : null,
            darkTheme: brightness == Brightness.dark ? ThemeData.dark() : null,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Builder(
              builder: (context) {
                completedStyle = calendarEventCompletionStyle(
                  context,
                  Theme.of(context).textTheme.bodyMedium,
                  completed: true,
                );
                completedAccent = calendarEventAccentColor(
                  context,
                  categoryColor,
                  completed: true,
                );
                completedBackground = calendarEventBackgroundColor(
                  context,
                  categoryColor,
                  completed: true,
                );
                return Text('완료 일정', style: completedStyle);
              },
            ),
          ),
        );

        expect(completedStyle.decoration, TextDecoration.lineThrough);
        expect(completedStyle.decorationStyle, TextDecorationStyle.double);
        expect(completedStyle.decorationThickness, greaterThanOrEqualTo(2));
        expect(completedStyle.color, isNotNull);
        expect(completedStyle.decorationColor, isNotNull);
        expect(completedStyle.color!.a, greaterThanOrEqualTo(0.7));
        expect(completedStyle.decorationColor!.a, greaterThanOrEqualTo(0.9));
        expect(completedAccent, isNot(categoryColor));
        expect(completedBackground, isNot(categoryColor));
        expect(
          completedBackground,
          calendarCompletedEventBackgroundColor(
            tester.element(find.text('완료 일정')),
          ),
        );
      },
    );
  }
}
