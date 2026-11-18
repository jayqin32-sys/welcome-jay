import CoreGraphics
import Foundation

let filmDuration = 8.5
private let authoredDuration = 7.25
private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
private let white = CGColor(red: 0.97, green: 0.98, blue: 1, alpha: 1)

private let inkGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 1.00, green: 0.31, blue: 0.46, alpha: 1),
        CGColor(red: 1.00, green: 0.65, blue: 0.32, alpha: 1),
        CGColor(red: 0.64, green: 0.94, blue: 0.43, alpha: 1),
        CGColor(red: 0.28, green: 0.77, blue: 1.00, alpha: 1),
        CGColor(red: 0.66, green: 0.52, blue: 1.00, alpha: 1),
        CGColor(red: 1.00, green: 0.38, blue: 0.67, alpha: 1),
        CGColor(red: 1.00, green: 0.53, blue: 0.36, alpha: 1),
        CGColor(red: 1.00, green: 0.78, blue: 0.36, alpha: 1),
        CGColor(red: 0.40, green: 0.88, blue: 0.91, alpha: 1),
        CGColor(red: 0.79, green: 0.53, blue: 1.00, alpha: 1)
    ] as CFArray,
    locations: [0, 0.15, 0.29, 0.42, 0.49, 0.63, 0.77, 0.88, 0.94, 1]
)!
private let gradientStart: CGFloat = 8
private let gradientEnd: CGFloat = 1080

private func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
private func ease(_ value: Double) -> Double {
    let t = clamp(value)
    return t * t * (3 - 2 * t)
}

private struct InkPoint {
    let p: CGPoint
    let length: CGFloat
}

private struct PenPath {
    let points: [InkPoint]
    var length: CGFloat { points.last!.length }

    init(_ coordinates: [CGFloat]) {
        var last = CGPoint(x: coordinates[0], y: coordinates[1])
        var previous = last
        var samples = [InkPoint(p: last, length: 0)]
        var traveled: CGFloat = 0
        for offset in stride(from: 2, to: coordinates.count, by: 6) {
            let a = CGPoint(x: coordinates[offset], y: coordinates[offset + 1])
            let b = CGPoint(x: coordinates[offset + 2], y: coordinates[offset + 3])
            let c = CGPoint(x: coordinates[offset + 4], y: coordinates[offset + 5])
            let span = hypot(a.x - last.x, a.y - last.y) + hypot(b.x - a.x, b.y - a.y)
                + hypot(c.x - b.x, c.y - b.y)
            let steps = max(3, Int(ceil(span / 1.7)))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let v = 1 - t
                let point = CGPoint(
                    x: v * v * v * last.x + 3 * v * v * t * a.x + 3 * v * t * t * b.x + t * t * t * c.x,
                    y: v * v * v * last.y + 3 * v * v * t * a.y + 3 * v * t * t * b.y + t * t * t * c.y
                )
                traveled += hypot(point.x - previous.x, point.y - previous.y)
                samples.append(InkPoint(p: point, length: traveled))
                previous = point
            }
            last = c
        }
        points = samples
    }

    private func sample(at distance: CGFloat) -> InkPoint {
        if distance <= 0 { return points[0] }
        guard let index = points.firstIndex(where: { $0.length >= distance }) else { return points.last! }
        let before = points[index - 1]
        let after = points[index]
        let t = (distance - before.length) / max(0.0001, after.length - before.length)
        return InkPoint(p: CGPoint(x: before.p.x + (after.p.x - before.p.x) * t,
                                   y: before.p.y + (after.p.y - before.p.y) * t), length: distance)
    }

    func draw(_ ctx: CGContext, progress: Double, width: CGFloat, pressure: CGFloat = 0,
              color: CGColor = white, startingAt startProgress: Double = 0) {
        let end = length * clamp(progress)
        let start = length * clamp(startProgress)
        guard end > start else { return }
        var visible = [sample(at: start)]
        visible += points.lazy.drop(while: { $0.length <= start }).prefix(while: { $0.length < end })
        visible.append(sample(at: end))
        ctx.setFillColor(color)
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for index in visible.indices {
            let sample = visible[index]
            let before = visible[max(0, index - 1)].p
            let after = visible[min(visible.count - 1, index + 1)].p
            let dx = after.x - before.x, dy = after.y - before.y
            let magnitude = max(0.00001, hypot(dx, dy))
            let angle = atan2(dy, dx)
            let swell = 0.59 + 0.43 * pow(abs(sin(angle - 0.48)), 1.5)
            let endTaper = length - sample.length
            let frontTaper = startProgress > 0 ? sample.length - start : sample.length
            let taper = 0.66 + 0.34 * ease(min(frontTaper, endTaper) / 13)
            let radius = width * 0.5 * (1 - pressure + pressure * swell) * taper
            let nx = -dy / magnitude * radius, ny = dx / magnitude * radius
            left.append(CGPoint(x: sample.p.x + nx, y: sample.p.y + ny))
            right.append(CGPoint(x: sample.p.x - nx, y: sample.p.y - ny))
            if index == 0 || index == visible.count - 1 {
                ctx.fillEllipse(in: CGRect(x: sample.p.x - radius, y: sample.p.y - radius,
                                         width: 2 * radius, height: 2 * radius))
            }
        }
        ctx.beginPath()
        ctx.addLines(between: left + Array(right.reversed()))
        ctx.closePath()
        ctx.fillPath()
    }
}

