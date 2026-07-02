import SwiftUI
import AppKit

/// 使用者自訂的顯示名稱，與 OAuth 帳號資料分離。名稱存 UserDefaults。
@MainActor
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()

    @Published var customName: String {
        didSet { UserDefaults.standard.set(customName, forKey: Self.nameKey) }
    }

    private static let nameKey = "customName"

    private init() {
        customName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
    }

    /// 有自訂名稱就用它，否則退回帳號名稱 / email。
    func displayName(fallback: String?) -> String {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (fallback ?? "Signed in") : trimmed
    }
}
