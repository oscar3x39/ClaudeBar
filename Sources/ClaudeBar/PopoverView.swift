import SwiftUI

// MARK: - Style (ref: Blimp-Labs/claude-usage-bar demo)
private enum Style {
    static let width: CGFloat = 380
    static let pad: CGFloat = 18
    static let bg = Color(red: 0.871, green: 0.933, blue: 0.714)
    static let track = Color.black.opacity(0.08)
    static let green = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let blue = Color(red: 0.20, green: 0.55, blue: 0.90)
    static let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let purple = Color(red: 0.60, green: 0.35, blue: 0.85)
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
    @ObservedObject var updater: Updater
    @ObservedObject var appearance = AppearanceStore.shared
    let onQuit: () -> Void
    @State private var code = ""
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsPanel(svc: svc, updater: updater, appearance: appearance, onQuit: onQuit,
                              onBack: { showingSettings = false })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                mainPanel
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(Style.pad)
        .frame(width: Style.width)
        .background(Style.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.18), value: showingSettings)
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar
            if svc.isAuthed {
                UsageSection(svc: svc)
            } else {
                SignInSection(svc: svc, code: $code)
            }
            if let tag = updater.latestTag {
                updateBanner(tag)
            }
            Divider().overlay(Color.black.opacity(0.1))
            footer
        }
    }

    /// 頂部 bar：左為帳號 / 標題，右上角放齒輪設定（慣例位置）。
    private var topBar: some View {
        HStack(spacing: 9) {
            if svc.isAuthed {
                Text(appearance.displayName(fallback: svc.fullName ?? svc.email))
                    .font(.system(size: 15.6, weight: .semibold)).foregroundColor(Style.ink)
                    .lineLimit(1).truncationMode(.middle)
                if let plan = svc.plan {
                    Text(plan.uppercased())
                        .font(.system(size: 12, weight: .bold)).foregroundColor(Style.ink)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.08)))
                        .overlay(Capsule().stroke(Style.border, lineWidth: 1))
                }
            } else {
                Text("ClaudeBar")
                    .font(.system(size: 15.6, weight: .semibold)).foregroundColor(Style.ink)
            }
            Spacer(minLength: 6)
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16.8)).foregroundColor(Style.sub)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).help("Settings")
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if updater.checking {
                Text("Checking for updates…").font(.system(size: 12)).foregroundColor(Style.sub)
            } else if let note = updater.statusNote {
                Text(note).font(.system(size: 12)).foregroundColor(Style.sub).lineLimit(1)
            } else if let next = svc.nextUpdate {
                TimelineView(.periodic(from: Date(), by: 1)) { _ in
                    Text(countdown(next)).font(.system(size: 12)).foregroundColor(Style.sub)
                }
            }
            Spacer()
            if svc.isAuthed {
                iconButton("arrow.clockwise", help: "Refresh") {
                    svc.loadHistory(); Task { await svc.refreshUsage(force: true) }
                }
            }
        }
    }

    private func updateBanner(_ tag: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 15.6)).foregroundColor(Style.ink)
            VStack(alignment: .leading, spacing: 1) {
                Text("New version \(tag)").font(.system(size: 13.2, weight: .semibold)).foregroundColor(Style.ink)
                Text("Current v\(Updater.current)").font(.system(size: 10.8)).foregroundColor(Style.sub)
            }
            Spacer()
            if updater.installing {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await updater.installAndRelaunch() } } label: {
                    Text("Update").font(.system(size: 13.2, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(Style.ink))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.06)))
        .overlay(alignment: .bottomLeading) {
            if let e = updater.error {
                Text(e).font(.system(size: 10.8)).foregroundColor(.red).padding(.leading, 4).offset(y: 14)
            }
        }
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14.4, weight: .medium)).foregroundColor(Style.ink)
                .frame(width: 28, height: 28)
                .background(Circle().stroke(Style.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func countdown(_ d: Date) -> String {
        let s = Int(d.timeIntervalSinceNow.rounded())
        if s <= 0 { return "Updating…" }
        return String(format: "Next update in %d:%02d", s / 60, s % 60)
    }
}

// MARK: - Settings (面板內切換，非 dropdown)
private struct SettingsPanel: View {
    @ObservedObject var svc: UsageService
    @ObservedObject var updater: Updater
    @ObservedObject var appearance: AppearanceStore
    let onQuit: () -> Void
    let onBack: () -> Void

    private var githubURL: URL? { URL(string: "https://github.com/oscar3x39/ClaudeBar") }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16.8, weight: .semibold)).foregroundColor(Style.ink)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(0.05)))
                        .contentShape(Circle())
                }.buttonStyle(.plain).help("Back")
                Text("Settings").font(.system(size: 18, weight: .semibold)).foregroundColor(Style.ink)
                Spacer()
            }

            if svc.isAuthed {
                section("ACCOUNT") {
                    accountHeader
                    rowDivider
                    actionRow("Switch Account", icon: "arrow.left.arrow.right") {
                        svc.switchAccount(); onBack()
                    }
                    rowDivider
                    actionRow("Sign Out", icon: "rectangle.portrait.and.arrow.right", tint: .red) {
                        svc.signOut()
                    }
                }

                section("PROFILE") {
                    HStack(spacing: 10) {
                        icon("person")
                        TextField(svc.fullName ?? svc.email ?? "Display name",
                                  text: $appearance.customName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15)).foregroundColor(Style.ink)
                        if !appearance.customName.isEmpty {
                            Button { appearance.customName = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14.4)).foregroundColor(Style.sub.opacity(0.7))
                            }.buttonStyle(.plain).help("Reset name")
                        }
                    }.rowPadding()
                }
            }

            section("GENERAL") {
                HStack(spacing: 10) {
                    icon("power.circle")
                    Text("Launch at Login").font(.system(size: 15)).foregroundColor(Style.ink)
                    Spacer()
                    Toggle("", isOn: Binding(get: { svc.launchAtLogin },
                                             set: { svc.setLaunchAtLogin($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }.rowPadding()
            }

            section("ABOUT") {
                HStack(spacing: 10) {
                    icon("info.circle")
                    Text("ClaudeBar").font(.system(size: 15, weight: .medium)).foregroundColor(Style.ink)
                    Spacer()
                    Text("v\(Updater.current)").font(.system(size: 13.8)).foregroundColor(Style.sub)
                }.rowPadding()
                rowDivider
                actionRow("Check for Updates", icon: "arrow.down.circle",
                          trailing: updater.checking ? "Checking…" : updater.statusNote,
                          showChevron: false) {
                    Task { await updater.check(silent: false) }
                }
                rowDivider
                if let url = githubURL {
                    Link(destination: url) {
                        rowBody("View on GitHub", icon: "arrow.up.forward.square", showChevron: true)
                    }.buttonStyle(.plain)
                }
            }

            if let e = updater.error {
                Text(e).font(.system(size: 12)).foregroundColor(.red).lineLimit(2)
                    .padding(.horizontal, 4)
            }

            actionRow("Quit ClaudeBar", icon: "power", tint: .red, action: onQuit)
                .background(card)
        }
    }

    // MARK: rows & pieces

    private var accountHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appearance.displayName(fallback: svc.fullName ?? svc.email))
                    .font(.system(size: 15.6, weight: .semibold)).foregroundColor(Style.ink)
                    .lineLimit(1).truncationMode(.middle)
                if let email = svc.email, email != svc.fullName {
                    Text(email).font(.system(size: 12.6)).foregroundColor(Style.sub)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)
            if let plan = svc.plan {
                Text(plan.uppercased())
                    .font(.system(size: 12, weight: .bold)).foregroundColor(Style.ink)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.07)))
                    .overlay(Capsule().stroke(Style.border, lineWidth: 1))
            }
        }.rowPadding()
    }

    private func actionRow(_ title: String, icon iconName: String, tint: Color = Style.ink,
                           trailing: String? = nil, showChevron: Bool = true,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowBody(title, icon: iconName, tint: tint, trailing: trailing, showChevron: showChevron)
        }.buttonStyle(.plain)
    }

    private func rowBody(_ title: String, icon iconName: String, tint: Color = Style.ink,
                         trailing: String? = nil, showChevron: Bool = false) -> some View {
        HStack(spacing: 10) {
            icon(iconName, tint: tint)
            Text(title).font(.system(size: 15)).foregroundColor(tint)
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 12.6)).foregroundColor(Style.sub)
                    .lineLimit(1)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Style.sub.opacity(0.7))
            }
        }
        .rowPadding()
        .contentShape(Rectangle())
    }

    private func icon(_ name: String, tint: Color = Style.ink) -> some View {
        Image(systemName: name).font(.system(size: 15.6)).foregroundColor(tint)
            .frame(width: 18, alignment: .center)
    }

    private var rowDivider: some View {
        Divider().overlay(Color.black.opacity(0.06)).padding(.leading, 40)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .shadow(color: Color.black.opacity(0.07), radius: 4, y: 1)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11.4, weight: .bold)).foregroundColor(Style.sub)
                .tracking(0.6).padding(.leading, 4)
            VStack(spacing: 0) { content() }.background(card)
        }
    }
}