private let fallbackScript: [PenPath] = [
    // W, with a rising exit flourish.
    PenPath([8,52, 27,30,54,25,53,45, 51,63,32,97,36,111, 42,130,68,101,83,76,
             90,64,95,52,97,40, 86,65,73,104,82,115, 96,132,125,89,138,59,
             146,40,149,25,141,22]),
    // elcome, in one continuous stroke.
    PenPath([126,113, 138,105,154,94,164,84, 174,73,169,66,159,71,
             145,77,135,97,141,109, 149,124,170,110,185,92,
             205,69,222,35,218,26, 213,13,197,33,189,51, 180,71,172,97,179,111,
             187,125,207,110,220,95, 225,88,229,82,237,78, 248,72,255,75,250,82,
             247,86,244,87,241,87, 230,82,219,97,221,109, 226,124,246,113,260,99,
             269,89,273,77,287,77, 303,78,302,96,293,108, 285,120,269,119,266,108,
             263,99,271,87,280,84, 286,82,294,87,299,89, 311,94,322,85,329,77,
             323,89,316,107,315,116, 324,103,335,79,347,80, 359,81,345,104,346,114,
             354,101,367,79,378,80, 391,83,375,108,382,115, 390,124,408,108,417,100,
             430,90,442,78,436,72, 430,67,417,77,411,87, 401,103,406,116,420,117,
             434,119,451,106,463,96]),
]
private let jayCoordinates: [CGFloat] = [
    465,49, 482,31,518,25,522,42, 527,62,506,100,490,119,
    481,130,464,137,457,128, 449,117,464,109,479,112,
    497,114,509,109,520,103, 537,83,556,68,568,79, 579,88,561,108,549,115,
    535,123,529,112,534,101, 539,90,552,78,567,78,
    575,77,578,81,573,87, 565,101,558,118,570,117,
    581,116,596,98,606,86, 603,100,592,112,601,117,
    612,123,631,103,643,81, 629,105,626,138,606,157,
    597,166,583,171,579,163, 576,153,594,141,616,128,
    638,115,658,103,683,100
]
private let finalLetters = jayCoordinates.enumerated().map { index, coordinate in
    index.isMultiple(of: 2) ? coordinate + 22 : coordinate
}
private struct SetupAssistantStrokes: Decodable {
    struct Curve: Decodable {
        let p0: [CGFloat], p1: [CGFloat], p2: [CGFloat], p3: [CGFloat]
    }
    let strokes: [[Curve]]
}

