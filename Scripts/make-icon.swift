// make-icon.swift
// Draws the app icon and writes Resources/AppIcon.icns.
//
// The artwork is the one already in the popover header: a blue-to-purple
// squircle carrying the same SF Symbol the menu bar uses, so the Finder icon,
// the header and the status item are visibly the same app.
//
//   swift Scripts/make-icon.swift
import AppKit

let glyphName = "hand.draw.fill"
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("dist/AppIcon.iconset")
let output = root.appendingPathComponent("Resources/AppIcon.icns")

/// Big Sur icon geometry: the tile sits inside the canvas rather than filling
/// it, with the continuous corner radius Apple uses for app icons.
func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let scale = size / 1024
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = 100 * scale
    let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237)

    // A little shadow lifts the tile off a light Finder background.
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 24 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(srgbRed: 0.31, green: 0.51, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.60, green: 0.31, blue: 0.90, alpha: 1)
    ])?.draw(in: shape, angle: -55)

    let configuration = NSImage.SymbolConfiguration(pointSize: 560 * scale, weight: .semibold)
    if let glyph = NSImage(systemSymbolName: glyphName, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) {
        let tinted = NSImage(size: glyph.size, flipped: false) { rect in
            NSColor.white.set()
            rect.fill(using: .sourceOver)
            glyph.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        let box = NSRect(
            x: (size - tinted.size.width) / 2,
            y: (size - tinted.size.height) / 2,
            width: tinted.size.width,
            height: tinted.size.height
        )
        tinted.draw(in: box)
    } else {
        FileHandle.standardError.write(Data("Symbol \(glyphName) unavailable\n".utf8))
        exit(1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// The set iconutil expects: every size at 1x and 2x.
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let data = drawIcon(size: CGFloat(pixels)).representation(using: .png, properties: [:])!
        try data.write(to: iconset.appendingPathComponent(name))
    }
}

try? FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let convert = Process()
convert.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
convert.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try convert.run()
convert.waitUntilExit()
guard convert.terminationStatus == 0 else { exit(convert.terminationStatus) }
try? FileManager.default.removeItem(at: iconset)
print("Wrote \(output.path)")