private extension View {
    func rowPadding() -> some View {
        padding(.horizontal, 12).frame(minHeight: 38)
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
                    .font(.system(size: 13.2)).foregroundColor(Style.sub)
                TextField("code#state", text: $code)
                    .textFieldStyle(.roundedBorder).font(.system(size: 14.4))
                HStack(spacing: 8) {
                    primary("Submit") { let c = code; code = ""; Task { await svc.submitCode(c) } }
                    secondary("Re-authorize") { code = ""; svc.startSignIn() }
                    secondary("Cancel") { code = ""; svc.cancelSignIn() }
                }
            } else {
                Text("Not signed in").font(.system(size: 14.4)).foregroundColor(Style.sub)
                primary("Sign in with Claude") { svc.startSignIn() }
            }
            if let e = svc.errorText {
                Text(e).font(.system(size: 12)).foregroundColor(.red).lineLimit(3)
            }
        }
    }

    private func primary(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 14.4, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(Style.ink))
        }.buttonStyle(.plain)
    }
    private func secondary(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 14.4)).foregroundColor(Style.ink)
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
            if let wk = svc.usage?.seven_day {
                Divider().overlay(Color.black.opacity(0.08))
                WindowRow(title: "Weekly (All)", bucket: wk, tint: Style.blue)
            }
            if let wk = svc.usage?.seven_day_opus {
                WindowRow(title: "Weekly (Opus)", bucket: wk, tint: Style.purple)
            }
            if let wk = svc.usage?.seven_day_sonnet {
                WindowRow(title: "Weekly (Sonnet)", bucket: wk, tint: Style.orange)
            }
            if !svc.daily.isEmpty {
                Divider().overlay(Color.black.opacity(0.08))
                DailyChartView(days: svc.daily)
            }
            if let today = svc.daily.last, today.tokens.total > 0 {
                Divider().overlay(Color.black.opacity(0.08))
                TokenUsageRow(today: today)
            }
            if let e = svc.errorText {
                Text(e).font(.system(size: 12)).foregroundColor(.red)
            }
        }
    }
}

