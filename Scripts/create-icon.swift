import AppKit
import Foundation

guard let destinationPath = CommandLine.arguments.dropFirst().first else {
    fatalError("Usage: create-icon.swift <iconset directory>")
}
let destination = URL(fileURLWithPath: destinationPath)

let sizes = [16, 32, 128, 256, 512, 1024]
let fileManager = FileManager.default
try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let scale = CGFloat(size) / 1024
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.25, alpha: 1).setFill()
    NSBezierPath(roundedRect: bounds.insetBy(dx: 28 * scale, dy: 28 * scale), xRadius: 220 * scale, yRadius: 220 * scale).fill()

    let keyboard = NSRect(x: 126 * scale, y: 264 * scale, width: 772 * scale, height: 500 * scale)
    NSColor(calibratedRed: 0.25, green: 0.43, blue: 0.94, alpha: 1).setFill()
    NSBezierPath(roundedRect: keyboard, xRadius: 96 * scale, yRadius: 96 * scale).fill()

    let keyWidth = 104 * scale
    let keyHeight = 82 * scale
    let gap = 28 * scale
    let startX = 184 * scale
    let rows: [(CGFloat, Int)] = [(574, 5), (464, 5)]
    for (y, count) in rows {
        for column in 0..<count {
            let rect = NSRect(
                x: startX + CGFloat(column) * (keyWidth + gap),
                y: y * scale,
                width: keyWidth,
                height: keyHeight
            )
            NSColor(calibratedWhite: 1, alpha: 0.9).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 20 * scale, yRadius: 20 * scale).fill()
        }
    }

    let shiftKey = NSRect(x: 184 * scale, y: 354 * scale, width: 656 * scale, height: keyHeight)
    NSColor(calibratedWhite: 1, alpha: 0.9).setFill()
    NSBezierPath(roundedRect: shiftKey, xRadius: 20 * scale, yRadius: 20 * scale).fill()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 512 * scale, y: 414 * scale))
    arrow.line(to: NSPoint(x: 430 * scale, y: 342 * scale))
    arrow.line(to: NSPoint(x: 466 * scale, y: 342 * scale))
    arrow.line(to: NSPoint(x: 466 * scale, y: 314 * scale))
    arrow.line(to: NSPoint(x: 558 * scale, y: 314 * scale))
    arrow.line(to: NSPoint(x: 558 * scale, y: 342 * scale))
    arrow.line(to: NSPoint(x: 594 * scale, y: 342 * scale))
    arrow.close()
    NSColor(calibratedRed: 0.25, green: 0.43, blue: 0.94, alpha: 1).setFill()
    arrow.fill()

    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return bitmap.representation(using: .png, properties: [:])!
}

for size in sizes {
    let data = drawIcon(size: size)
    let name: String
    switch size {
    case 16:
        name = "icon_16x16.png"
    case 32:
        name = "icon_16x16@2x.png"
    case 128:
        name = "icon_128x128.png"
    case 256:
        name = "icon_128x128@2x.png"
    case 512:
        name = "icon_512x512.png"
    default:
        name = "icon_512x512@2x.png"
    }
    try data.write(to: destination.appendingPathComponent(name))
}
