# History Pattern Discovery

Status: accepted

Caloryn's History tab moves from a weekly calorie recap plus daily rows toward a pattern-discovery experience that explains recurring nutrition behavior across 7, 14, 30, and 90 day ranges. The first implementation is a narrow slice: a separate pure Swift `HistoryAnalytics` layer with tests, a range-aware calorie trend, goal consistency, macro patterns, previous-range comparison, low-coverage caveats, and weekly consistency for longer ranges.

The redesigned History screen leads with the calorie trend in every range so the first card answers what was tracked against the user's goal. Goal consistency follows directly after it so the screen balances goal-oriented calorie review with tracking consistency.
Goal consistency metrics will count logged days only, while logging coverage remains adjacent and explicit so missing days are visible without being treated as zero-calorie days.
The calorie trend should emphasize logged calories first and distance from target second. Bars show daily calorie totals for 7, 14, and 30 day ranges. The 90-day range uses one bar per calendar week, where bar height is average calories per logged day in that week. A single rule marks the calorie target; a separate average rule is intentionally omitted to keep the chart simple. Status color communicates under/on-track/over, but chart legends are omitted to reduce visual noise.
Daily detail rows are removed from the main History screen. Exact per-day lookup should return later as a drill-down from a chart or a dedicated log surface, not as a persistent section on the main insight screen.
Weekly consistency appears for 30 and 90 day ranges. It summarizes on-track logged days per calendar week with W1/W2/W3 labels and no card footer or arbitrary 50% reference line.
Macro patterns stay inline as concise summary rows. Missing previous-range data is omitted rather than rendered as "No prev data".
Logging coverage remains secondary context. It can appear as a confidence metric or caveat, but it should not drive the top chart or headline for short ranges.
Goal consistency copy should lead with the result, such as "5 days on track", and treat the denominator, such as "of 7 logged days", as supporting text.

## Considered Options

- Keep adding charts directly inside `HistoryView`.
- Build one large History redesign with every agreed pattern block at once.
- Start with a tested analytics layer and a narrow scan-first UI slice.

We chose the narrow analytics-first slice because most risk is in the aggregation rules, not the SwiftUI layout. Keeping calculations outside SwiftUI makes the behavior testable and keeps the History screen from becoming a large view that mixes presentation with nutrition logic.

## Consequences

History v1 compares historical days against the current profile target because food log entries do not store daily target snapshots. It will not use Apple Health active-energy history until daily activity or target snapshots are persisted.

The first slice does not include drill-down sheets. The next phase should add actionable drill-downs for exact per-day lookup from the calorie chart, top foods or recurring causes behind over/under-target periods, meal contribution, enabled nutrient patterns, produce variety, and conditional Nutri-Score history. Longer-term detail views should use SwiftUI-native sheet presentation for longer lists such as top foods, over-target days, and meal-level causes, while tiny summaries can stay inline.
