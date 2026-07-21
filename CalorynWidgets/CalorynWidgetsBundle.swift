import SwiftUI
import WidgetKit

@main
struct CalorynWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyProgressWidget()
        QuickLogWidget()
    }
}
