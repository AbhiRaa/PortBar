// Generates AppIcon.icns for PortBar by drawing a gradient tile with the
// powerplug glyph. Run: swift scripts/make-icon.swift
import AppKit

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.225 // macOS "squircle"-ish corner
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()

    // Amber -> red diagonal gradient.
    let colors = [
        NSColor(calibratedRed: 0.96, green: 0.66, blue: 0.24, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.95, green: 0.34, blue: 0.30, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0),
                           options: [])

    // Subtle top sheen (soft gradient, no hard seam).
    let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor.white.withAlphaComponent(0.14).cgColor,
                                    NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(sheen,
                           start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: 0, y: size * 0.45),
                           options: [])

    // Plug glyph, tinted dark via a palette color (no compositing hacks).
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(white: 0.07, alpha: 0.92)]))
    if let symbol = NSImage(systemSymbolName: "powerplug.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let s = symbol.size
        let r = NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height)
        symbol.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1)
    }

    image.unlockFocus()
    return image
}

let fm = FileManager.default
let iconset = "build/AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

for (px, name) in specs {
    let img = drawIcon(size: CGFloat(px))
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}

print("wrote \(iconset)")
