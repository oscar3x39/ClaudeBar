import Foundation
import CoreServices

/// 監看 ~/.claude/projects 的 JSONL 寫入。
///
/// 5h 視窗的用量只有在你實際跑 Claude Code 時才會往上走,所以「檔案有動」比「時間到了」
/// 是更準也更省的刷新信號:idle 時完全不打 API,你在用時幾乎即時。
/// FSEvents 由 kernel 推送(不是輪詢),app 閒置時零成本。
///
/// 這裡刻意不自己做 debounce —— kernel 端已用 latency 合併連續寫入,
/// 下游 UsageService.refreshUsage 又有 60s 節流,再疊一層只是多一份會出錯的狀態。
final class UsageWatcher {
    private let path: String
    private let latency: CFTimeInterval
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?

    /// onChange 一律在 main queue 上呼叫。
    init(path: String = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path,
         latency: CFTimeInterval = 2,
         onChange: @escaping () -> Void) {
        self.path = path
        self.latency = latency
        self.onChange = onChange
    }

    deinit { stop() }

    func start() {
        guard stream == nil else { return }
        // 目錄不存在就不啟動(沒裝 Claude Code / 還沒跑過)——FSEvents 對不存在的路徑不會補送。
        guard FileManager.default.fileExists(atPath: path) else { return }

        var ctx = FSEventStreamContext(version: 0,
                                       info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<UsageWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
        }
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents)
        guard let s = FSEventStreamCreate(kCFAllocatorDefault, callback, &ctx,
                                          [path] as CFArray,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                          latency, flags) else { return }
        FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
        FSEventStreamStart(s)
        stream = s
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }
}
