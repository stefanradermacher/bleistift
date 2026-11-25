// Copyright 2026 Stefan Radermacher
//
// NOT covered by the Apache License 2.0 that applies to the rest of Bleistift.
// This file draws the app icon and the document icon, which are marks of
// Stefan Radermacher and are reserved. See TRADEMARKS.md.

import AppKit

// Draws the Bleistift app icon into the asset catalog and the document icon into Resources.
// Usage (from the project folder): swift scripts/make_icon.swift
// All drawing is done on a 1024 × 1024 canvas and scaled for the smaller sizes.

// MARK: helpers
func c(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func rr(_ r: NSRect, _ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius) }
var ctx: CGContext { NSGraphicsContext.current!.cgContext }
/// Output size relative to 1024; shadows are not affected by the scaled drawing, so they scale by hand.
var outputScale: CGFloat = 1
/// Additional scale of the drawing inside the icon; shadows follow it as well.
var drawingScale: CGFloat = 1
func shadow(_ blur: CGFloat, _ dy: CGFloat, _ alpha: CGFloat) {
    let s = outputScale * drawingScale
    ctx.setShadow(offset: CGSize(width: 0, height: dy * s), blur: blur * s,
                  color: NSColor.black.withAlphaComponent(alpha).cgColor)
}
func noShadow() { ctx.setShadow(offset: .zero, blur: 0, color: nil) }

// MARK: colours

let skyTop = c(0x5C88C6), skyBottom = c(0x2D5592)          // steel blue background
let lacquer = [c(0xFFD866), c(0xF4BE2E), c(0xD99A12)]      // the three visible faces of the pencil, lit from above
let wood = c(0xF1D3A2), woodDark = c(0xD9AE72)             // sharpened wood
let graphite = c(0x34363C), graphiteLight = c(0x5A5D66)    // lead and the lines it wrote
let eraser = c(0xF0A3A0), eraserDark = c(0xD9807E)
let ink = c(0x2B2F3A, 0.78)                                // lines on the document icon
let cursorColor = c(0xE8702E)                              // insertion point
let chrome = NSGradient(colors: [c(0xF6F6F8), c(0xA8A8B0), c(0xE4E4EA), c(0x74747C)],
                        atLocations: [0, 0.35, 0.6, 1], colorSpace: .sRGB)!

// MARK: parts

/// Squircle background on the macOS icon grid, steel blue.
func background() {
    let path = rr(NSRect(x: 100, y: 100, width: 824, height: 824), 185)
    NSGradient(starting: skyTop, ending: skyBottom)!.draw(in: path, angle: -90)
    ctx.saveGState(); path.addClip()
    NSGradient(starting: NSColor.white.withAlphaComponent(0.16), ending: NSColor.white.withAlphaComponent(0))!
        .draw(in: NSRect(x: 100, y: 600, width: 824, height: 324), angle: -90)
    ctx.restoreGState()
}

/// Typed lines: bars of different lengths at equal distances.
func typedLines(in r: NSRect, widths: [CGFloat], height: CGFloat, gap: CGFloat) {
    ink.setFill()
    for (i, w) in widths.enumerated() {
        rr(NSRect(x: r.minX, y: r.maxY - CGFloat(i) * gap - height, width: r.width * w, height: height), height / 2).fill()
    }
}

