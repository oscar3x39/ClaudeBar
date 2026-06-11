import SwiftUI

// MARK: - Style (ref: Blimp-Labs/claude-usage-bar demo)
private enum Style {
    static let width: CGFloat = 320
    static let pad: CGFloat = 18
    static let bg = Color(red: 0.871, green: 0.933, blue: 0.714)
    static let track = Color.black.opacity(0.08)
    static let green = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let ink = Color(white: 0.13)
    static let sub = Color(white: 0.40)
    static let border = Color.black.opacity(0.18)
}

private func resetVerbose(_ date: Date?, now: Date = Date()) -> String {
    guard let d = date else { return "—" }
    let secs = max(0, Int(d.timeIntervalSince(now)))
    let days = secs / 86400, h = (secs % 86400) / 3600, m = (secs % 3600) / 60
    if days > 0 { return "Resets in \(days)d \(h)h" }
    if h > 0 { return "Resets in \(h)h \(m)m" }
    return "Resets in \(m)m"
}

// MARK: - Rounded bar
private struct CapsuleBar: View {
    let value: Double
    let tint: Color
    var height: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Style.track)
                Capsule().fill(tint).frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Popover root
struct PopoverView: View {
    @ObservedObject var svc: UsageService
    let onQuit: () -> Void
    @State private var code = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let email = svc.email {
                Text(email).font(.system(size: 11)).foregroundColor(Style.sub)
            }
            if svc.isAuthed {
                UsageSection(svc: svc)
            } else {
                SignInSection(svc: svc, code: $code)
            }
            Divider().overlay(Color.black.opacity(0.1))
            footer
            launchRow
        }
        .padding(Style.pad)
        .frame(width: Style.width)
        .background(Style.bg)
        .preferredColorScheme(.light)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let u = svc.updatedAt {
                Text("Updated \(timeAgo(u))").font(.system(size: 10)).foregroundColor(Style.sub)
            }
            Spacer()
            if svc.isAuthed {
                iconButton("arrow.clockwise", help: "Refresh") {
                    svc.loadHistory(); Task { await svc.refreshUsage(force: true) }
                }
                iconButton("rectangle.portrait.and.arrow.right", help: "Sign Out") { svc.signOut() }
            }
            iconButton("power", help: "Quit", action: onQuit)
        }
    }

    private var launchRow: some View {
        HStack {
            Text("Launch at Login").font(.system(size: 11)).foregroundColor(Style.ink)
            Spacer()
            Toggle("", isOn: Binding(get: { svc.launchAtLogin }, set: { svc.setLaunchAtLogin($0) }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium)).foregroundColor(Style.ink)
                .frame(width: 28, height: 28)
                .background(Circle().stroke(Style.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func timeAgo(_ d: Date) -> String {
        let s = Int(-d.timeIntervalSinceNow)
        return s < 60 ? "\(s)s ago" : "\(s / 60)m ago"
    }
}

// MARK: - Sign in
private struct SignInSection: View {
    @ObservedObject var svc: UsageService
    @Binding var code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if svc.awaitingCode {
                Text("After authorizing in the browser, paste the code here")
                    .font(.system(size: 11)).foregroundColor(Style.sub)
                TextField("code#state", text: $code)
                    .textFieldStyle(.roundedBorder).font(.system(size: 12))
                HStack(spacing: 8) {
                    primary("Submit") { let c = code; code = ""; Task { await svc.submitCode(c) } }
                    secondary("Re-authorize") { code = ""; svc.startSignIn() }
                    secondary("Cancel") { code = ""; svc.cancelSignIn() }
                }
            } else {
                Text("Not signed in").font(.system(size: 12)).foregroundColor(Style.sub)
                primary("Sign in with Claude") { svc.startSignIn() }
            }
            if let e = svc.errorText {
                Text(e).font(.system(size: 10)).foregroundColor(.red).lineLimit(3)
            }
        }
    }

    private func primary(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(Style.ink))
        }.buttonStyle(.plain)
    }
    private func secondary(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 12)).foregroundColor(Style.ink)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().stroke(Style.border, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - Usage
private struct UsageSection: View {
    @ObservedObject var svc: UsageService

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WindowRow(title: "5-Hour Window", bucket: svc.usage?.five_hour, tint: Style.green)
            if !svc.daily.isEmpty {
                Divider().overlay(Color.black.opacity(0.08))
                DailyChartView(days: svc.daily)
            }
            if let e = svc.errorText {
                Text(e).font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }
}

private struct WindowRow: View {
    let title: String
    let bucket: UsageBucket?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Style.ink)
                Spacer()
                Text(bucket?.utilization == nil ? "—" : String(format: "%.0f%%", bucket!.utilization!))
                    .font(.system(size: 18, weight: .bold)).foregroundColor(Style.ink)
            }
            CapsuleBar(value: bucket?.fraction ?? 0, tint: tint)
            Text(resetVerbose(bucket?.resetDate)).font(.system(size: 11)).foregroundColor(Style.sub)
        }
    }
}