private let script: [PenPath] = {
    let path = "/System/Library/PrivateFrameworks/SetupAssistantSupportUI.framework/Versions/A/Resources/Welcome/en.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let source = try? JSONDecoder().decode(SetupAssistantStrokes.self, from: data),
          !source.strokes.isEmpty else { return fallbackScript }
    func localPoint(_ p: [CGFloat]) -> [CGFloat] {
        [p[0] * 0.114 + 2, 119 - p[1] * 0.139]
    }
    var welcome: [PenPath] = []
    for stroke in source.strokes {
        guard let first = stroke.first,
              stroke.allSatisfy({ [$0.p0, $0.p1, $0.p2, $0.p3].allSatisfy { $0.count >= 2 } }) else {
            return fallbackScript
        }
        var coordinates = localPoint(first.p0)
        for curve in stroke {
            coordinates += localPoint(curve.p1) + localPoint(curve.p2) + localPoint(curve.p3)
        }
        welcome.append(PenPath(coordinates))
    }
    return welcome + fallbackScript.dropFirst(2)
}()
private let entryInk = script.reduce(0) { $0 + $1.length }
private let nameCenter = CGPoint(x: 356.5, y: 91.5)
private let portalWorldX: CGFloat = 660
private let iconScale: CGFloat = 1.60
// The outline begins on the upper-left lobe so the connector enters up and to the right.
private let markOutline: [CGFloat] = [
    7,36, 9,27,15,21,24,19,
    28,10,37,5,46,6, 52,5,58,8,62,12, 72,9,81,14,86,21,
    91,28,92,35,90,42, 96,48,99,57,95,65, 92,72,86,76,80,78,
    78,88,70,95,60,96, 53,97,47,94,43,90,
    35,94,26,91,20,85, 13,79,11,71,13,63, 14,59,14,58,13,55,
    8,50,5,44,7,36
]
private let chevron = PenPath([30,35, 32,39,35,45,39,50, 35,56,32,62,30,65])
private let underscore = PenPath([55,65, 60,65,68,65,75,65])
private let cloudCenter = CGPoint(x: 51, y: 51)
private let markInWorld = markOutline.enumerated().map { index, coordinate in
    if index.isMultiple(of: 2) { return nameCenter.x + portalWorldX + (coordinate - cloudCenter.x) * iconScale }
    return nameCenter.y + (coordinate - cloudCenter.y) * iconScale
}
private let connector: [CGFloat] = [
    738,96.04,762,99,791,112,
    811,125,834,146,870,134,
    901,123.67,942.9,81.9,markInWorld[0],markInWorld[1]
]
private let nameLength = PenPath(finalLetters).length
private let markEntry = PenPath(finalLetters + connector).length
private let continuousLine = PenPath(finalLetters + connector + markInWorld.dropFirst(2))
private let penSpeed = (entryInk + continuousLine.length) / (5.62 - 0.16)

private func cloud(at center: CGPoint, scale: CGFloat) -> CGPath {
    func point(_ index: Int) -> CGPoint {
        CGPoint(x: center.x + (markOutline[index] - cloudCenter.x) * scale,
                y: center.y + (markOutline[index + 1] - cloudCenter.y) * scale)
    }
    let path = CGMutablePath()
    path.move(to: point(0))
    for index in stride(from: 2, to: markOutline.count, by: 6) {
        path.addCurve(to: point(index + 4), control1: point(index), control2: point(index + 2))
    }
    path.closeSubpath()
    return path
}

private func glow(_ ctx: CGContext, origin: CGPoint, radius: CGFloat, tint: [CGFloat]) {
    let start = CGColor(red: tint[0], green: tint[1], blue: tint[2], alpha: tint[3])
    let end = start.copy(alpha: 0)!
    let gradient = CGGradient(colorsSpace: colorSpace, colors: [start, end] as CFArray,
                              locations: [0, 1])!
    ctx.drawRadialGradient(gradient, startCenter: origin, startRadius: 0,
                           endCenter: origin, endRadius: radius, options: [])
}

