// 把一页的几屏截图（「20-钱-主页-1.png」「20-钱-主页-2.png」……）按顺序竖着拼成一张长图「20-钱-主页.jpg」，
// 缩到一半宽，屏和屏之间留一道灰缝。只用系统的图像库，不用装别的。scripts/tour-shots.sh 会调用。
// 用法：swift scripts/stitch-shots.swift <每一屏的目录> <长图放哪>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("用法：swift scripts/stitch-shots.swift <每一屏的目录> <长图放哪>\n".utf8))
    exit(2)
}
let source = URL(fileURLWithPath: arguments[1])
let target = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

let scale = 0.5
let gap = 24.0

// 「名字-3.png」→（名字, 3）；没有序号的单张自成一组
var groups: [String: [(Int, URL)]] = [:]
let pattern = try NSRegularExpression(pattern: #"^(.*)-(\d+)\.png$"#)
for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
where file.pathExtension == "png" {
    let name = file.lastPathComponent
    let range = NSRange(name.startIndex..., in: name)
    if let match = pattern.firstMatch(in: name, range: range),
        let page = Range(match.range(at: 1), in: name), let number = Range(match.range(at: 2), in: name)
    {
        groups[String(name[page]), default: []].append((Int(name[number]) ?? 0, file))
    } else {
        groups[String(name.dropLast(4)), default: []].append((1, file))
    }
}

func load(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

var written = 0
for (page, files) in groups.sorted(by: { $0.key < $1.key }) {
    let images = files.sorted { $0.0 < $1.0 }.compactMap { load($0.1) }
    guard let first = images.first else { continue }
    let width = (Double(first.width) * scale).rounded()
    let heights = images.map { (Double($0.height) * Double(width) / Double($0.width)).rounded() }
    let height = heights.reduce(0, +) + gap * Double(images.count - 1)
    guard
        let context = CGContext(
            data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { continue }
    context.setFillColor(CGColor(gray: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    // CoreGraphics 的原点在左下角：第一屏画在最上面
    var top = height
    for (image, imageHeight) in zip(images, heights) {
        top -= imageHeight
        context.draw(image, in: CGRect(x: 0, y: top, width: width, height: imageHeight))
        top -= gap
    }
    guard let stitched = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            target.appendingPathComponent("\(page).jpg") as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { continue }
    CGImageDestinationAddImage(destination, stitched, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    if CGImageDestinationFinalize(destination) { written += 1 }
}
print("  长图 \(written) 张 → \(target.path)")
