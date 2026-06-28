# History Pattern Discovery

Status: accepted

Caloryn's History tab will move from a weekly calorie recap plus daily rows toward a pattern-discovery experience that explains recurring nutrition behavior across 7, 14, 30, and 90 day ranges. The first implementation will be a narrow slice: a separate pure Swift `HistoryAnalytics` layer with tests, a range-aware headline, goal consistency, macro patterns, previous-range comparison, low-coverage caveats, and weekly rollups for longer ranges.

The redesigned History headline will generally lead with goal consistency, such as how many logged days were on track, with average calories against the current target as supporting context.
Goal consistency metrics will count logged days only, while logging coverage remains adjacent and explicit so missing days are visible without being treated as zero-calorie days.
The 7-day range is the exception: it will lead with a calorie trend because short ranges are better suited to detailed day-by-day review. Goal consistency remains directly adjacent so the screen balances what was logged with whether logged days landed near the user's goals.
The 14-day range will also include the calorie trend, but below goal consistency. Daily bars remain readable across 14 days; 30-day and 90-day ranges should favor weekly rollups instead.
The calorie trend should emphasize exact logged calories first and distance from target second: bars show daily calorie totals, a rule marks the calorie target, a second rule marks the logged-day average when available, and status color communicates under/on-track/over.
Daily detail rows remain available for 7-day and 14-day ranges because those ranges are still small enough for exact per-day lookup. Longer ranges should avoid daily lists and use rollups instead.
Logging coverage remains secondary context. It can appear as a confidence metric or caveat, but it should not drive the top chart or headline for short ranges.
Goal consistency copy should lead with the result, such as "5 days on track", and treat the denominator, such as "of 7 logged days", as supporting text.

## Considered Options

- Keep adding charts directly inside `HistoryView`.
- Build one large History redesign with every agreed pattern block at once.
- Start with a tested analytics layer and a narrow scan-first UI slice.

We chose the narrow analytics-first slice because most risk is in the aggregation rules, not the SwiftUI layout. Keeping calculations outside SwiftUI makes the behavior testable and keeps the History screen from becoming a large view that mixes presentation with nutrition logic.

## Consequences

History v1 compares historical days against the current profile target because food log entries do not store daily target snapshots. It will not use Apple Health active-energy history until daily activity or target snapshots are persisted. Later slices can add enabled nutrient patterns, meal contribution, produce variety, conditional Nutri-Score history, and top-food drill-down sheets without changing the core direction.
The first slice will not include drill-down sheets. Longer-term detail views should use SwiftUI-native sheet presentation for longer lists such as top foods, over-target days, and meal-level causes, while tiny summaries can stay inline.
