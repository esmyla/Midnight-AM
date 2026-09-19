import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Background: deep midnight gradient.
let colors = [CGColor(red: 0.11, green: 0.11, blue: 0.125, alpha: 1),
              CGColor(red: 0.035, green: 0.035, blue: 0.042, alpha: 1)] as CFArray
let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// Fine grain.
srand48(7)
for _ in 0..<9000 {
    let x = drand48() * size, y = drand48() * size
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.02 + drand48() * 0.06))
    ctx.fill(CGRect(x: x, y: y, width: 2.5, height: 2.5))
}

// Crescent moon in lavender: big circle minus an offset circle.
let lavender = CGColor(red: 0.91, green: 0.66, blue: 0.26, alpha: 1)  // brass
ctx.saveGState()
// Clip to everything except the cutout circle, then fill the moon disc.
let clip = CGMutablePath()
clip.addRect(CGRect(x: 0, y: 0, width: size, height: size))
clip.addEllipse(in: CGRect(x: 392, y: 442, width: 540, height: 540))
ctx.addPath(clip)
ctx.clip(using: .evenOdd)
ctx.setFillColor(lavender)
ctx.fillEllipse(in: CGRect(x: 212, y: 292, width: 600, height: 600))
ctx.restoreGState()

// Lock: shackle arc + rounded body, bottom-right, white.
let white = CGColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1)
ctx.setStrokeColor(white)
ctx.setFillColor(white)
ctx.setLineWidth(44)
ctx.setLineCap(.round)
let cx = 640.0, baseY = 210.0
let shackle = CGMutablePath()
shackle.addArc(center: CGPoint(x: cx, y: baseY + 170), radius: 82, startAngle: .pi, endAngle: 0, clockwise: true)
ctx.addPath(shackle); ctx.strokePath()
ctx.move(to: CGPoint(x: cx - 82, y: baseY + 170)); ctx.addLine(to: CGPoint(x: cx - 82, y: baseY + 120)); ctx.strokePath()
ctx.move(to: CGPoint(x: cx + 82, y: baseY + 170)); ctx.addLine(to: CGPoint(x: cx + 82, y: baseY + 120)); ctx.strokePath()
let body = CGPath(roundedRect: CGRect(x: cx - 150, y: baseY - 60, width: 300, height: 200), cornerWidth: 44, cornerHeight: 44, transform: nil)
ctx.addPath(body); ctx.fillPath()
// Keyhole in background color.
ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1))
ctx.fillEllipse(in: CGRect(x: cx - 30, y: baseY + 30, width: 60, height: 60))
ctx.fill(CGRect(x: cx - 14, y: baseY - 20, width: 28, height: 60))

let img = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
