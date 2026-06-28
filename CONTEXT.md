# Caloryn

Caloryn is a nutrition-tracking context focused on daily food logging, personal nutrition goals, and retrospective eating-pattern review.

## Language

**History**:
The retrospective part of Caloryn where logged nutrition data is reviewed across a selected date range.
_Avoid_: Report, archive

**Pattern Discovery**:
A History experience that helps identify recurring nutrition behaviors across time, such as goal consistency, macro adherence, meal contribution, and food-quality signals.
_Avoid_: Dashboard, coaching, report

**Goal Consistency**:
The pattern that describes how often logged days land under, within, or over the user's nutrition goals across a selected range.
_Avoid_: Compliance, success rate

**Calorie Trend**:
A History visualization that shows logged calories over time against the user's calorie target.
The 7, 14, and 30 day ranges use daily bars. The 90-day range uses calendar-week bars showing average calories per logged day for each week.
Unlogged days appear as empty positions rather than zero-calorie days in daily ranges.
_Avoid_: Tracking coverage, goal consistency

**On Track**:
A logged day whose calories are within the accepted target band for the selected History analysis.
_Avoid_: Perfect, compliant, successful

**Logged Day**:
A calendar day that contains at least one food log entry.
_Avoid_: Active day, completed day

**Produce Variety**:
The range of distinct fruit and vegetable foods represented in logged meals.
_Avoid_: Five-a-day, servings

## Current History Direction

The History screen is an insight surface, not a log. It currently leads with Calorie Trend in every range, then Goal Consistency, then Weekly Consistency for 30/90 day ranges, then Macro Patterns when profile targets exist.

Daily detail rows have been removed from the main History screen. Exact day lookup should return as a drill-down from charts or a dedicated log surface, not as persistent content below the cards.

The runtime mock History preview gallery has been removed from the app launch path. Keep `#Preview` fixtures for Xcode preview coverage, but normal simulator runs should show the real app and real SwiftData-backed content.

## Next History Phase

Add the most actionable drill-downs: exact per-day detail from calorie bars, recurring causes behind over/under-target periods, top foods, meal contribution, enabled nutrient patterns, produce variety, and conditional Nutri-Score history. Use SwiftUI-native sheets for larger lists and keep short summaries inline.
