# Daily iPhone 17 UI Ratio Measurements

Measured: 2026-07-17

This document records screenshot measurements only. No UI implementation has
been changed as part of this measurement work.

## Measurement basis

- Reference A: physical iPhone 17 shown through iPhone Mirroring.
- Reference B: iPhone 17 Simulator.
- The external Mirroring window and Simulator device frame are excluded.
- Both application viewports measure `400 x 874` captured pixels, so the
  values below are directly comparable without a scale conversion.
- Coordinates use the application viewport's top-left corner as `(0, 0)`.

## Monthly calendar

### Fixed geometry

| Element | Physical iPhone | Simulator | Result |
| --- | ---: | ---: | --- |
| Month card horizontal bounds | `x=4..396` | `x=4..396` | same |
| Inner week-grid bounds | `x=7..393` | `x=7..393` | same |
| Week-grid width | `386` | `386` | same |
| Single day column width | `55.143` | `55.143` | same |
| Search icon bounds | `x=262..278`, `y=84..100` | same | same |
| Filter icon bounds | `x=310..327`, `y=87..98` | same | same |
| Settings icon bounds | `x=357..376`, `y=83..102` | same | same |
| Selected-date filled circle | `20 x 20`, `x=292`, `y=375` | `20 x 20`, `x=292`, `y=377` | simulator `+2 y` |
| Active month-tab fill | `x=163..236`, `y=808..871` | same | same |
| Bottom tab centers | `54.4, 127.2, 200, 272.8, 345.6` | same | same |

### Text measurements

| Element | Physical iPhone bounding box | Simulator bounding box | Physical / Simulator |
| --- | --- | --- | ---: |
| `2026년 7월` | `70 x 14` at `(107, 86)` | `86 x 16` at `(99, 84)` | `0.81x` width |
| Weekday `일` | `7 x 8` at `(30, 138)` | `9 x 10` at `(29, 138)` | about `0.80x` |
| Weekday `월` | `6 x 9` at `(86, 137)` | `8 x 11` at `(85, 137)` | about `0.80x` |
| Weekday `화` | `7 x 8` at `(141, 137)` | `9 x 11` at `(140, 137)` | about `0.80x` |
| Weekday `목` | `7 x 8` at `(252, 137)` | `9 x 11` at `(251, 137)` | about `0.80x` |
| Weekday `금` | `6 x 9` at `(308, 137)` | `8 x 10` at `(307, 138)` | about `0.80x` |
| Weekday `토` | `3 x 6` at `(364, 138)` | `6 x 8` at `(363, 138)` | about `0.80x` |
| Date `22` | `9 x 7` at `(187, 486)` | `11 x 9` at `(186, 487)` | about `0.80x` |
| Bottom tab `월` | `8 x 9` at `(196, 831)` | `10 x 11` at `(195, 829)` | about `0.80x` |
| Event label `전역` | `21 x 8` at `(122, 183)` | `27 x 10` at `(121, 186)` | about `0.78x` |
| Event label `16시 kfc` | `30 x 8` at `(11, 288)` | `36 x 9` at `(11, 291)` | about `0.83x` |
| Lunar label `5.17` | `14 x 6` at `(205, 170)` | `14 x 6` at `(205, 173)` | same size |

The weekday `수` screenshot was covered by the Simulator mouse cursor during
capture. Its implementation and text style are the same as the other weekday
labels, so no separate unreliable measurement is recorded.

### Vertical text anchors

| Calendar row anchor | Physical iPhone y | Simulator y | Delta |
| --- | ---: | ---: | ---: |
| Row 1 date `1` | `169` | `171` | `+2` |
| Row 2 date `8` | `275` | `277` | `+2` |
| Row 3 date `15` | `381` | `382` | `+1` |
| Row 4 date `22` | `486` | `487` | `+1` |
| Row 5 date `29` | `592` | `593` | `+1` |

### Text inventory and implementation rules

The visible monthly surface contains the following text groups:

- Header month label: one string, currently `2026년 7월`.
- Weekday labels: seven strings, `일` through `토`.
- Date labels: 42 cells in a six-week grid.
- Lunar labels: 42 cells when lunar dates are enabled.
- Event labels: data-dependent visible event spans, each with one-line
  ellipsis behavior.
- Bottom navigation labels: `주`, `월`, `일`.

Code rules currently used by the monthly view:

- Header label: nominal `18` logical pixels and follows the system text
  scaler.
- Weekday labels: theme `labelMedium` and follow the system text scaler.
- Date labels: nominal `12` logical pixels and follow the system text scaler.
- Lunar labels: nominal `8.5` logical pixels with `TextScaler.noScaling`.
- Event labels: nominal `10.5` logical pixels in compact mode and follow the
  system text scaler; dense event rows use `9.2`.
