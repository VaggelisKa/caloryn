import SwiftUI

/// A primary region beside a secondary one, for a page `RegularWidthSplit` has given columns.
/// Wider than tall, the split arrangement puts them side by side on the flat display, and
/// rearranges them around the fold when iPhone Duo is partially open — the axes are left
/// unconstrained so a horizontal fold (the laptop pose) can stack them instead. Both regions
/// scroll on their own.
///
/// The arrangement view is iOS 27.1; before it the same two regions sit in an `HStack`.
/// The SDK has to know it too: Swift 6.4 is Xcode 27.1, and CI builds with Xcode 26.6.
/// A page taller than wide always gets the `HStack`: it has no fold to arrange around, and an
/// arrangement view would stack the regions instead, clipping the primary one.
struct SplitColumns<Primary: View, Secondary: View>: View {
    let split: RegularWidthSplit
    @ViewBuilder let primary: Primary
    @ViewBuilder let secondary: Secondary

    var body: some View {
        if split.arrangesAroundFold {
            arrangedAroundFold
        } else {
            sideBySide
        }
    }

    @ViewBuilder
    private var arrangedAroundFold: some View {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            ArrangementView {
                primary
                    // Enough for Today's hero: a 168pt donut beside its number column needs
                    // about 380pt. No maximum, so the divider can still land on the fold in the
                    // book pose.
                    .splitArrangementLayoutRatio(
                        minHorizontal: 0.36,
                        idealHorizontal: RegularWidthSplit.primaryColumnFraction,
                        minVertical: 0.38,
                        idealVertical: 0.42
                    )
            } secondary: {
                secondary
            }
            .arrangementViewStyle(.split)
        } else {
            sideBySide
        }
        #else
        sideBySide
        #endif
    }

    private var sideBySide: some View {
        HStack(alignment: .top, spacing: 0) {
            primary
                .containerRelativeFrame(.horizontal) { width, _ in RegularWidthSplit.primaryColumnWidth(forPageWidth: width) }

            secondary
        }
    }
}
