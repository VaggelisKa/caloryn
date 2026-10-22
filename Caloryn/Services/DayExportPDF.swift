import Foundation
import UIKit

enum DayExportPDF {
    static let a4 = CGSize(width: 595, height: 842)
    static let usLetter = CGSize(width: 612, height: 792)

    static func pageSize(for locale: Locale) -> CGSize {
        locale.measurementSystem == .us ? usLetter : a4
    }

    static func exportURL(for report: DayExportReport, locale: Locale = .current) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(report.fileName)
            .appendingPathExtension("pdf")

        do {
            try data(for: report, pageSize: pageSize(for: locale)).write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    static func data(for report: DayExportReport, pageSize: CGSize = a4) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: report.title,
            kCGPDFContextCreator as String: "Caloryn"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        return renderer.pdfData { context in
            var page = DayExportPageLayout(context: context, pageSize: pageSize)
            page.begin()
            page.drawHeading(report.title)
            page.drawColumnTitles()

            for meal in report.meals {
                page.draw(meal.subtotal, style: .meal, keepingWith: meal.foods.first)
                for food in meal.foods {
                    page.draw(food, style: .food)
                }
            }

            page.draw(report.total, style: .total)
            if let target = report.target {
                page.draw(target, style: .target)
            }
        }
    }
}

private struct DayExportPageLayout {
    enum RowStyle {
        case columnTitles
        case meal
        case food
        case total
        case target
    }

    // Paper, not screen: a printed page has no dark appearance, so these are fixed
    // ink values rather than CalorynTheme tokens that would follow the device setting.
    private static let ink = UIColor.black
    private static let secondaryInk = UIColor(white: 0.4, alpha: 1)
    private static let rule = UIColor(white: 0.8, alpha: 1)
    private static let mealFill = UIColor(white: 0.94, alpha: 1)

    private static let margin: CGFloat = 48
    private static let numericColumnWidth: CGFloat = 64
    private static let foodIndent: CGFloat = 10
    private static let cellPadding: CGFloat = 5

    let context: UIGraphicsPDFRendererContext
    let pageSize: CGSize
    private var y: CGFloat = 0

    init(context: UIGraphicsPDFRendererContext, pageSize: CGSize) {
        self.context = context
        self.pageSize = pageSize
    }

    private var contentWidth: CGFloat { pageSize.width - 2 * Self.margin }
    private var labelWidth: CGFloat { contentWidth - 5 * Self.numericColumnWidth }
    private var bottom: CGFloat { pageSize.height - Self.margin }

    mutating func begin() {
        context.beginPage()
        y = Self.margin
    }

    mutating func drawHeading(_ title: String) {
        let titleAttributes = Self.attributes(font: .systemFont(ofSize: 18, weight: .bold), color: Self.ink)
        let captionAttributes = Self.attributes(font: .systemFont(ofSize: 10), color: Self.secondaryInk)

        y += draw(title, in: CGRect(x: Self.margin, y: y, width: contentWidth, height: .greatestFiniteMagnitude), attributes: titleAttributes)
        y += 2
        y += draw("Caloryn food log", in: CGRect(x: Self.margin, y: y, width: contentWidth, height: .greatestFiniteMagnitude), attributes: captionAttributes)
        y += 16
    }

    mutating func drawColumnTitles() {
        draw(DayExportReport.columnTitles, style: .columnTitles)
    }

    mutating func draw(_ row: DayExportReport.Row, style: RowStyle, keepingWith next: DayExportReport.Row? = nil) {
        let rowHeight = height(of: row, style: style)
        let reserved = rowHeight + (next.map { self.height(of: $0, style: .food) } ?? 0)
        if style != .columnTitles, y + reserved > bottom {
            begin()
            drawColumnTitles()
        }

        let rowRect = CGRect(x: Self.margin, y: y, width: contentWidth, height: rowHeight)
        switch style {
        case .meal:
            Self.mealFill.setFill()
            UIRectFill(rowRect)
        case .total:
            strokeLine(at: rowRect.minY, width: 1, color: Self.ink)
        case .columnTitles, .food, .target:
            break
        }

        let labelAttributes = Self.attributes(font: Self.labelFont(style), color: Self.color(style))
        let numberAttributes = Self.attributes(
            font: Self.numberFont(style),
            color: Self.color(style),
            alignment: .right
        )
        let indent = style == .food ? Self.foodIndent : 0
        let textTop = y + Self.cellPadding

        draw(
            row.label,
            in: CGRect(x: Self.margin + indent + Self.cellPadding, y: textTop, width: labelWidth - indent - 2 * Self.cellPadding, height: rowHeight),
            attributes: labelAttributes
        )
        for (index, cell) in row.numericCells.enumerated() {
            let x = Self.margin + labelWidth + CGFloat(index) * Self.numericColumnWidth
            draw(
                cell,
                in: CGRect(x: x, y: textTop, width: Self.numericColumnWidth - Self.cellPadding, height: rowHeight),
                attributes: numberAttributes
            )
        }

        if style == .columnTitles || style == .food {
            strokeLine(at: rowRect.maxY, width: 0.5, color: Self.rule)
        }
        y += rowHeight
    }

    private func height(of row: DayExportReport.Row, style: RowStyle) -> CGFloat {
        let indent = style == .food ? Self.foodIndent : 0
        let labelHeight = measure(
            row.label,
            width: labelWidth - indent - 2 * Self.cellPadding,
            attributes: Self.attributes(font: Self.labelFont(style), color: Self.ink)
        )
        let numberHeight = Self.numberFont(style).lineHeight
        return ceil(max(labelHeight, numberHeight)) + 2 * Self.cellPadding
    }

    private func strokeLine(at lineY: CGFloat, width: CGFloat, color: UIColor) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: Self.margin, y: lineY))
        path.addLine(to: CGPoint(x: Self.margin + contentWidth, y: lineY))
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    @discardableResult
    private func draw(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        (text as NSString).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        return measure(text, width: rect.width, attributes: attributes)
    }

    private func measure(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        ceil(
            (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: attributes,
                context: nil
            ).height
        )
    }

    private static func labelFont(_ style: RowStyle) -> UIFont {
        switch style {
        case .columnTitles:
            .systemFont(ofSize: 8.5, weight: .semibold)
        case .meal, .total:
            .systemFont(ofSize: 10.5, weight: .bold)
        case .food:
            .systemFont(ofSize: 10)
        case .target:
            .systemFont(ofSize: 10, weight: .medium)
        }
    }

    private static func numberFont(_ style: RowStyle) -> UIFont {
        switch style {
        case .columnTitles:
            .systemFont(ofSize: 8.5, weight: .semibold)
        case .meal, .total:
            .monospacedDigitSystemFont(ofSize: 10.5, weight: .bold)
        case .food:
            .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        case .target:
            .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        }
    }

    private static func color(_ style: RowStyle) -> UIColor {
        switch style {
        case .columnTitles, .target:
            secondaryInk
        case .meal, .food, .total:
            ink
        }
    }

    private static func attributes(
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    }
}