- Bottom tab labels: nominal `13` logical pixels and follow the system text
  scaler.

## Finding

The physical iPhone renders scalable text at approximately `0.80x` of the
Simulator's text size. This is supported by the header, weekday, date, event,
and bottom-tab measurements. The lunar label, which explicitly disables text
scaling, renders at the same size on both devices.

Therefore the observed monthly-calendar mismatch is caused by different iOS
system text-scaler values, not by a different iPhone 17 viewport, card width,
grid width, icon placement, or bottom-navigation layout. The different text
heights shift the first calendar rows down by one to two pixels on the
Simulator, then the flexible six-row layout absorbs the difference lower down.

## Pending measurements

### Expanded search bar

The expanded search bar was opened and measured in the iPhone 17 Simulator.
The physical iPhone search button did not accept the mirrored pointer action,
so physical search text values below are calculated from the confirmed monthly
text-scaler ratio rather than represented as a direct screenshot measurement.

| Element | Simulator measurement | Physical-iPhone estimate at `0.80x` text scale |
| --- | --- | --- |
| Search panel horizontal bounds | `x=0..400` | same |
| Search panel top / bottom separator | `y=125 / y=191` | same fixed geometry |
| Outlined text field | `x=14..386`, `y=125..181`, `372 x 56` | same fixed geometry |
| Prefix search glyph | `17 x 17` at `(28, 144)` | same icon geometry |
| Input caret while focused | `(65, 141)`, `10 x 24` painted area | system-rendered |
| Placeholder `제목, 메모, 장소 검색` | `125 x 14` at `(76, 145)` | about `100 x 11` |
| Submit arrow glyph | about `16 x 16`, centered near `(315, 153)` | same icon geometry |
| Close glyph | about `16 x 16`, centered near `(364, 153)` | same icon geometry |

The search panel uses an `AnimatedSize` duration of `220 ms` with
`easeOutCubic`. Before input results appear, the search panel has a fixed
height of approximately `67` pixels including its bottom separator.

### Filter sheet

The filter sheet was opened and measured in the iPhone 17 Simulator without
changing any filter, category, or density setting.

| Element | Simulator measurement |
| --- | --- |
| Sheet top | `y=392` |
| Sheet height to viewport bottom | `482` |
| Sheet width | `400` |
| Horizontal content inset | `16` each side |
| Drag handle | centered at `x=200`, about `32 x 4` |
| Title `검색/필터` anchor | starts at `(16, 443)` |
| Current-view search field | outer bounds about `x=16..384`, `y=472..531`, `368 x 56` |
| Density selector | outer bounds about `x=16..384`, `y=543..599`, `368 x 56` |
| D-day switch row label | starts at `(16, 619)`, label box `122 x 15` |
| Holiday switch row label | starts at `(16, 675)`, label box `74 x 14` |
| Category section heading | starts at `(16, 722)`, label box `50 x 12` |
| Category-chip text baseline | `y=762..773` |
| Clear button | left-aligned at the bottom; text / icon area ends near `x=159` |
| Done button fill | `x=313..384`, `y=811..850`, `72 x 40` |

Visible text inventory in the captured filter state:

- `검색/필터`
- `현재 보기에서 검색`
- `일정 표시 밀도`
- `기본`
- `D-day 일정만 보기`
- `공휴일 표시`
- `분류 표시`
- category labels `기본`, `학사`, `공휴일`
- `검색어 지우기`
- `완료`

All filter text follows the system text scaler except for platform-controlled
input caret and switch rendering. The confirmed physical-to-Simulator text
ratio is therefore expected to remain approximately `0.80x` for the textual
content while field, switch, chip, and button hit-target geometry remains
unchanged.

### Month/year picker

The month/year picker was captured live in the iPhone 17 Simulator. The
dialog values below use its visible bounds; the derived tile size remains
useful because Flutter constrains the requested `370`-point content width to
the dialog's available content width.

| Element | iPhone 17 constraint / implementation value |
| --- | --- |
| Dialog outer bounds | `x=17..383`, `y=285..615`, about `366 x 330` |
| Dialog horizontal inset | about `17` each side (implementation inset: `18`) |
| Maximum dialog outer width | `400 - 36 = 364` before shadow rasterization |
| Requested content width | `370`, constrained by the dialog width |
| Dialog title | `연월 선택` |
| Year row | four `IconButton` controls plus one expanded year label |
| Year actions | `10년 전`, `1년 전`, current year, `1년 후`, `10년 후` |
| Month grid | `4` columns by `3` rows |
| Month-grid gaps | `8` horizontal, `8` vertical |
| Month-tile aspect ratio | `2.55` width / height |
| Approximate available content width | `316` after standard dialog content insets |
| Derived tile width | `(316 - 24) / 4 = 73` |
| Derived tile height | `73 / 2.55 = 28.63` |
| Month labels | `1월` through `12월`, one line, no wrapping |
| Footer actions | `취소`, `이동` |