/// A sharpened pencil lying along the x axis, the point at the origin, the eraser to the right,
/// `length` long from the point to the end of the eraser.
/// The y axis runs across it; the upper face catches the light.
func pencil(length: CGFloat = 790) {
    let half: CGFloat = 62                    // half the width
    let face = half * 2 / 3                   // width of one of the three visible faces
    let paint: CGFloat = 190                  // where the lacquer starts
    let end = length, rubber = length - 78, ferrule = length - 170

    // The whole outline first, for the shadow on the background.
    let outline = NSBezierPath()
    outline.move(to: .zero)
    outline.line(to: NSPoint(x: paint - 24, y: half)); outline.line(to: NSPoint(x: end - 26, y: half))
    outline.curve(to: NSPoint(x: end - 26, y: -half), controlPoint1: NSPoint(x: end + 8, y: half), controlPoint2: NSPoint(x: end + 8, y: -half))
    outline.line(to: NSPoint(x: paint - 24, y: -half)); outline.close()
    shadow(26, -18, 0.42); c(0x000000, 0.5).setFill(); outline.fill(); noShadow()

    // Sharpened wood, darker on the shaded side
    let cone = NSBezierPath()
    cone.move(to: .zero); cone.line(to: NSPoint(x: paint - 24, y: half)); cone.line(to: NSPoint(x: paint + 20, y: half))
    cone.line(to: NSPoint(x: paint + 20, y: -half)); cone.line(to: NSPoint(x: paint - 24, y: -half)); cone.close()
    NSGradient(starting: wood, ending: woodDark)!.draw(in: cone, angle: -90)
    // Lead at the point
    let lead: CGFloat = 62
    let tip = NSBezierPath()
    tip.move(to: NSPoint(x: -4, y: 0))
    tip.line(to: NSPoint(x: lead, y: half * lead / (paint - 24)))
    tip.curve(to: NSPoint(x: lead, y: -half * lead / (paint - 24)), controlPoint1: NSPoint(x: lead - 8, y: 6), controlPoint2: NSPoint(x: lead - 8, y: -6))
    tip.close()
    NSGradient(starting: graphiteLight, ending: graphite)!.draw(in: tip, angle: -90)

    // Lacquered body: three faces, each ending in a curve where the knife cut the paint.
    for i in 0..<3 {
        let top = half - CGFloat(i) * face, bottom = top - face
        let body = NSBezierPath()
        body.move(to: NSPoint(x: paint - 24, y: top))
        body.line(to: NSPoint(x: ferrule, y: top)); body.line(to: NSPoint(x: ferrule, y: bottom))
        body.line(to: NSPoint(x: paint - 24, y: bottom))
        body.curve(to: NSPoint(x: paint - 24, y: top), controlPoint1: NSPoint(x: paint + 14, y: bottom + face * 0.2),
                   controlPoint2: NSPoint(x: paint + 14, y: top - face * 0.2))
        body.close()
        let colour = lacquer[i]
        NSGradient(starting: colour.blended(withFraction: 0.12, of: .white)!, ending: colour)!.draw(in: body, angle: -90)
    }
    // Fine edges between the faces
    c(0x000000, 0.10).setFill()
    for i in 1..<3 {
        let y = half - CGFloat(i) * face
        NSBezierPath(rect: NSRect(x: paint - 6, y: y - 1.5, width: ferrule - paint + 6, height: 3)).fill()
    }

    // Metal ferrule with grooves
    let band = NSBezierPath(rect: NSRect(x: ferrule, y: -half - 3, width: rubber - ferrule, height: 2 * half + 6))
    chrome.draw(in: band, angle: -90)
    c(0x000000, 0.22).setFill()
    for x in stride(from: ferrule + 16, to: rubber - 10, by: 22) {
        NSBezierPath(rect: NSRect(x: x, y: -half - 3, width: 5, height: 2 * half + 6)).fill()
    }
    // Eraser
    let rub = NSBezierPath()
    rub.move(to: NSPoint(x: rubber, y: half)); rub.line(to: NSPoint(x: end - 26, y: half))
    rub.curve(to: NSPoint(x: end - 26, y: -half), controlPoint1: NSPoint(x: end + 8, y: half), controlPoint2: NSPoint(x: end + 8, y: -half))
    rub.line(to: NSPoint(x: rubber, y: -half)); rub.close()
    NSGradient(starting: eraser.blended(withFraction: 0.15, of: .white)!, ending: eraserDark)!.draw(in: rub, angle: -90)
}

/// Lines written in graphite, the last one shorter; returns the middle of the last line's end.
@discardableResult
func writtenLines(in r: NSRect, widths: [CGFloat], height: CGFloat, gap: CGFloat) -> NSPoint {
    graphite.withAlphaComponent(0.88).setFill()
    var end = NSPoint.zero
    for (i, w) in widths.enumerated() {
        let y = r.maxY - CGFloat(i) * gap - height
        rr(NSRect(x: r.minX, y: y, width: r.width * w, height: height), height / 2).fill()
        end = NSPoint(x: r.minX + r.width * w, y: y + height / 2)
    }
    return end
}

/// A white sheet with a folded corner, as on the document icon, in a light steel blue.
func sheet(_ r: NSRect, fold: CGFloat) {
    let page = NSBezierPath()
    page.move(to: NSPoint(x: r.minX, y: r.minY)); page.line(to: NSPoint(x: r.maxX, y: r.minY))
    page.line(to: NSPoint(x: r.maxX, y: r.maxY - fold)); page.line(to: NSPoint(x: r.maxX - fold, y: r.maxY))
    page.line(to: NSPoint(x: r.minX, y: r.maxY)); page.close()
    shadow(30, -14, 0.30); NSColor.white.setFill(); page.fill(); noShadow()
    let corner = NSBezierPath()
    corner.move(to: NSPoint(x: r.maxX - fold, y: r.maxY)); corner.line(to: NSPoint(x: r.maxX - fold, y: r.maxY - fold))
    corner.line(to: NSPoint(x: r.maxX, y: r.maxY - fold)); corner.close()
    shadow(10, -4, 0.2); c(0xC9D6EA).setFill(); corner.fill(); noShadow()
}

