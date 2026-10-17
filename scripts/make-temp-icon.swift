// M0 的临时 App 图标：纸底墨字「倾」+ 一条青线（亮色）；透明底浅字（深色，系统会垫上深色底）。
// 正式图标在 M1 用 Icon Composer 出三个方案（docs/ios/设计规范/04-图标与图形.md 第 4 节）。
// 用法：swift ios/scripts/make-temp-icon.swift <输出目录>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size = 1024.0

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func render(background: NSColor?, ink: NSColor, qing: NSColor, to name: String) throws {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
            bitsPerPixel: 0)
    else { throw CocoaError(.fileWriteUnknown) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    if let background {
        background.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
    }
    let font = NSFont(name: "Songti SC", size: 520) ?? NSFont.systemFont(ofSize: 520)
    let glyph = NSAttributedString(string: "倾", attributes: [.font: font, .foregroundColor: ink])
    let bounds = glyph.size()
    glyph.draw(at: NSPoint(x: (size - bounds.width) / 2, y: (size - bounds.height) / 2 + 80))
    qing.setFill()
    NSBezierPath(roundedRect: NSRect(x: size / 2 - 150, y: 190, width: 300, height: 22), xRadius: 11, yRadius: 11)
        .fill()
    NSGraphicsContext.restoreGraphicsState()
    // 有底色的（亮色）图标不能带透明通道，App Store 会拒；画完再拍平成不透明的
    var output = rep
    if background != nil, let cgImage = rep.cgImage,
        let context = CGContext(
            data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    {
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        if let flat = context.makeImage() { output = NSBitmapImageRep(cgImage: flat) }
    }
    guard let png = output.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}

try render(background: color(0xF6F4F0), ink: color(0x161513), qing: color(0x067976), to: "icon-light.png")
try render(background: nil, ink: color(0xF6F4F0), qing: color(0x7FCAC7), to: "icon-dark.png")
print("图标已生成：\(outDir)")