func drawScene(_ ctx: CGContext, size: CGSize, time elapsed: Double, live: Bool) {
    let bounds = CGRect(origin: .zero, size: size)
    ctx.clear(bounds)
    guard elapsed < filmDuration, size.width > 0, size.height > 0 else { return }
    let time = elapsed * authoredDuration / filmDuration
    let tunnel = clamp((time - 6.15) / 1.02)
    let fade = ease((time - 6.91) / 0.24)
    let entrance = ease(time / 0.18)
    let scale = min(size.width / 1070, size.height / 400)
    let midpoint = CGPoint(x: size.width / 2, y: size.height / 2)

    if !live {
        ctx.setFillColor(CGColor(red: 0.073, green: 0.081, blue: 0.11, alpha: 1))
        ctx.fill(bounds)
    }

    ctx.saveGState()
    ctx.setAlpha((1 - fade) * (live ? entrance : 1))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(CGColor(red: 0.014, green: 0.016, blue: 0.025, alpha: 1))
    ctx.fill(bounds)
    glow(ctx, origin: CGPoint(x: size.width * 0.23, y: size.height * (0.27 + 0.12 * time / authoredDuration)),
         radius: max(size.width * 0.57, size.height * 0.8), tint: [0.16, 0.12, 0.28, 0.13])
    glow(ctx, origin: CGPoint(x: size.width * (0.83 - tunnel * 0.19), y: size.height * 0.73),
         radius: max(size.width * 0.53, size.height * 0.85), tint: [0.08, 0.16, 0.30, 0.14])
    glow(ctx, origin: CGPoint(x: size.width * 0.04, y: size.height * 0.90),
         radius: max(size.width * 0.43, size.height * 0.62), tint: [0.24, 0.13, 0.26, 0.08])

    if tunnel == 0 {
        let traveled = max(0, time - 0.16) * penSpeed
        let finalInk = traveled - entryInk
        let bridgeLength = markEntry - nameLength
        let perimeter = continuousLine.length - markEntry
        let travelPastName = max(0, finalInk - nameLength)
        let camera = portalWorldX * ease(travelPastName / (bridgeLength + perimeter * 0.60))
        let nameOpacity = 1 - ease(travelPastName / (bridgeLength * 0.70))
        let trailStart = markEntry * ease(travelPastName / (bridgeLength + perimeter * 0.70))

        ctx.saveGState()
        ctx.translateBy(x: midpoint.x - (nameCenter.x + camera) * scale,
                        y: midpoint.y - nameCenter.y * scale)
        ctx.scaleBy(x: scale, y: scale)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        if nameOpacity > 0 {
            var ink = traveled
            ctx.setAlpha(nameOpacity)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            for stroke in script {
                stroke.draw(ctx, progress: ink / stroke.length, width: 8.3, pressure: 0.20)
                ink -= stroke.length
            }
            ctx.endTransparencyLayer()
            ctx.setAlpha(1)
        }
        continuousLine.draw(ctx, progress: finalInk / continuousLine.length,
                            width: 8.3, pressure: 0.20, startingAt: trailStart / continuousLine.length)
        ctx.setBlendMode(.sourceIn)
        ctx.drawLinearGradient(inkGradient, start: CGPoint(x: gradientStart, y: 92),
                               end: CGPoint(x: gradientEnd, y: 92),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.endTransparencyLayer()
        ctx.restoreGState()

        let markCenter = CGPoint(x: midpoint.x + (portalWorldX - camera) * scale, y: midpoint.y)
        let markScale = scale * iconScale
        ctx.saveGState()
        ctx.translateBy(x: markCenter.x - cloudCenter.x * markScale,
                        y: markCenter.y - cloudCenter.y * markScale)
        ctx.scaleBy(x: markScale, y: markScale)
        let promptInk = max(0, traveled - entryInk - continuousLine.length) / iconScale
        chevron.draw(ctx, progress: promptInk / chevron.length, width: 5.3)
        underscore.draw(ctx, progress: (promptInk - chevron.length) / underscore.length, width: 5.3)
        ctx.restoreGState()
    } else {
        let center = midpoint
        let camera = exp(4.38 * pow(tunnel, 1.29))
        let rimScale = scale * iconScale * camera
        let apertureScale = rimScale * ease(tunnel / 0.40) * 0.91

        if apertureScale > 0 {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.addPath(cloud(at: center, scale: apertureScale))
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.setLineJoin(.round)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for ring in (0...4).reversed() {
            let index = Double(ring)
            let presence = ring == 0 ? 1 : ease((tunnel - 0.035 * index) / 0.19)
            let depth = exp(index * 0.37 * ease(tunnel / 0.38))
            let alpha = presence * (ring == 0 ? 0.98 : 0.23 / (0.7 + index * 0.38))
            ctx.setStrokeColor(white.copy(alpha: alpha)!)
            ctx.setLineWidth(min(44 * scale, (ring == 0 ? 5.18 : 2.0) * sqrt(camera) * scale * iconScale))
            ctx.addPath(cloud(at: center, scale: rimScale * depth))
            ctx.strokePath()
        }
        let referenceX = nameCenter.x + portalWorldX
        let worldScale = rimScale / iconScale
        ctx.setBlendMode(.sourceIn)
        ctx.drawLinearGradient(inkGradient,
                               start: CGPoint(x: center.x + (gradientStart - referenceX) * worldScale, y: center.y),
                               end: CGPoint(x: center.x + (gradientEnd - referenceX) * worldScale, y: center.y),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.endTransparencyLayer()
        ctx.saveGState()
        ctx.translateBy(x: center.x - cloudCenter.x * rimScale,
                        y: center.y - cloudCenter.y * rimScale)
        ctx.scaleBy(x: rimScale, y: rimScale)
        chevron.draw(ctx, progress: 1, width: 5.4, color: white.copy(alpha: 1 - ease(tunnel / 0.24))!)
        underscore.draw(ctx, progress: 1, width: 5.4, color: white.copy(alpha: 1 - ease(tunnel / 0.24))!)
        ctx.restoreGState()
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func drawWelcomeIcon(_ ctx: CGContext, pixelSize: Int) {
    let s = CGFloat(pixelSize) / 1024
    ctx.translateBy(x: 0, y: CGFloat(pixelSize))
    ctx.scaleBy(x: s, y: -s)

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()

    let panel = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.125, green: 0.115, blue: 0.192, alpha: 1),
        CGColor(red: 0.069, green: 0.073, blue: 0.105, alpha: 1),
        CGColor(red: 0.033, green: 0.040, blue: 0.065, alpha: 1)
    ] as CFArray, locations: [0, 0.56, 1])!
    ctx.drawLinearGradient(panel, start: CGPoint(x: 160, y: 100), end: CGPoint(x: 900, y: 930),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    glow(ctx, origin: CGPoint(x: 370, y: 360), radius: 445, tint: [0.27, 0.19, 0.40, 0.16])
    ctx.restoreGState()

    if pixelSize >= 64 {
        ctx.addPath(tilePath)
        ctx.setStrokeColor(CGColor(red: 0.69, green: 0.65, blue: 0.84, alpha: 0.21))
        ctx.setLineWidth(2.5)
        ctx.strokePath()
    }

    let artScale: CGFloat = 5.18
    let center = CGPoint(x: 512, y: 488)
    let origin = CGPoint(x: center.x - cloudCenter.x * artScale,
                         y: center.y - cloudCenter.y * artScale)
    let cloudWithTail = PenPath([
        -7,43, -2,43,3,51,7,36
    ] + Array(markOutline.dropFirst(2)))
    let spectrum = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 1.00, green: 0.38, blue: 0.52, alpha: 1),
        CGColor(red: 1.00, green: 0.73, blue: 0.42, alpha: 1),
        CGColor(red: 0.71, green: 0.94, blue: 0.53, alpha: 1),
        CGColor(red: 0.33, green: 0.83, blue: 1.00, alpha: 1),
        CGColor(red: 0.81, green: 0.54, blue: 1.00, alpha: 1)
    ] as CFArray, locations: [0, 0.24, 0.46, 0.71, 1])!

    ctx.translateBy(x: origin.x, y: origin.y)
    ctx.scaleBy(x: artScale, y: artScale)

    let smallMark = pixelSize <= 32
    let strokeWidth: CGFloat = smallMark ? 7.8 : 5.6
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    if smallMark {
        ctx.addPath(cloud(at: cloudCenter, scale: 1))
        ctx.setLineJoin(.round)
        ctx.setLineWidth(strokeWidth)
        ctx.setStrokeColor(white)
        ctx.strokePath()
    } else {
        cloudWithTail.draw(ctx, progress: 1, width: strokeWidth, pressure: 0.10)
    }
    ctx.setBlendMode(.sourceIn)
    ctx.drawLinearGradient(spectrum, start: CGPoint(x: -3, y: 28), end: CGPoint(x: 91, y: 70),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.endTransparencyLayer()
    ctx.setBlendMode(.normal)

    chevron.draw(ctx, progress: 1, width: smallMark ? 9.0 : 6.6)
    underscore.draw(ctx, progress: 1, width: smallMark ? 9.0 : 6.6)
}
