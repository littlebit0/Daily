# AI Strategy

Daily should treat AI as an optional assistant, not as the source of truth.
The calendar data model, sync, notifications, and rule-based parser must keep
working without any AI provider.

## Current Position

- The app already uses a hybrid parser.
- Simple schedule text is parsed locally by deterministic rules.
- AI is only used for complex text when the user enables it.
- Sensitive text can be blocked from AI calls through the existing setting.
- The current implementation uses a user-provided Gemini API key.

## Recommended Direction

1. Keep local rules as the default path.
2. Use AI only when local parsing is uncertain or the request is naturally
   language-heavy.
3. Always show a confirmation screen before saving AI-generated events.
4. Do not require AI for sync, backup, notification, search, or editing.
5. For public release without running our own server, keep AI as a bring-your-
   own-key feature. Embedding a shared paid API key in the app is not safe.

## Feature Roadmap

- Natural-language schedule creation.
- Multi-event extraction from one message.
- Follow-up questions when date/time/title is ambiguous.
- Smart category and reminder suggestions.
- Calendar cleanup suggestions, such as detecting duplicate or overlapping
  events.
- Local-first privacy mode that never sends text to AI.

## Public Release Constraint

If the app is distributed to other people and we still avoid our own server,
there are only three practical AI options:

1. User-provided API key: lowest maintenance, safest for cost control, weakest
   onboarding.
2. Platform/on-device AI where available: best privacy, inconsistent across
   Windows/macOS/iOS/Android.
3. No AI by default, with AI hidden behind an advanced setting.

The practical first public version should use option 1 plus option 3: ship the
calendar and sync as complete features, and expose AI as an optional advanced
feature for users who provide their own key.