The picker title, year label, 12 month labels, and footer labels follow the
system text scaler. Their physical iPhone rendering is expected to be about
`0.80x` of the Simulator rendering until the two devices use the same iOS text
size setting. The tile geometry, four-column grid, gaps, and dialog insets do
not scale with the text setting.

## Ratio reference table

All percentages in this section use the iPhone 17 app viewport of `400 x 874`.
They are layout ratios, not screenshots scaled to a different device.

| Surface | Fixed geometry in points | Ratio of viewport |
| --- | --- | --- |
| Header utility row | horizontal padding `14`; top/bottom padding `10` | `3.5%` horizontal padding |
| Month card | `x=4..396` | `98.0%` width |
| Inner month grid | `x=7..393` | `96.5%` width |
| Day column | `55.143` wide | `13.786%` width per column |
| Month-grid inner padding | left/right `3`, top/bottom `6` | `0.75%` width; `0.69%` height |
| Bottom navigation outer padding | `18, 2, 18, 0` | `4.5%` horizontal; `0.23%` top |
| Bottom navigation active area | `73 x 65` per item | `18.25%` width; `7.44%` height |
| Bottom-navigation icon | `20 x 20` | `5.0%` viewport width |
| Expanded search field | `372 x 56` | `93.0%` width; `6.41%` height |
| Filter-sheet content width | `368` after `16`-point insets | `92.0%` width |
| Filter-sheet completion button | `72 x 40` | `18.0%` width; `4.58%` height |
| Month-picker dialog | about `366 x 330` | `91.5%` width; `37.8%` height |
| Month-picker tile | about `73 x 28.6` | `18.25%` width; `3.27%` height |
| Weekly content inset | `12` each side | `3.0%` width |
| Weekly day-card inner padding | `10` | `2.5%` width |
| Daily event-panel padding | `16` all sides | `4.0%` width; `1.83%` height |
| Quick-access sheet inset | `16, 0, 16, 18` | `4.0%` horizontal; `2.06%` bottom |
| Settings list inset | `16, 10, 16, 24` | `4.0%` horizontal; `1.14%` top; `2.75%` bottom |

## Additional view checks

The following view structures were checked against the active Flutter source.
No setting, account, or calendar data was changed.

### Weekly calendar

- Weekly navigation is a `PageView`; one horizontal swipe advances or rewinds
  exactly one seven-day range.
- On the iPhone compact layout, the week content is a vertically scrollable
  seven-card list with outer padding `12, 0, 12, 12` and `8` pixels between
  day cards.
- Each day card uses a `10` pixel radius, `10` pixel internal padding, and a
  selected border width of `1.4` pixels.
- Each mobile day card shows at most four event flags. Additional events are
  represented by a `+N` label; each event flag has horizontal `8` and vertical
  `7` pixel padding, a `6` pixel radius, and up to two lines of text.
- Week-card event text has a nominal `12` pixel size and follows the system
  text scaler.
- Live iPhone 17 Simulator capture confirmed that the seven cards preserve the
  `12`-point outer inset and `8`-point inter-card gap. The selected card uses
  a blue `1.4`-point stroke without moving the card's content. At four or more
  events the card becomes taller and the parent list scrolls; it is not clipped
  by the fixed bottom navigation.

### Daily calendar

- Daily navigation is a `PageView`; one horizontal swipe advances or rewinds
  one calendar day.
- The daily surface is the event-detail panel with `16` pixel outer padding.
- It contains a date heading, a fixed add-event icon button, a `12` pixel gap,
  and an always-scrollable event list separated by `8` pixels.
- The empty state text is `일정이 없습니다.`. Event content is data-dependent
  and uses the shared event-tile implementation.
- Live capture with four events on July 17 confirmed the heading, event cards,
  map/weather/link metadata rows, and edit/delete controls remain inside the
  `16`-point content inset. The event list, not the page, owns vertical scroll.

### Quick access

- Quick access opens as a modal bottom sheet with a system drag handle.
- The content uses `16, 0, 16, 18` padding and a shrink-wrapped `ListView`.
- The visible sections are `빠른 보기`, `월간 미니 캘린더`, `오늘 일정`, and
  `D-day`.
- Card spacing is `12` pixels after the title and `10` pixels between cards.
- No quick-access action was invoked during the check.
- Live capture showed the three cards together in one sheet on iPhone 17. The
  title-to-first-card gap is `12`, cards are separated by `10`, card padding is
  `14`, icon-to-content gap is `12`, and item-line spacing is `3`.

### LLM input sheet

