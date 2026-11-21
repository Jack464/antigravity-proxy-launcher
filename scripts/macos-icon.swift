import AppKit
import Foundation

// Original project artwork, equivalent to assets/launcher.svg. No vendor artwork is bundled.
guard CommandLine.arguments.count == 2 else { fatalError("Pass the destination .iconset directory") }
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let dimensions = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (size, scale) in dimensions {
    let pixels = size * scale
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot create icon bitmap") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 256, y: CGFloat(pixels) / 256)
    let background = NSBezierPath(roundedRect: NSRect(x: 8, y: 8, width: 240, height: 240), xRadius: 52, yRadius: 52)
    let gradient = NSGradient(starting: NSColor(srgbRed: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1), ending: NSColor(srgbRed: 124 / 255, green: 58 / 255, blue: 237 / 255, alpha: 1))!
    gradient.draw(in: background, angle: -45)
    let letter = NSBezierPath()
    letter.windingRule = .evenOdd
    let points: [(CGFloat, CGFloat)] = [(56, 190), (119, 60), (145, 60), (208, 190), (173, 190), (160, 160), (102, 160), (89, 190)]
    letter.move(to: NSPoint(x: points[0].0, y: 256 - points[0].1))
    for point in points.dropFirst() { letter.line(to: NSPoint(x: point.0, y: 256 - point.1)) }
    letter.close()
    letter.move(to: NSPoint(x: 115, y: 125))
    letter.line(to: NSPoint(x: 147, y: 125))
    letter.line(to: NSPoint(x: 131, y: 164))
    letter.close()
    NSColor.white.setFill()
    letter.fill()
    let arrow = NSBezierPath()
    arrow.lineWidth = 12
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 177, y: 201)); arrow.line(to: NSPoint(x: 209, y: 201)); arrow.line(to: NSPoint(x: 209, y: 169))
    arrow.move(to: NSPoint(x: 208, y: 200)); arrow.line(to: NSPoint(x: 175, y: 167))
    NSColor.white.setStroke()
    arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
    let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
    try png.write(to: directory.appendingPathComponent(filename), options: .atomic)
}
