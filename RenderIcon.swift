#!/usr/bin/env swift
// Renders the SF Symbol 'cube.box.fill' to PNG files for the app icon.
// Run with: swift RenderIcon.swift

import AppKit

let size = 1024
let symbolSize: CGFloat = 520
let bgColor = NSColor(red: 0.12, green: 0.47, blue: 0.86, alpha: 1.0)

// Create master image
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// Blue background
bgColor.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// Render SF Symbol
let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
if let symbol = NSImage(systemSymbolName: "cube.box.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let symbolBounds = NSRect(
        x: CGFloat(size) / 2 - symbol.size.width / 2,
        y: CGFloat(size) / 2 - symbol.size.height / 2,
        width: symbol.size.width,
        height: symbol.size.height
    )
    NSColor.white.setFill()
    symbol.draw(in: symbolBounds, from: .zero, operation: .sourceOver, fraction: 1.0)
    // Tint white by drawing again with compositing
    let tintImg = NSImage(size: NSSize(width: size, height: size))
    tintImg.lockFocus()
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    symbol.draw(in: symbolBounds, from: .zero, operation: .destinationIn, fraction: 1.0)
    tintImg.unlockFocus()
    tintImg.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                 from: .zero, operation: .sourceOver, fraction: 1.0)
}

img.unlockFocus()

// Save as PNG
guard let tiff = img.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG")
    exit(1)
}

let outDir = "Collect/Resources/Assets.xcassets/AppIcon.appiconset"
let logoDir = "Collect/Resources/Assets.xcassets/AppLogo.imageset"

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
try? fm.createDirectory(atPath: logoDir, withIntermediateDirectories: true)

let masterPath = "\(outDir)/Icon-1024.png"
try! png.write(to: URL(fileURLWithPath: masterPath))
print("✓ Master → \(masterPath)")

// Copy to AppLogo
try! png.write(to: URL(fileURLWithPath: "\(logoDir)/AppLogo.png"))
print("✓ AppLogo synced")

// Resize for all required sizes
let sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180]
for s in sizes {
    let resized = NSImage(size: NSSize(width: s, height: s))
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    img.draw(in: NSRect(x: 0, y: 0, width: s, height: s),
             from: .zero, operation: .copy, fraction: 1.0)
    resized.unlockFocus()

    if let t = resized.tiffRepresentation,
       let b = NSBitmapImageRep(data: t),
       let p = b.representation(using: .png, properties: [:]) {
        try! p.write(to: URL(fileURLWithPath: "\(outDir)/Icon-\(s).png"))
        print("  \(s)×\(s)")
    }
}

print("\n✓ Done")
