import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: RecoverySnapshot?
    @Published private(set) var nights: [SleepNight] = []
    @Published private(set) var workouts: [WorkoutRecord] = []
    @Published private(set) var trend: [DailyPoint] = []
    @Published private(set) var checkIns: [CheckIn] = []

    @Published var settings: UserSettings {
        didSet {
            store.save(settings, key: Keys.settings)
            guard settings != oldValue else { return }
            scheduleSettingsRefresh()
        }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var authorizationRequested: Bool
    @Published var errorMessage: String?

    private enum Keys {
        static let settings = "settings"
        static let checkIns = "checkIns"
        static let snapshot = "snapshot"
        static let nights = "nights"
        static let workouts = "workouts"
        static let trend = "trend"
    }

    private let store = LocalStore.shared
    private let health = HealthKitService.shared
    private let session = WatchSessionManager.shared

    private var settingsRefreshTask: Task<Void, Never>?
    private var isRefreshPending = false

    init() {
        let savedSettings = LocalStore.shared.load(UserSettings.self, key: Keys.settings) ?? .default
        settings = savedSettings
        checkIns = LocalStore.shared.load([CheckIn].self, key: Keys.checkIns) ?? []
        snapshot = LocalStore.shared.load(RecoverySnapshot.self, key: Keys.snapshot)
        nights = LocalStore.shared.load([SleepNight].self, key: Keys.nights) ?? []
        workouts = LocalStore.shared.load([WorkoutRecord].self, key: Keys.workouts) ?? []
        trend = LocalStore.shared.load([DailyPoint].self, key: Keys.trend) ?? []
        authorizationRequested = HealthKitService.shared.authorizationRequested

        session.onCheckInReceived = { [weak self] checkIn in
            Task { @MainActor in
                self?.receive(checkIn)
            }
        }
        session.activate()
    }

    func bootstrap() async {
        session.activate()
        if authorizationRequested {
            await refresh()
        }
    }

    func refresh() async {
        guard !isLoading else {
            isRefreshPending = true
            return
        }

        isRefreshPending = true
        while isRefreshPending {
            isRefreshPending = false
            isLoading = true
            do {
                let data = try await health.loadDashboard(days: 14, settings: settings)
                apply(data)
                lastUpdated = Date()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func requestHealthAccess() async {
        do {
            try await health.requestAuthorization()
            authorizationRequested = true
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reauthorize() async {
        health.resetAuthorizationFlag()
        authorizationRequested = false
        await requestHealthAccess()
    }

    func pushToWatch() {
        guard let snapshot, snapshot.hasAnyData else { return }
        session.push(snapshot: snapshot)
    }

    func clearLocalData() {
        settingsRefreshTask?.cancel()
        ["snapshot", "nights", "workouts", "trend", "checkIns", "watchSnapshot"].forEach {
            store.remove(key: $0)
        }
        snapshot = nil
        nights = []
        workouts = []
        trend = []
        checkIns = []
        lastUpdated = nil
        errorMessage = nil
    }

    // MARK: - 内部

    /// 设置改动后防抖刷新：Stepper 连续点按时只在停下后重算一次
    private func scheduleSettingsRefresh() {
        settingsRefreshTask?.cancel()
        guard authorizationRequested else { return }
        settingsRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    private func apply(_ data: DashboardData) {
        if !data.nights.isEmpty {
            nights = data.nights
            store.save(data.nights, key: Keys.nights)
        }
        if !data.workouts.isEmpty {
            workouts = data.workouts
            store.save(data.workouts, key: Keys.workouts)
        }
        if !data.trend.isEmpty {
            trend = data.trend
            store.save(data.trend, key: Keys.trend)
        }
        if data.snapshot.hasAnyData {
            snapshot = data.snapshot
            store.save(data.snapshot, key: Keys.snapshot)
            session.push(snapshot: data.snapshot)
        }
    }

    private func receive(_ checkIn: CheckIn) {
        guard !checkIns.contains(where: { $0.id == checkIn.id }) else { return }
        checkIns.insert(checkIn, at: 0)
        store.save(checkIns, key: Keys.checkIns)
    }
}