/// 今日 token 用量：大數字總量 + In/Out/Cache 細分。
/// 資料同 Daily Usage，來自本機 JSONL；面板打開時才重算（見 AppDelegate.showPanel）。
private struct TokenUsageRow: View {
    let today: DayCost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Token Usage").font(.system(size: 15.6, weight: .semibold)).foregroundColor(Style.ink)
                Spacer()
                Text("Today").font(.system(size: 13.2)).foregroundColor(Style.sub)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(Self.fmt(today.tokens.total))
                    .font(.system(size: 26.4, weight: .bold)).foregroundColor(Style.ink)
                Text("tokens").font(.system(size: 13.2)).foregroundColor(Style.sub)
            }
            HStack(spacing: 14) {
                stat("In", today.tokens.input)
                stat("Out", today.tokens.output)
                stat("Cache W", today.tokens.cacheWrite)
                stat("Cache R", today.tokens.cacheRead)
            }
        }
    }

    private func stat(_ label: String, _ n: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10.8, weight: .semibold)).foregroundColor(Style.sub)
            Text(Self.fmt(n)).font(.system(size: 14.4, weight: .medium)).foregroundColor(Style.ink)
        }
    }

    /// 1_234_567 → "1.2M"、12_300 → "12.3K"。
    static func fmt(_ n: Int) -> String {
        let d = Double(n)
        if d >= 1_000_000 { return String(format: "%.1fM", d / 1_000_000) }
        if d >= 1_000 { return String(format: "%.1fK", d / 1_000) }
        return "\(n)"
    }
}

private struct WindowRow: View {
    let title: String
    let bucket: UsageBucket?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 16.8, weight: .semibold)).foregroundColor(Style.ink)
                Spacer()
                Text(bucket?.utilization == nil ? "—" : String(format: "%.0f%%", bucket!.utilization!))
                    .font(.system(size: 21.6, weight: .bold)).foregroundColor(Style.ink)
            }
            CapsuleBar(value: bucket?.fraction ?? 0, tint: tint)
            Text(resetVerbose(bucket?.resetDate)).font(.system(size: 13.2)).foregroundColor(Style.sub)
        }
    }
}
