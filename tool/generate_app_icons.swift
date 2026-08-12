import AppKit

struct IconTarget {
    let path: String
    let size: Int
}

struct ImageTarget {
    let path: String
    let width: Int
    let height: Int
}

let targets: [IconTarget] = [
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", size: 20),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", size: 40),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", size: 60),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", size: 29),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", size: 58),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", size: 87),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", size: 40),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", size: 80),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", size: 120),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", size: 120),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", size: 180),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", size: 76),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", size: 152),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", size: 167),
    IconTarget(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", size: 1024),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png", size: 16),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png", size: 32),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png", size: 64),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png", size: 128),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png", size: 256),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png", size: 512),
    IconTarget(path: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png", size: 1024),
    IconTarget(path: "android/app/src/main/res/mipmap-mdpi/ic_launcher.png", size: 48),
    IconTarget(path: "android/app/src/main/res/mipmap-hdpi/ic_launcher.png", size: 72),
    IconTarget(path: "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", size: 96),
    IconTarget(path: "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", size: 144),
    IconTarget(path: "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", size: 192),
]

let launchTargets: [ImageTarget] = [
    ImageTarget(path: "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png", width: 168, height: 185),
    ImageTarget(path: "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png", width: 336, height: 370),
    ImageTarget(path: "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png", width: 504, height: 555),
]

let appleOnly = CommandLine.arguments.contains("--apple-only")

func color(_ hex: UInt32) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return NSColor(red: red, green: green, blue: blue, alpha: 1)
}

func roundedPath(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(size: Int) -> NSImage {
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))

    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    let bg = NSGradient(
        starting: color(0xFFFFFF),
        ending: color(0xEEF3FA)
    )!
    bg.draw(in: NSBezierPath(rect: bounds), angle: -55)

    let inset = side * 0.13
    let card = CGRect(x: inset, y: side * 0.14, width: side - inset * 2, height: side * 0.73)
    let radius = side * 0.13

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -side * 0.018), blur: side * 0.05, color: NSColor.black.withAlphaComponent(0.14).cgColor)
    color(0xFFFFFF).setFill()
    roundedPath(card, radius).fill()
    context.restoreGState()

    color(0xE1E7F0).setStroke()
    let border = roundedPath(card.insetBy(dx: side * 0.006, dy: side * 0.006), radius)
    border.lineWidth = max(1, side * 0.006)
    border.stroke()

    let header = CGRect(x: card.minX, y: card.maxY - card.height * 0.26, width: card.width, height: card.height * 0.26)
    let headerPath = roundedPath(header, radius)
    context.saveGState()
    roundedPath(card, radius).addClip()
    let headerGradient = NSGradient(starting: color(0x2867F0), ending: color(0x4A8CFF))!
    headerGradient.draw(in: headerPath, angle: 0)
    context.restoreGState()

    color(0xEEF4FF).setFill()
    let ringY = card.maxY - card.height * 0.13
    for x in [card.minX + card.width * 0.28, card.maxX - card.width * 0.28] {
        let ring = CGRect(x: x - side * 0.027, y: ringY - side * 0.027, width: side * 0.054, height: side * 0.054)
        NSBezierPath(ovalIn: ring).fill()
    }

    let textSize = side * 0.37
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: textSize, weight: .medium),
        .foregroundColor: color(0x242936),
        .paragraphStyle: paragraph,
    ]
    let textRect = CGRect(
        x: card.minX,
        y: card.minY + card.height * 0.20,
        width: card.width,
        height: card.height * 0.42
    )
    NSString(string: "24").draw(in: textRect, withAttributes: attrs)

    let markerWidth = side * 0.085
    let markerHeight = max(1, side * 0.016)
    let marker = CGRect(
        x: card.midX - markerWidth / 2,
        y: card.minY + card.height * 0.12,
        width: markerWidth,
        height: markerHeight
    )
    color(0xFF624F).setFill()
    roundedPath(marker, markerHeight / 2).fill()

    image.unlockFocus()
    return image
}

func drawLaunchImage(width: Int, height: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: width, height: height))

    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    color(0xFFFFFF).setFill()
    NSBezierPath(rect: bounds).fill()

    let side = min(CGFloat(width), CGFloat(height)) * 0.72
    let icon = drawIcon(size: Int(side))
    let rect = CGRect(
        x: (CGFloat(width) - side) / 2,
        y: (CGFloat(height) - side) / 2,
        width: side,
        height: side
    )
    icon.draw(in: rect)

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, path: String, width: Int, height: Int) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "DailyIconGeneration", code: 1)
    }

    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(path)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = ["-z", "\(height)", "\(width)", url.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw NSError(domain: "DailyIconGeneration", code: Int(process.terminationStatus))
    }
}

for target in targets where !appleOnly || target.path.hasPrefix("ios/") || target.path.hasPrefix("macos/") {
    try writePNG(drawIcon(size: target.size), path: target.path, width: target.size, height: target.size)
    print("wrote \(target.path)")
}

for target in launchTargets {
    try writePNG(
        drawLaunchImage(width: target.width, height: target.height),
        path: target.path,
        width: target.width,
        height: target.height
    )
    print("wrote \(target.path)")
}
