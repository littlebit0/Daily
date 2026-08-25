import AppKit
import ImageIO
import UniformTypeIdentifiers

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
    let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("artwork/daily-app-icon-source.png")
    guard let source = NSImage(contentsOf: sourceURL) else {
        fatalError("Unable to load approved app icon artwork at \(sourceURL.path)")
    }

    let output = NSImage(size: NSSize(width: side, height: side))
    output.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(
        in: CGRect(x: 0, y: 0, width: side, height: side),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    output.unlockFocus()
    return output
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
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(path)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "DailyIconGeneration", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    color(0xFFFFFF).setFill()
    NSBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: height)).fill()
    image.draw(
        in: CGRect(x: 0, y: 0, width: width, height: height),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard
        let output = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        throw NSError(domain: "DailyIconGeneration", code: 1)
    }
    CGImageDestinationAddImage(destination, output, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "DailyIconGeneration", code: 1)
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