// MARK: icons

/// The app icon: a page with written lines on the steel blue squircle, and the pencil that is
/// writing its last line, coming in from the lower right.
func drawIcon() {
    background()
    let r = NSRect(x: 262, y: 170, width: 470, height: 660)
    sheet(r, fold: 128)
    let end = writtenLines(in: NSRect(x: r.minX + 56, y: r.minY + 60, width: r.width - 112, height: r.height - 150),
                           widths: [0.6, 0.94, 0.86, 0.92, 0.72, 0.9, 0.3], height: 24, gap: 62)
    ctx.saveGState()
    // A short, thick pencil, so that it carries the icon even at small sizes.
    drawingScale = 0.95
    ctx.translateBy(x: end.x + 6, y: end.y - 4)
    ctx.rotate(by: .pi * 0.29)
    ctx.scaleBy(x: drawingScale, y: drawingScale)
    pencil(length: 640)
    ctx.restoreGState()
    drawingScale = 1
}

/// The document icon: a page with a folded steel blue corner, filled with typed lines and the
/// orange insertion point, as the page of Leser's document icon is filled with text.
func drawDocumentIcon() {
    let r = NSRect(x: 142, y: 40, width: 740, height: 950)
    let fold = r.width * 0.27
    let page = NSBezierPath()
    page.move(to: NSPoint(x: r.minX, y: r.minY)); page.line(to: NSPoint(x: r.maxX, y: r.minY))
    page.line(to: NSPoint(x: r.maxX, y: r.maxY - fold)); page.line(to: NSPoint(x: r.maxX - fold, y: r.maxY))
    page.line(to: NSPoint(x: r.minX, y: r.maxY)); page.close()
    shadow(34, -14, 0.34); NSColor.white.setFill(); page.fill(); noShadow()

    let margin = r.width * 0.12
    // The text starts at the top margin, as on Leser's page; the lines beside the folded corner
    // stay short of it.
    let text = NSRect(x: r.minX + margin, y: r.minY + margin * 1.2, width: r.width - 2 * margin, height: r.height - margin * 2.2)
    let widths: [CGFloat] = [0.72, 0.5, 0.95, 0.88, 0.92, 0.7, 0.9, 0.84, 0.93, 0.8, 0.35]
    typedLines(in: text, widths: widths, height: 34, gap: 72)
    cursorColor.setFill()
    let last = CGFloat(widths.count - 1)
    NSBezierPath(rect: NSRect(x: text.minX + text.width * 0.35 + 16, y: text.maxY - last * 72 - 34 - 10, width: 16, height: 54)).fill()

    let corner = NSBezierPath()
    corner.move(to: NSPoint(x: r.maxX - fold, y: r.maxY)); corner.line(to: NSPoint(x: r.maxX - fold, y: r.maxY - fold))
    corner.line(to: NSPoint(x: r.maxX, y: r.maxY - fold)); corner.close()
    shadow(12, -5, 0.22); skyBottom.setFill(); corner.fill(); noShadow()
}

// MARK: output

let out = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func png(_ px: Int, _ draw: () -> Void = drawIcon) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    outputScale = CGFloat(px) / 1024
    ctx.scaleBy(x: outputScale, y: outputScale)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [String] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try! png(size * scale).write(to: out.appendingPathComponent(name))
        images.append("""
            { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(size)x\(size)" }
        """)
    }
}

// Document icon as .icns next to the app icon
let docSet = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DocumentIcon.iconset")
try? FileManager.default.removeItem(at: docSet)
try! FileManager.default.createDirectory(at: docSet, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! png(size, drawDocumentIcon).write(to: docSet.appendingPathComponent("icon_\(size)x\(size).png"))
    try! png(size * 2, drawDocumentIcon).write(to: docSet.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", docSet.path, "-o", "Resources/TextDocument.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: docSet)

let contents = """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

"""
try! contents.write(to: out.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
let catalog = URL(fileURLWithPath: "Resources/Assets.xcassets/Contents.json")
if !FileManager.default.fileExists(atPath: catalog.path) {
    try! "{\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n".write(to: catalog, atomically: true, encoding: .utf8)
}
