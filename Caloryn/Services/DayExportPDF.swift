import Foundation
import UIKit

enum DayExportPDF {
    static let a4 = CGSize(width: 595, height: 842)
    static let usLetter = CGSize(width: 612, height: 792)

    struct Layout: Equatable {
        let pageSize: CGSize
        let columnBands: [Range<Int>]
    }

    static func pageSize(for locale: Locale) -> CGSize {
        locale.measurementSystem == .us ? usLetter : a4
    }

    static func layout(columnCount: Int, paper: CGSize) -> Layout {
        let portrait = CGSize(width: min(paper.width, paper.height), height: max(paper.width, paper.height))
        if columnCount <= DayExportPageLayout.columnsThatFit(pageWidth: portrait.width) {
            return Layout(pageSize: portrait, columnBands: [0..<columnCount])
        }

        let landscape = CGSize(width: portrait.height, height: portrait.width)
        let perBand = DayExportPageLayout.columnsThatFit(pageWidth: landscape.width)
        let bandCount = (columnCount + perBand - 1) / perBand
        var bands: [Range<Int>] = []
        var start = 0
        for band in 0..<bandCount {
            let size = columnCount / bandCount + (band < columnCount % bandCount ? 1 : 0)
            bands.append(start..<start + size)
            start += size
        }
        return Layout(pageSize: landscape, columnBands: bands)
    }

    static func exportURL(for report: DayExportReport, locale: Locale = .current) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(report.fileName)
            .appendingPathExtension("pdf")

        do {
            try data(for: report, paper: pageSize(for: locale)).write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    static func presentPrintDialog(for report: DayExportReport, locale: Locale = .current) {
        let paper = pageSize(for: locale)
        let pageSize = layout(columnCount: report.columns.count, paper: paper).pageSize
        let info = UIPrintInfo.printInfo()
        info.jobName = report.fileName
        info.outputType = .general
        info.orientation = pageSize.width > pageSize.height ? .landscape : .portrait

        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = data(for: report, paper: paper)
        controller.present(animated: true)
    }

    static func data(for report: DayExportReport, paper: CGSize = a4) -> Data {
        let layout = layout(columnCount: report.columns.count, paper: paper)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: report.title,
            kCGPDFContextCreator as String: "Caloryn"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: layout.pageSize), format: format)

