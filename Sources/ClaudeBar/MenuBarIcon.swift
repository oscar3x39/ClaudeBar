import AppKit

/// 把 5h 用量畫成 menu bar 的迷你長條圖（template image，自動配合深淺色）。
enum MenuBarIcon {
    private static let labelW: CGFloat = 18
    private static let barW: CGFloat = 40
    private static let barH: CGFloat = 9
    private static let gap: CGFloat = 4
    private static let radius: CGFloat = 4
    private static let height: CGFloat = 16
    private static var width: CGFloat { labelW + gap + barW + 2 }
    private static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)

    /// pct5h 為 0..100。authed=false 時畫虛位空條。
    static func make(pct5h: Double, authed: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            let y = (height - barH) / 2
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let s = NSAttributedString(string: "5h", attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: labelW - sz.width, y: y + (barH - sz.height) / 2))

            let bx = labelW + gap
            let track = NSBezierPath(roundedRect: NSRect(x: bx, y: y, width: barW, height: barH),
                                     xRadius: radius, yRadius: radius)
            NSColor.black.withAlphaComponent(0.22).setFill()
            track.fill()

            if authed {
                let fw = max(0, min(1, pct5h / 100)) * barW
                if fw > 0 {
                    NSBezierPath(roundedRect: NSRect(x: bx, y: y, width: max(fw, 2), height: barH),
                                 xRadius: radius, yRadius: radius).fill(with: .black)
                }
            } else {
                NSColor.black.withAlphaComponent(0.35).setFill()
                NSBezierPath(rect: NSRect(x: bx, y: y + barH / 2 - 0.5, width: barW, height: 1)).fill()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}

private extension NSBezierPath {
    func fill(with color: NSColor) { color.setFill(); fill() }
}
