import Testing
@testable import Caloryn

@Suite("History detail pane selection")
@MainActor
struct HistoryDetailSelectionTests {
    @Test("With nothing chosen the calorie trend shows when it can drill down")
    func defaultsToCalorieTrend() {
        let selection = HistoryDetailSelection()

        #expect(
            selection.pane(range: .week, canDrillIntoCalorieTrend: true, hasRecurringPattern: true)
                == .calorieTrend(.week)
        )
    }

    @Test("With nothing chosen and a trend too thin to drill into, the pattern shows")
    func defaultsToPatternWithoutTrend() {
        let selection = HistoryDetailSelection()

        #expect(
            selection.pane(range: .week, canDrillIntoCalorieTrend: false, hasRecurringPattern: true)
                == .recurringPattern
        )
    }

    @Test("With neither detail available the pane is empty")
    func emptyWithoutEitherDetail() {
        let selection = HistoryDetailSelection()

        #expect(
            selection.pane(range: .week, canDrillIntoCalorieTrend: false, hasRecurringPattern: false)
                == .empty
        )
        #expect(HistoryDetailSelection.Pane.empty.detail == nil)
    }

    @Test("A chosen pattern shows even when the trend could drill down")
    func choosingThePattern() {
        var selection = HistoryDetailSelection()
        selection.choose(.recurringPattern)

        #expect(
            selection.pane(range: .week, canDrillIntoCalorieTrend: true, hasRecurringPattern: true)
                == .recurringPattern
        )
    }

    @Test("A chosen pattern that disappears falls back to the calorie trend")
    func patternDisappears() {
        var selection = HistoryDetailSelection()
        selection.choose(.recurringPattern)

        #expect(
            selection.pane(range: .week, canDrillIntoCalorieTrend: true, hasRecurringPattern: false)
                == .calorieTrend(.week)
        )
    }

    @Test("A chosen pattern that disappears with no trend to drill into leaves the pane empty")
    func patternDisappearsWithoutTrend() {
        var selection = HistoryDetailSelection()
        selection.choose(.recurringPattern)

        #expect(
            selection.pane(range: .week, canDrillIntoCalorieTrend: false, hasRecurringPattern: false)
                == .empty
        )
    }

    @Test("A chosen trend that can no longer drill down falls back to the pattern")
    func trendCannotDrillDown() {
        var selection = HistoryDetailSelection()
        selection.choose(.calorieTrend)

        #expect(
            selection.pane(range: .week, canDrillIntoCalorieTrend: false, hasRecurringPattern: true)
                == .recurringPattern
        )
    }

    @Test("A range change moves the trend pane to the new range and keeps the choice for when it returns")
    func rangeChange() {
        var selection = HistoryDetailSelection()
        selection.choose(.calorieTrend)

        let week = selection.pane(range: .week, canDrillIntoCalorieTrend: true, hasRecurringPattern: true)
        let month = selection.pane(range: .month, canDrillIntoCalorieTrend: true, hasRecurringPattern: true)
        let thinRange = selection.pane(range: .twoWeeks, canDrillIntoCalorieTrend: false, hasRecurringPattern: true)
        let back = selection.pane(range: .week, canDrillIntoCalorieTrend: true, hasRecurringPattern: true)

        #expect(week == .calorieTrend(.week))
        #expect(month == .calorieTrend(.month))
        #expect(week != month)
        #expect(thinRange == .recurringPattern)
        #expect(back == .calorieTrend(.week))
    }

    @Test("A range change leaves a chosen pattern pane as it was")
    func rangeChangeKeepsPattern() {
        var selection = HistoryDetailSelection()
        selection.choose(.recurringPattern)

        let week = selection.pane(range: .week, canDrillIntoCalorieTrend: true, hasRecurringPattern: true)
        let quarter = selection.pane(range: .quarter, canDrillIntoCalorieTrend: true, hasRecurringPattern: true)

        #expect(week == quarter)
        #expect(quarter.detail == .recurringPattern)
    }
}
