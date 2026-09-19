import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let S = 1024.0
let cs = CGColorSpaceCreateDeviceRGB()
let brass = CGColor(red: 0.91, green: 0.66, blue: 0.26, alpha: 1)
let brassLight = CGColor(red: 0.98, green: 0.82, blue: 0.52, alpha: 1)
let bone = CGColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1)
let ink = CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)

func context() -> CGContext {
    CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
              space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func background(_ ctx: CGContext, radial: Bool = false) {
    let colors = [CGColor(red: 0.11, green: 0.11, blue: 0.125, alpha: 1),
                  CGColor(red: 0.035, green: 0.035, blue: 0.042, alpha: 1)] as CFArray
    let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
    if radial {
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: S/2, y: S*0.6), startRadius: 0,
                               endCenter: CGPoint(x: S/2, y: S/2), endRadius: S*0.75, options: [])
    } else {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
    }
    srand48(7)
    for _ in 0..<9000 {
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.02 + drand48() * 0.06))
        ctx.fill(CGRect(x: drand48() * S, y: drand48() * S, width: 2.5, height: 2.5))
    }
}

func text(_ ctx: CGContext, _ str: String, size: CGFloat, weight: String, color: CGColor, center: CGPoint, kern: CGFloat = 0) {
    let w: CGFloat = ["Black": 0.62, "Heavy": 0.56, "Bold": 0.4, "Semibold": 0.3][weight] ?? 0.4
    let desc = CTFontDescriptorCreateWithAttributes([
        kCTFontFamilyNameAttribute: ".AppleSystemUIFont",
        kCTFontTraitsAttribute: [kCTFontWeightTrait: w]
    ] as CFDictionary)
    let font = CTFontCreateWithFontDescriptor(desc, size, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: color,
        kCTKernAttributeName as NSAttributedString.Key: kern
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: str, attributes: attrs))
    ctx.textPosition = .zero   // image bounds are relative to the current text position
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
    CTLineDraw(line, ctx)
}

func crescent(_ ctx: CGContext, center: CGPoint, r: CGFloat, color: CGColor, cut: CGPoint, cutR: CGFloat) {
    ctx.saveGState()
    let clip = CGMutablePath()
    clip.addRect(CGRect(x: 0, y: 0, width: S, height: S))
    clip.addEllipse(in: CGRect(x: cut.x - cutR, y: cut.y - cutR, width: cutR*2, height: cutR*2))
    ctx.addPath(clip); ctx.clip(using: .evenOdd)
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2))
    ctx.restoreGState()
}

func padlock(_ ctx: CGContext, cx: CGFloat, baseY: CGFloat, scale: CGFloat, body: CGColor, shackle: CGColor, keyhole: CGColor) {
    ctx.setStrokeColor(shackle); ctx.setLineWidth(44 * scale); ctx.setLineCap(.round)
    let sh = CGMutablePath()
    sh.addArc(center: CGPoint(x: cx, y: baseY + 170*scale), radius: 82*scale, startAngle: .pi, endAngle: 0, clockwise: true)
    ctx.addPath(sh); ctx.strokePath()
    for dx in [-82.0, 82.0] {
        ctx.move(to: CGPoint(x: cx + dx*scale, y: baseY + 170*scale)); ctx.addLine(to: CGPoint(x: cx + dx*scale, y: baseY + 120*scale)); ctx.strokePath()
    }
    ctx.setFillColor(body)
    ctx.addPath(CGPath(roundedRect: CGRect(x: cx - 150*scale, y: baseY - 60*scale, width: 300*scale, height: 200*scale),
                       cornerWidth: 36*scale, cornerHeight: 36*scale, transform: nil)); ctx.fillPath()
    ctx.setFillColor(keyhole)
    ctx.fillEllipse(in: CGRect(x: cx - 30*scale, y: baseY + 30*scale, width: 60*scale, height: 60*scale))
    ctx.fill(CGRect(x: cx - 14*scale, y: baseY - 20*scale, width: 28*scale, height: 60*scale))
}

func ticks(_ ctx: CGContext, center: CGPoint, r: CGFloat, count: Int = 60, color: CGColor) {
    for i in 0..<count {
        let a = Double(i) / Double(count) * 2 * .pi
        let major = i % 5 == 0
        let len: CGFloat = major ? 34 : 16
        let w: CGFloat = major ? 6 : 3.5
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: a)
        ctx.setFillColor(major ? color : color.copy(alpha: 0.45)!)
        ctx.fill(CGRect(x: -w/2, y: r - len, width: w, height: len))
        ctx.restoreGState()
    }
}

func save(_ ctx: CGContext, _ name: String) {
    let url = URL(fileURLWithPath: "Design/icons/\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
}


let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "midnight"

func keyhole(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, r: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r*2, height: r*2))
    ctx.fill(CGRect(x: cx - r*0.48, y: cy - r*2.6, width: r*0.96, height: r*2.2))
}

