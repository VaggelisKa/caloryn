#!/usr/bin/env swift
//
// Renders the app icon from the welcome screen's mark: the four-meal plate with a bite out
// of its top-left, in the Market palette.
//
//   swift scripts/render-app-icon.swift
//
// Writes the three 1024×1024 PNGs the icon set lists (`Caloryn/Assets.xcassets/
// AppIcon.appiconset/Contents.json`): light, dark and tinted. Colours are read from the
// Color Sets in `CalorynShared/SharedColors.xcassets`, so the icon cannot drift from the
// app — re-run this after changing a meal colour or the page.
//
// Geometry follows `WelcomePlateMark`: a ring whose outer radius is 94% of the mark and
// whose hole is 70% of that (the Today donut's `innerRadius`), four equal sectors from
// twelve o'clock in `MealType.sortOrder`, each parted from the next by the page showing
// through, and a disc of 34% of the mark centred at (21%, 19%) taken out of the ring. The
// mark fills 76% of the icon, the circle of Apple's icon grid, so the ring clears the
// system's rounded mask with the same margin a glyph gets.
//
// - Light: the ring on the page, opaque, as the icon set requires.
// - Dark: the dark-appearance fills on a transparent background; the system supplies the
//   dark backdrop, and the bite is transparent so the backdrop shows through it.
// - Tinted: a grey ring on a transparent background; the system maps luminance to the
//   tint, so the four sectors step from light to dark in their meals' order of brightness
//   and stay tellable apart.

import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let colorsURL = root.appendingPathComponent("CalorynShared/SharedColors.xcassets")
let iconSetURL = root.appendingPathComponent("Caloryn/Assets.xcassets/AppIcon.appiconset")

enum Appearance: String {
    case light, dark
}

/// One Color Set's value for an appearance, as the catalog declares it.
func color(_ name: String, _ appearance: Appearance) throws -> CGColor {
    let url = colorsURL.appendingPathComponent("\(name).colorset/Contents.json")
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    let colors = json["colors"] as! [[String: Any]]
    let entry = colors.first { entry in
        let appearances = entry["appearances"] as? [[String: String]] ?? []
        let declared = appearances.first { $0["appearance"] == "luminosity" }?["value"]
        return (declared ?? "light") == appearance.rawValue
    }!
    let components = (entry["color"] as! [String: Any])["components"] as! [String: String]
    func channel(_ key: String) -> CGFloat {
        let text = components[key]!
        if text.hasPrefix("0x") {
            return CGFloat(Int(text.dropFirst(2), radix: 16)!) / 255
        }
        return CGFloat(Double(text)!)
    }
    return CGColor(
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        components: [channel("red"), channel("green"), channel("blue"), channel("alpha")]
    )!
}

let size: CGFloat = 1024
/// The mark's edge, as a fraction of the icon.
let markScale: CGFloat = 0.76
let meals = ["MealBreakfast", "MealLunch", "MealDinner", "MealSnack"]

/// The mark as the welcome screen lays it out, scaled to the icon.
struct Mark {
    /// The mark's own size: what `WelcomePlateMark` calls 200pt.
    let mark = size * markScale
    let center = CGPoint(x: size / 2, y: size / 2)
    var origin: CGPoint { CGPoint(x: center.x - mark / 2, y: center.y - mark / 2) }
    var outerRadius: CGFloat { mark * 0.94 / 2 }
    var innerRadius: CGFloat { outerRadius * 0.7 }
    /// The Today donut's 1.5pt inset at 168pt, as a gap between sectors.
    var gap: CGFloat { mark * 1.5 / 168 }
    var biteRadius: CGFloat { mark * 0.34 / 2 }
    /// Core Graphics' origin is bottom-left; the mark's bite is at (21%, 19%) from the top.
    var biteCenter: CGPoint { CGPoint(x: origin.x + mark * 0.21, y: origin.y + mark * (1 - 0.19)) }

    func draw(in context: CGContext, fills: [CGColor], bite: CGColor?) {
        let quarter = CGFloat.pi / 2
        for (index, fill) in fills.enumerated() {
            // Clockwise from twelve o'clock, in a bottom-left origin.
            let start = quarter - CGFloat(index) * quarter
            let end = start - quarter
            context.saveGState()
            context.setFillColor(fill)
            context.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: true)
            context.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: false)
            context.closePath()
            context.fillPath()
            context.restoreGState()
        }

        // The page between sectors: four strokes along the sector edges, which is how the
        // chart's angular inset reads at this size.
        context.saveGState()
        context.setBlendMode(bite == nil ? .clear : .normal)
        if let bite { context.setStrokeColor(bite) }
        context.setLineWidth(gap)
        for index in 0..<4 {
            let angle = quarter - CGFloat(index) * quarter
            context.move(to: center)
            context.addLine(to: CGPoint(
                x: center.x + cos(angle) * (outerRadius + gap),
                y: center.y + sin(angle) * (outerRadius + gap)
            ))
        }
        context.strokePath()
        context.restoreGState()

        // The bite: the page, or nothing at all where the system draws the backdrop.
        context.saveGState()
        context.setBlendMode(bite == nil ? .clear : .normal)
        if let bite { context.setFillColor(bite) }
        context.fillEllipse(in: CGRect(
            x: biteCenter.x - biteRadius,
            y: biteCenter.y - biteRadius,
            width: biteRadius * 2,
            height: biteRadius * 2
        ))
        context.restoreGState()
    }
}

func render(_ fileName: String, background: CGColor?, fills: [CGColor], bite: CGColor?) throws {
    let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    if let background {
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
    Mark().draw(in: context, fills: fills, bite: bite)

    let image = context.makeImage()!
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try data.write(to: iconSetURL.appendingPathComponent(fileName))
    print("wrote \(fileName)")
}

func grey(_ value: CGFloat) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [value, value, value, 1])!
}

let page = try color("PageBackground", .light)
try render(
    "AppIcon.png",
    background: page,
    fills: try meals.map { try color($0, .light) },
    bite: page
)
try render(
    "AppIconDark.png",
    background: nil,
    fills: try meals.map { try color($0, .dark) },
    bite: nil
)
// Breakfast is the brightest meal and dinner the darkest; lunch and snack sit between.
try render(
    "AppIconTinted.png",
    background: nil,
    fills: [grey(1.0), grey(0.78), grey(0.52), grey(0.65)],
    bite: nil
)
