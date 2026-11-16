import Foundation
import WatchConnectivity

/// iPhone 与 Apple Watch 之间的直连同步，不经过 iCloud。
/// - 手机 -> 手表：恢复分快照（updateApplicationContext，手表没开 App 也会补发）
/// - 手表 -> 手机：主观打卡（可达时即时发送，否则排队后台传输）
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    private enum Key {
        static let kind = "kind"
        static let snapshot = "snapshot"
        static let checkIn = "checkIn"
        static let kindSnapshot = "snapshot"
        static let kindCheckIn = "checkIn"
        static let cacheKey = "watchSnapshot"
    }

    @Published private(set) var latestSnapshot: RecoverySnapshot?
    @Published private(set) var isReachable = false
    @Published private(set) var lastSentAt: Date?

    /// 手机端收到手表打卡时回调
    var onCheckInReceived: ((CheckIn) -> Void)?

    private let store = LocalStore.shared

    /// 会话尚未激活时先暂存打卡，激活完成后再发
    private var pendingCheckIns: [CheckIn] = []

    private override init() {
        super.init()
        latestSnapshot = store.load(RecoverySnapshot.self, key: Key.cacheKey)
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    /// 手机端调用：把最新恢复分推给手表
    func push(snapshot: RecoverySnapshot) {
        store.save(snapshot, key: Key.cacheKey)
        guard WCSession.isSupported() else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try WCSession.default.updateApplicationContext([
                Key.kind: Key.kindSnapshot,
                Key.snapshot: data
            ])
        } catch {
            // 应用上下文写入失败时忽略，下一次刷新会重试
        }
    }

    /// 手表端调用：发送主观打卡
    func send(checkIn: CheckIn) {
        lastSentAt = Date()
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else {
            pendingCheckIns.append(checkIn)
            activate()
            return
        }
        deliver(checkIn)
    }

    private func deliver(_ checkIn: CheckIn) {
        guard let data = try? JSONEncoder().encode(checkIn) else { return }
        let payload: [String: Any] = [
            Key.kind: Key.kindCheckIn,
            Key.checkIn: data
        ]
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func handle(_ payload: [String: Any]) {
        guard let kind = payload[Key.kind] as? String else { return }

        if kind == Key.kindSnapshot,
           let data = payload[Key.snapshot] as? Data,
           let snapshot = try? JSONDecoder().decode(RecoverySnapshot.self, from: data) {
            store.save(snapshot, key: Key.cacheKey)
            DispatchQueue.main.async {
                self.latestSnapshot = snapshot
            }
            return
        }

        if kind == Key.kindCheckIn,
           let data = payload[Key.checkIn] as? Data,
           let checkIn = try? JSONDecoder().decode(CheckIn.self, from: data) {
            DispatchQueue.main.async {
                self.onCheckInReceived?(checkIn)
            }
        }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            guard activationState == .activated, !self.pendingCheckIns.isEmpty else { return }
            let queued = self.pendingCheckIns
            self.pendingCheckIns = []
            queued.forEach { self.deliver($0) }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