- The LLM button opens an `isScrollControlled` modal bottom sheet with a
  system drag handle.
- The composer has a white surface, a top divider, and padding
  `12, 10, 12, 12`.
- The input hint is `일정을 입력하세요`; it accepts one to three lines.
- The submit button is disabled until non-whitespace input exists. No text was
  entered and no schedule parsing or event creation was triggered.
- Live capture placed the sheet top at approximately `y=713` (`81.6%` of the
  viewport) when the keyboard is hidden. The input hint was centered in the
  composer and the disabled send control stayed within the right touch target.
- The current implementation opens `ChatInputBar`, which routes input to the
  on-device schedule parser. It is a schedule-entry surface labelled `LLM`,
  not a connected external LLM service. This is a product-label fact to decide
  on separately; no behavior was changed during measurement.

### Settings

- Settings uses a standard `AppBar` titled `설정` and a vertically scrollable
  list with padding `16, 10, 16, 24`.
- The sections are `알림`, `달력`, `개인정보`, `분류`, `AI`, `계정`, and
  `앱 정보`.
- The section contents use system-scaled text, while standard control hit
  targets (switches, segmented buttons, dropdowns, and buttons) retain their
  Material dimensions.
- Account, notification, category, AI, and privacy controls were inspected
  only; none was pressed or changed.
- Live iPhone 17 capture confirmed the narrow-layout notification test action
  intentionally wraps under its description, while the `12h`/`24h` segmented
  control remains on the right. The D-day chip row wraps rather than colliding
  with its labels. No clipped text, overlapping hit target, or horizontal
  overflow was visible in the inspected notification section.

## UI findings from the actual iPhone 17 analysis

1. **There is no iPhone-17 viewport-ratio mismatch in the monthly layout.**
   The card, calendar grid, header actions, selected date, and five bottom
   navigation targets use the same `400 x 874` geometry in both captures.
2. **The only cross-device visual difference measured is the system text
   scale.** The mirrored physical phone is approximately `0.80x` for scalable
   text, while the Simulator uses its default size. Geometry and icons do not
   scale with that setting. Changing Flutter font sizes to force a match would
   make the application less accessible and would not solve the underlying
   device-setting difference.
3. **At the current iPhone 17 width, no real overlap was found** in the
   monthly grid, active bottom navigation, weekly cards, daily event cards,
   quick-access sheet, notification settings, filter sheet, or month picker.
4. **The actual density boundary is data-dependent.** The month grid permits
   five visible event lanes at width `400` in standard density; the week cards
   intentionally cap their visible event flags at four and represent the rest
   as `+N`. Those values should be retained as explicit product rules when
   future UI work changes event density.

## Follow-up live checks

The Simulator input channel briefly disconnected during the pass, then
recovered. The following surfaces were opened and visually checked on the same
iPhone 17 Simulator. No data was created, edited, deleted, searched, or
submitted.

### Weekly calendar live check

- The weekly tab opened with Sunday 12 July through Saturday 18 July visible.
- The day-card list scrolls vertically under the fixed header and bottom bar.
- Long weeks remain readable: Thursday displays three event flags and Friday
  displays its event content within the selected card; no text overlapped the
  card border or bottom bar.
- Empty days display `일정 없음` with visibly reduced emphasis.

### Daily calendar live check

- The daily tab opened for `7월 17일 금요일`.
- Four event cards were visible: academic-change period, class-reservation
  period, Constitution Day, and ophthalmology appointment.
- The appointment card displayed its time, map shortcut, weather, and URL
  rows without collision with the edit/delete controls.
- The event list had remaining space above the fixed bottom bar and did not
  clip the final card.

### Quick access live check

- The bottom sheet exposed all three cards without requiring a scroll:
  `월간 미니 캘린더`, `오늘 일정`, and `D-day`.
- The summary showed `일정 15개`, `D-day 1개`, and `공휴일 1개`.
- The Today card showed four current-day entries and the D-day card showed
  `전역🎉`; no action card was selected.

### Settings live check

- The settings top section rendered as a constrained white panel below the
  standard iOS-style navigation header.
- The notification-test control, reminder selector, all-day reminder time,
  12h/24h segmented control, morning-briefing switch, and D-day chips were
  visible and aligned.
- The settings list continues below the viewport, confirming intended vertical
  scrolling to the calendar, privacy, category, AI, account, and app-info
  sections.
- No switch, dropdown, time selector, chip, account control, or notification
  button was pressed.

### LLM input live check

- The LLM sheet opened over the daily view with the standard drag handle and
  a dimmed background.
- The composer field displayed `일정을 입력하세요` with the chat icon.
- The upward submit button was visibly disabled while the field was empty.
- The sheet remained above the bottom safe area and did not obscure the
  composer; no text was entered or parsed.
