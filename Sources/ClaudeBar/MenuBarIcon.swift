import AppKit

/// 把 5h 用量畫成 menu bar 的迷你長條圖（template image，自動配合深淺色）。
enum MenuBarIcon {
    private static let logoW: CGFloat = 18
    private static let barW: CGFloat = 40
    private static let barH: CGFloat = 13
    private static let gap: CGFloat = 3
    private static let radius: CGFloat = 4
    private static let height: CGFloat = 18
    private static var width: CGFloat { logoW + gap + barW + 2 }
    private static let pctFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .bold)

    /// pct5h 為 0..100。authed=false 時畫虛位空條。
    static func make(pct5h: Double, authed: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            drawClaudeLogo(in: NSRect(x: 0, y: (height - logoW) / 2, width: logoW, height: logoW))

            // 彩色 logo 不能走 template，文字/進度條用 labelColor 自動配合深淺色。
            let ink = NSColor.labelColor
            let bx = logoW + gap
            let barY = (height - barH) / 2
            // 進度條半透明，讓疊在上面的不透明 % 文字在已填/未填區都讀得到。
            let track = NSBezierPath(roundedRect: NSRect(x: bx, y: barY, width: barW, height: barH),
                                     xRadius: radius, yRadius: radius)
            ink.withAlphaComponent(0.18).setFill()
            track.fill()

            if authed {
                let fw = max(0, min(1, pct5h / 100)) * barW
                if fw > 0 {
                    ink.withAlphaComponent(0.4).setFill()
                    NSBezierPath(roundedRect: NSRect(x: bx, y: barY, width: max(fw, 2), height: barH),
                                 xRadius: radius, yRadius: radius).fill()
                }
                // % 數疊印在進度條正中央
                let s = NSAttributedString(string: String(format: "%.0f%%", pct5h),
                                           attributes: [.font: pctFont, .foregroundColor: ink])
                let sz = s.size()
                s.draw(at: NSPoint(x: bx + (barW - sz.width) / 2, y: (height - sz.height) / 2))
            } else {
                ink.withAlphaComponent(0.35).setFill()
                NSBezierPath(rect: NSRect(x: bx, y: barY + barH / 2 - 0.5, width: barW, height: 1)).fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }
}

private extension MenuBarIcon {
    /// 從 app bundle 載入的 Claude 彩色 logo（去背 PNG），快取一次。
    static let claudeLogo: NSImage? = {
        guard let url = Bundle.main.url(forResource: "claude-logo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    /// 把 Claude logo 畫在 rect 內。context 為 flipped，用 respectFlipped 保持朝上。
    static func drawClaudeLogo(in rect: NSRect) {
        claudeLogo?.draw(in: rect, from: .zero, operation: .sourceOver,
                         fraction: 1.0, respectFlipped: true, hints: nil)
    }
}

private extension NSBezierPath {
    func fill(with color: NSColor) { color.setFill(); fill() }
}