func sheet(_ names: [String], out: String) {
    let cell = 480.0, pad = 40.0, labelH = 70.0
    let cols = Double(min(4, names.count)), rows = Double((names.count + 3) / 4)
    let W = cols * (cell + pad) + pad, H = rows * (cell + pad + labelH) + pad
    let sh = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    sh.setFillColor(CGColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)); sh.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (i, n) in names.enumerated() {
        let col = Double(i % 4), row = Double(i / 4)
        let x = pad + col * (cell + pad)
        let y = H - pad - (row + 1) * (cell + pad + labelH) + pad + labelH
        let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: "Design/icons/\(n).png") as CFURL, nil)!
        let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
        sh.saveGState()
        sh.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: cell, height: cell), cornerWidth: 108, cornerHeight: 108, transform: nil)); sh.clip()
        sh.draw(img, in: CGRect(x: x, y: y, width: cell, height: cell))
        sh.restoreGState()
        text(sh, String(n.dropFirst(3)).replacingOccurrences(of: "-", with: " ").uppercased(), size: 26, weight: "Semibold",
             color: CGColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1), center: CGPoint(x: x + cell/2, y: y - 38), kern: 3)
    }
    let url = URL(fileURLWithPath: "Design/icons/\(out).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, sh.makeImage()!, nil); CGImageDestinationFinalize(dest)
}

if mode == "am" {
    var c = context()
    // 1. M monogram (chosen) for reference
    background(c)
    text(c, "M", size: 720, weight: "Black", color: brass, center: CGPoint(x: 512, y: 512), kern: -20)
    keyhole(c, cx: 512, cy: 512, r: 42, color: ink)
    save(c, "am-0-m-monogram")

    // 2. AM side by side, keyhole in the A's counter
    c = context(); background(c)
    text(c, "AM", size: 520, weight: "Black", color: brass, center: CGPoint(x: 512, y: 512), kern: -30)
    keyhole(c, cx: 322, cy: 470, r: 34, color: ink)
    save(c, "am-1-a-keyhole")

    // 3. AM side by side, keyhole through the M like the chosen mark
    c = context(); background(c)
    text(c, "AM", size: 520, weight: "Black", color: brass, center: CGPoint(x: 512, y: 512), kern: -30)
    keyhole(c, cx: 705, cy: 512, r: 34, color: ink)
    save(c, "am-2-m-keyhole")

    // 4. AM stacked: A on top in bone, M below in brass with keyhole
    c = context(); background(c)
    text(c, "A", size: 470, weight: "Black", color: bone, center: CGPoint(x: 512, y: 690), kern: -20)
    text(c, "M", size: 470, weight: "Black", color: brass, center: CGPoint(x: 512, y: 330), kern: -20)
    keyhole(c, cx: 512, cy: 330, r: 30, color: ink)
    save(c, "am-3-stacked")

    // 5. AM with a brass rule and small tick marks, keyhole between letters
    c = context(); background(c, radial: true)
    text(c, "A", size: 500, weight: "Black", color: brass, center: CGPoint(x: 330, y: 540), kern: 0)
    text(c, "M", size: 500, weight: "Black", color: brass, center: CGPoint(x: 700, y: 540), kern: 0)
    c.setFillColor(brass); c.fill(CGRect(x: 150, y: 250, width: 724, height: 12))
    text(c, "ALWAYS MOTIVATED", size: 44, weight: "Semibold", color: bone, center: CGPoint(x: 512, y: 190), kern: 10)
    save(c, "am-4-tagline")

    // 6. Bone AM on brass plate, keyhole punched in the M
    c = context(); background(c)
    c.setFillColor(brass)
    c.addPath(CGPath(roundedRect: CGRect(x: 152, y: 152, width: 720, height: 720), cornerWidth: 130, cornerHeight: 130, transform: nil)); c.fillPath()
    text(c, "AM", size: 440, weight: "Black", color: ink, center: CGPoint(x: 512, y: 512), kern: -26)
    keyhole(c, cx: 676, cy: 512, r: 30, color: brass)
    save(c, "am-5-plate")

    sheet(["am-0-m-monogram","am-1-a-keyhole","am-2-m-keyhole","am-3-stacked","am-4-tagline","am-5-plate"], out: "am-contact-sheet")
    print("done")
    exit(0)
}

// 1. Current: crescent + padlock
var c = context(); background(c)
crescent(c, center: CGPoint(x: 512, y: 592), r: 300, color: brass, cut: CGPoint(x: 662, y: 712), cutR: 270)
padlock(c, cx: 640, baseY: 210, scale: 1, body: bone, shackle: bone, keyhole: ink)
save(c, "01-crescent-lock")

