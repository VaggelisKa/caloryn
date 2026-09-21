import CoreGraphics
import Testing
@testable import Caloryn

/// The widths behind the food search placeholder rows.
///
/// What is worth pinning is that the same index always yields the same row —
/// the bars must not move while the shimmer runs — and that a group starting
/// part-way through the cycle continues it rather than repeating the rows
/// above it.
struct FoodSearchSkeletonTests {

    @Test("Asking twice yields the same rows")
    func widthsAreStable() {
        #expect(FoodSearchSkeleton.rows(count: 5) == FoodSearchSkeleton.rows(count: 5))
    }

    @Test("A group gives as many rows as asked for")
    func honoursTheCount() {
        #expect(FoodSearchSkeleton.rows(count: 3).count == 3)
        #expect(FoodSearchSkeleton.rows(count: 12).count == 12)
    }

    @Test("No rows, rather than a crash, for a count of zero or less")
    func emptyForNonPositiveCounts() {
        #expect(FoodSearchSkeleton.rows(count: 0).isEmpty)
        #expect(FoodSearchSkeleton.rows(count: -4).isEmpty)
    }

    @Test("An offset continues the cycle instead of restarting it")
    func offsetContinuesTheCycle() {
        let continuous = FoodSearchSkeleton.rows(count: 10)
        let tail = FoodSearchSkeleton.rows(count: 4, startingAt: 6)

        #expect(tail.map(\.titleWidth) == continuous.suffix(4).map(\.titleWidth))
    }

    @Test("A negative offset still lands on a real row")
    func negativeOffsetIsSafe() {
        let rows = FoodSearchSkeleton.rows(count: 3, startingAt: -2)

        #expect(rows.count == 3)
        #expect(rows.allSatisfy { $0.titleWidth > 0 })
    }

    @Test("Neighbouring rows differ, so the block does not read as a grid")
    func neighbouringRowsDiffer() {
        let widths = FoodSearchSkeleton.rows(count: FoodSearchSkeleton.fullScreenRowCount)
            .map(\.titleWidth)

        #expect(zip(widths, widths.dropFirst()).allSatisfy { $0 != $1 })
    }

    @Test("No bar is wider than the column the row promises it")
    func noBarOverflowsItsColumn() {
        let rows = FoodSearchSkeleton.rows(count: 20)

        #expect(rows.allSatisfy { $0.titleWidth <= FoodSearchSkeleton.maxTitleWidth })
        #expect(rows.allSatisfy { $0.subtitleWidth < $0.titleWidth })
    }
}
