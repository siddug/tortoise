import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: generate-icon.swift <iconset-dir>\n", stderr)
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconVariants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, side) in iconVariants {
    let image = makeIconImage(side: side)
    let destination = iconsetURL.appendingPathComponent(filename)
    try pngData(for: image).write(to: destination)
}

func makeIconImage(side: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: image.size)
    NSColor(calibratedRed: 0.92, green: 0.94, blue: 0.87, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: side * 0.22, yRadius: side * 0.22).fill()

    let border = NSBezierPath(
        roundedRect: rect.insetBy(dx: side * 0.02, dy: side * 0.02),
        xRadius: side * 0.2,
        yRadius: side * 0.2
    )
    border.lineWidth = max(1, side * 0.025)
    NSColor(calibratedRed: 0.34, green: 0.37, blue: 0.28, alpha: 1).setStroke()
    border.stroke()

    drawTortoise(in: NSRect(x: side * 0.13, y: side * 0.22, width: side * 0.74, height: side * 0.56))

    image.unlockFocus()
    return image
}

func drawTortoise(in rect: NSRect) {
    let shell = NSBezierPath(
        roundedRect: NSRect(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.3, width: rect.width * 0.46, height: rect.height * 0.4),
        xRadius: rect.height * 0.18,
        yRadius: rect.height * 0.18
    )
    NSColor(calibratedRed: 0.29, green: 0.43, blue: 0.24, alpha: 1).setFill()
    shell.fill()

    let shellPattern = NSBezierPath()
    shellPattern.lineWidth = max(2, rect.width * 0.045)
    shellPattern.lineCapStyle = .round
    NSColor(calibratedRed: 0.84, green: 0.9, blue: 0.75, alpha: 0.65).setStroke()
    shellPattern.move(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.48))
    shellPattern.line(to: CGPoint(x: rect.minX + rect.width * 0.46, y: rect.minY + rect.height * 0.48))
    shellPattern.move(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.37))
    shellPattern.line(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.59))
    shellPattern.stroke()

    let head = NSBezierPath(ovalIn: NSRect(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.4, width: rect.width * 0.16, height: rect.height * 0.17))
    NSColor(calibratedRed: 0.42, green: 0.57, blue: 0.31, alpha: 1).setFill()
    head.fill()

    let eye = NSBezierPath(ovalIn: NSRect(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.49, width: rect.width * 0.022, height: rect.width * 0.022))
    NSColor.white.setFill()
    eye.fill()

    let pupil = NSBezierPath(ovalIn: NSRect(x: rect.minX + rect.width * 0.665, y: rect.minY + rect.height * 0.492, width: rect.width * 0.012, height: rect.width * 0.012))
    NSColor.black.setFill()
    pupil.fill()

    let tail = NSBezierPath()
    tail.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.5))
    tail.line(to: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.minY + rect.height * 0.56))
    tail.line(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.45))
    tail.close()
    NSColor(calibratedRed: 0.42, green: 0.57, blue: 0.31, alpha: 1).setFill()
    tail.fill()

    let legs = NSBezierPath()
    legs.lineWidth = max(3, rect.width * 0.06)
    legs.lineCapStyle = .round
    NSColor(calibratedRed: 0.42, green: 0.57, blue: 0.31, alpha: 1).setStroke()
    legs.move(to: CGPoint(x: rect.minX + rect.width * 0.23, y: rect.minY + rect.height * 0.28))
    legs.line(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.08))
    legs.move(to: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.28))
    legs.line(to: CGPoint(x: rect.minX + rect.width * 0.45, y: rect.minY + rect.height * 0.08))
    legs.move(to: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.3))
    legs.line(to: CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.1))
    legs.move(to: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.31))
    legs.line(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.13))
    legs.stroke()
}

func pngData(for image: NSImage) throws -> Data {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "TortoiseIcon", code: 1)
    }

    return png
}