        return renderer.pdfData { context in
            for (index, band) in layout.columnBands.enumerated() {
                var page = DayExportPageLayout(
                    context: context,
                    pageSize: layout.pageSize,
                    columns: Array(report.columns[band]),
                    cells: band
                )
                page.begin()
                page.drawHeading(
                    report.title,
                    caption: index == 0 ? "Caloryn food log" : "Caloryn food log, continued with more nutrients"
                )
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
}

private struct DayExportPageLayout {
    enum RowStyle {
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

    private static let margin: CGFloat = 40
    private static let minimumLabelWidth: CGFloat = 150
    private static let numericColumnWidth: CGFloat = 50
    private static let foodIndent: CGFloat = 10
    private static let cellPadding: CGFloat = 4
    private static let maximumLabelLines: CGFloat = 4

    static func columnsThatFit(pageWidth: CGFloat) -> Int {
        max(1, Int((pageWidth - 2 * margin - minimumLabelWidth) / numericColumnWidth))
    }

    let context: UIGraphicsPDFRendererContext
    let pageSize: CGSize
    let columns: [DayExportReport.Column]
    let cells: Range<Int>
    private var y: CGFloat = 0

    init(
        context: UIGraphicsPDFRendererContext,
        pageSize: CGSize,
        columns: [DayExportReport.Column],
        cells: Range<Int>
    ) {
        self.context = context
        self.pageSize = pageSize
        self.columns = columns
        self.cells = cells
    }

    private var contentWidth: CGFloat { pageSize.width - 2 * Self.margin }
    private var labelWidth: CGFloat { contentWidth - CGFloat(columns.count) * Self.numericColumnWidth }
    private var bottom: CGFloat { pageSize.height - Self.margin }

    mutating func begin() {
        context.beginPage()
        y = Self.margin
    }

    mutating func drawHeading(_ title: String, caption: String) {
        let titleAttributes = Self.attributes(font: .systemFont(ofSize: 18, weight: .bold), color: Self.ink)
        let captionAttributes = Self.attributes(font: .systemFont(ofSize: 10), color: Self.secondaryInk)

        y += draw(title, in: CGRect(x: Self.margin, y: y, width: contentWidth, height: .greatestFiniteMagnitude), attributes: titleAttributes)
        y += 2
        y += draw(caption, in: CGRect(x: Self.margin, y: y, width: contentWidth, height: .greatestFiniteMagnitude), attributes: captionAttributes)
        y += 16
    }

    mutating func drawColumnTitles() {
        var titleAttributes = Self.attributes(font: Self.columnTitleFont, color: Self.secondaryInk, alignment: .right)
        titleAttributes[.paragraphStyle] = Self.hyphenating(alignment: .right)
        let labelAttributes = Self.attributes(font: Self.columnTitleFont, color: Self.secondaryInk)
        let titles = columns.map { "\($0.compactTitle)\n\($0.unit.symbol)" }
        let cellWidth = Self.numericColumnWidth - Self.cellPadding
        let height = titles
            .map { measure($0, width: cellWidth, attributes: titleAttributes) }
            .max() ?? 0
        let rowHeight = ceil(height) + 2 * Self.cellPadding
        let textTop = y + Self.cellPadding

        draw(
            DayExportReport.foodColumnTitle,
            in: CGRect(x: Self.margin + Self.cellPadding, y: textTop + height - Self.columnTitleFont.lineHeight, width: labelWidth, height: rowHeight),
            attributes: labelAttributes
        )
        for (index, title) in titles.enumerated() {
            let x = Self.margin + labelWidth + CGFloat(index) * Self.numericColumnWidth
            draw(title, in: CGRect(x: x, y: textTop, width: cellWidth, height: rowHeight), attributes: titleAttributes)
        }

        strokeLine(at: y + rowHeight, width: 0.5, color: Self.rule)
        y += rowHeight
    }

    mutating func draw(_ row: DayExportReport.Row, style: RowStyle, keepingWith next: DayExportReport.Row? = nil) {
        let rowHeight = height(of: row, style: style)
        let reserved = rowHeight + (next.map { self.height(of: $0, style: .food) } ?? 0)
        if y + reserved > bottom {
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
        case .food, .target:
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
            in: CGRect(x: Self.margin + indent + Self.cellPadding, y: textTop, width: labelWidth - indent - 2 * Self.cellPadding, height: rowHeight - 2 * Self.cellPadding),
            attributes: labelAttributes,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
        for (index, cell) in row.cells[cells].enumerated() {
            let x = Self.margin + labelWidth + CGFloat(index) * Self.numericColumnWidth
            draw(
                cell,
                in: CGRect(x: x, y: textTop, width: Self.numericColumnWidth - Self.cellPadding, height: rowHeight),
                attributes: numberAttributes
            )
        }

        if style == .food {
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
        let maximumLabelHeight = ceil(Self.labelFont(style).lineHeight * Self.maximumLabelLines)
        let numberHeight = Self.numberFont(style).lineHeight
        return ceil(max(min(labelHeight, maximumLabelHeight), numberHeight)) + 2 * Self.cellPadding
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
    private func draw(
        _ text: String,
        in rect: CGRect,
        attributes: [NSAttributedString.Key: Any],
        options: NSStringDrawingOptions = .usesLineFragmentOrigin
    ) -> CGFloat {
        (text as NSString).draw(with: rect, options: options, attributes: attributes, context: nil)
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

    private static let columnTitleFont = UIFont.systemFont(ofSize: 8, weight: .semibold)

    private static func labelFont(_ style: RowStyle) -> UIFont {
        switch style {
        case .meal, .total:
            .systemFont(ofSize: 10, weight: .bold)
        case .food:
            .systemFont(ofSize: 9.5)
        case .target:
            .systemFont(ofSize: 9.5, weight: .medium)
        }
    }

    private static func numberFont(_ style: RowStyle) -> UIFont {
        switch style {
        case .meal, .total:
            .monospacedDigitSystemFont(ofSize: 9.5, weight: .bold)
        case .food:
            .monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        case .target:
            .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        }
    }

    private static func color(_ style: RowStyle) -> UIColor {
        switch style {
        case .target:
            secondaryInk
        case .meal, .food, .total:
            ink
        }
    }

    private static func hyphenating(alignment: NSTextAlignment) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.hyphenationFactor = 1
        return paragraph
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
