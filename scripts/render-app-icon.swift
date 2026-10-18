#!/usr/bin/env swift

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
let markScale: CGFloat = 0.76
let meals = ["MealBreakfast", "MealLunch", "MealDinner", "MealSnack"]

struct Mark {
    let mark = size * markScale
    let center = CGPoint(x: size / 2, y: size / 2)
    var origin: CGPoint { CGPoint(x: center.x - mark / 2, y: center.y - mark / 2) }
    var outerRadius: CGFloat { mark * 0.94 / 2 }
    var innerRadius: CGFloat { outerRadius * 0.7 }
    var gap: CGFloat { mark * 1.5 / 168 }
    var biteRadius: CGFloat { mark * 0.34 / 2 }
    var biteCenter: CGPoint { CGPoint(x: origin.x + mark * 0.21, y: origin.y + mark * (1 - 0.19)) }

    func draw(in context: CGContext, fills: [CGColor], bite: CGColor?) {
        let quarter = CGFloat.pi / 2
        for (index, fill) in fills.enumerated() {
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
try render(
    "AppIconTinted.png",
    background: nil,
    fills: [grey(1.0), grey(0.78), grey(0.52), grey(0.65)],
    bite: nil
)
