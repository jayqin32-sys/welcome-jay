import AppKit

@main
struct RenderIcon {
    static func main() throws {
        for name in CommandLine.arguments.dropFirst() {
            let stem = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
            let dimensions = stem.split(separator: "_")[1].split(separator: "x")
            let width = Int(dimensions[0])! * (stem.hasSuffix("@2x") ? 2 : 1)
            let ctx = CGContext(data: nil, width: width, height: width, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            drawWelcomeIcon(ctx, pixelSize: width)
            let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
            try png.write(to: URL(fileURLWithPath: name))
        }
    }
}
