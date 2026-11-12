import UIKit
import UniformTypeIdentifiers

enum DayExportTable {
    static func tabSeparated(_ report: DayExportReport) -> String {
        records(report)
            .map { $0.map(tabSafe).joined(separator: "\t") }
            .joined(separator: "\n") + "\n"
    }

    static func html(_ report: DayExportReport) -> String {
        let header = headerCells(report)
            .map { "<th>\(escaped($0))</th>" }
            .joined()
        var body = ""
        for meal in report.meals {
            for food in meal.foods {
                body += row([meal.title, CSVExporter.neutralised(food.label)] + food.cells)
            }
            body += row([meal.title, "Subtotal"] + meal.subtotal.cells, emphasis: "b")
        }
        body += row(["", report.total.label] + report.total.cells, emphasis: "b")
        if let target = report.target {
            body += row(["", target.label] + target.cells, emphasis: "i")
        }

        return """
        <meta charset="utf-8"><p><b>\(escaped(report.title))</b></p>\
        <table border="1" cellspacing="0" cellpadding="4">\
        <thead><tr>\(header)</tr></thead><tbody>\(body)</tbody></table>
        """
    }

    static func copy(_ report: DayExportReport, to pasteboard: UIPasteboard = .general) {
        let text = tabSeparated(report)
        pasteboard.setItems([[
            UTType.html.identifier: html(report),
            UTType.tabSeparatedText.identifier: text,
            UTType.utf8PlainText.identifier: text
        ]])
    }

    private static func records(_ report: DayExportReport) -> [[String]] {
        var records: [[String]] = [[report.title], headerCells(report)]
        for meal in report.meals {
            records += meal.foods.map { [meal.title, CSVExporter.neutralised($0.label)] + $0.cells }
            records.append([meal.title, "Subtotal"] + meal.subtotal.cells)
        }
        records.append(["", report.total.label] + report.total.cells)
        if let target = report.target {
            records.append(["", target.label] + target.cells)
        }
        return records
    }

    private static func headerCells(_ report: DayExportReport) -> [String] {
        [DayExportReport.mealColumnTitle, DayExportReport.foodColumnTitle] + report.columns.map(\.header)
    }

    private static func row(_ cells: [String], emphasis: String? = nil) -> String {
        let content = cells.map { cell in
            let text = escaped(cell)
            guard let emphasis, !text.isEmpty else { return "<td>\(text)</td>" }
            return "<td><\(emphasis)>\(text)</\(emphasis)></td>"
        }
        return "<tr>\(content.joined())</tr>"
    }

    private static func tabSafe(_ cell: String) -> String {
        String(cell.map { $0 == "\t" || $0.isNewline ? " " : $0 })
    }

    private static func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
