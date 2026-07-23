import AppKit
import CoreGraphics

let S: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
func rgb(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat,_ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r/255, g/255, b/255, a])!
}
// 深色圓角底 + 垂直漸層(與 StockBar 一致)
let rect = CGRect(x: 0, y: 0, width: S, height: S)
let radius = S * 0.2237
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.clip()
let grad = CGGradient(colorsSpace: cs, colors: [rgb(30,41,59), rgb(15,23,33), rgb(8,12,18)] as CFArray,
                      locations: [0,0.55,1])!
ctx.drawLinearGradient(grad, start: CGPoint(x:0,y:S), end: CGPoint(x:0,y:0), options: [])

// 載入 claude-logo.png(橘色星芒)
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
      let logo = CGImageSourceCreateImageAtIndex(src, 0, nil) else { print("no logo"); exit(1) }

// 置中、縮到約 62%，加橘色柔光
let target: CGFloat = S * 0.62
let x = (S - target)/2, y = (S - target)/2
ctx.setShadow(offset: .zero, blur: 55, color: rgb(217,119,87,0.55))
ctx.draw(logo, in: CGRect(x: x, y: y, width: target, height: target))

guard let img = ctx.makeImage() else { exit(1) }
let out = URL(fileURLWithPath: CommandLine.arguments[2])
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote", out.path)