// 2. Monogram M, heavy brass, keyhole cut
c = context(); background(c)
text(c, "M", size: 720, weight: "Black", color: brass, center: CGPoint(x: 512, y: 512), kern: -20)
c.setFillColor(ink)
c.fillEllipse(in: CGRect(x: 512-42, y: 470, width: 84, height: 84))
c.fill(CGRect(x: 512-20, y: 380, width: 40, height: 110))
save(c, "02-monogram-keyhole")

// 3. Padlock alone, brass, oversized, off-center
c = context(); background(c, radial: true)
padlock(c, cx: 512, baseY: 300, scale: 1.9, body: brass, shackle: brass, keyhole: ink)
save(c, "03-padlock")

// 4. Instrument ring with ticks and a thin crescent inside
c = context(); background(c, radial: true)
c.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10)); c.setLineWidth(22)
c.strokeEllipse(in: CGRect(x: 512-330, y: 512-330, width: 660, height: 660))
c.setStrokeColor(brass); c.setLineWidth(22); c.setLineCap(.butt)
let arc = CGMutablePath()
arc.addArc(center: CGPoint(x: 512, y: 512), radius: 330, startAngle: .pi/2, endAngle: .pi/2 - 2 * .pi * 0.72, clockwise: true)
c.addPath(arc); c.strokePath()
ticks(c, center: CGPoint(x: 512, y: 512), r: 275, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.6))
crescent(c, center: CGPoint(x: 512, y: 512), r: 150, color: brass, cut: CGPoint(x: 590, y: 570), cutR: 135)
save(c, "04-ring-crescent")

// 5. Midnight clock: ring, ticks, hand at 12, brass dot
c = context(); background(c, radial: true)
ticks(c, center: CGPoint(x: 512, y: 512), r: 400, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
c.setFillColor(brass)
c.addPath(CGPath(roundedRect: CGRect(x: 512-16, y: 512, width: 32, height: 330), cornerWidth: 16, cornerHeight: 16, transform: nil)); c.fillPath()
c.fillEllipse(in: CGRect(x: 512-44, y: 512-44, width: 88, height: 88))
c.setFillColor(ink); c.fillEllipse(in: CGRect(x: 512-14, y: 512-14, width: 28, height: 28))
text(c, "12", size: 150, weight: "Heavy", color: bone, center: CGPoint(x: 512, y: 220), kern: -6)
save(c, "05-midnight-clock")

// 6. Keyhole plate: brass square, black keyhole cut, moon inside the keyhole
c = context(); background(c)
c.setFillColor(brass)
c.addPath(CGPath(roundedRect: CGRect(x: 172, y: 172, width: 680, height: 680), cornerWidth: 120, cornerHeight: 120, transform: nil)); c.fillPath()
c.setFillColor(ink)
c.fillEllipse(in: CGRect(x: 512-150, y: 480, width: 300, height: 300))
let stem = CGMutablePath()
stem.move(to: CGPoint(x: 512-95, y: 560)); stem.addLine(to: CGPoint(x: 512+95, y: 560))
stem.addLine(to: CGPoint(x: 512+130, y: 290)); stem.addLine(to: CGPoint(x: 512-130, y: 290)); stem.closeSubpath()
c.addPath(stem); c.fillPath()
crescent(c, center: CGPoint(x: 512, y: 630), r: 95, color: brass, cut: CGPoint(x: 555, y: 665), cutR: 85)
save(c, "06-keyhole-plate")

// 7. Wordmark: MIDNIGHT stacked tight, brass rule
c = context(); background(c)
text(c, "MID", size: 300, weight: "Black", color: bone, center: CGPoint(x: 512, y: 640), kern: -14)
text(c, "NIGHT", size: 300, weight: "Black", color: bone, center: CGPoint(x: 512, y: 380), kern: -14)
c.setFillColor(brass); c.fill(CGRect(x: 160, y: 505, width: 704, height: 14))
save(c, "07-wordmark")

// 8. Bar lock: three brass bars (vault) with one bar as a lock shackle
c = context(); background(c, radial: true)
c.setFillColor(brass)
for y in [300.0, 480.0, 660.0] {
    c.addPath(CGPath(roundedRect: CGRect(x: 160, y: y, width: 704, height: 90), cornerWidth: 20, cornerHeight: 20, transform: nil)); c.fillPath()
}
c.setFillColor(ink)
c.fillEllipse(in: CGRect(x: 512-60, y: 495, width: 120, height: 120))
c.fill(CGRect(x: 512-24, y: 300, width: 48, height: 230))
save(c, "08-vault-bars")

// Contact sheet
let names: [String] = ["01-crescent-lock","02-monogram-keyhole","03-padlock","04-ring-crescent","05-midnight-clock","06-keyhole-plate","07-wordmark","08-vault-bars"]
sheet(names, out: "contact-sheet")
print("done")
