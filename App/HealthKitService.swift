import Foundation
import HealthKit

enum HealthError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "这台设备不支持 Apple 健康数据"
        }
    }
}

/// 只读 Apple 健康：睡眠、HRV、静息心率、心率与训练。
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard
    private let requestedKey = "healthkit.authorizationRequested"

    var authorizationRequested: Bool {
        defaults.bool(forKey: requestedKey)
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .heartRate,
            .activeEnergyBurned
        ]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        for identifier in identifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        defaults.set(true, forKey: requestedKey)
    }

    func resetAuthorizationFlag() {
        defaults.removeObject(forKey: requestedKey)
    }

    func loadDashboard(days: Int, settings: UserSettings) async throws -> DashboardData {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }

        let today = calendar.startOfDay(for: Date())
        let lookback = max(settings.hrvBaselineDays + 2, days + 2)
        guard let start = calendar.date(byAdding: .day, value: -lookback, to: today) else {
            throw HealthError.unavailable
        }

        let sleepSamples = try await fetchSleepSamples(from: start)
        let hrvSamples = try await fetchQuantity(.heartRateVariabilitySDNN, from: start)
        let rhrSamples = try await fetchQuantity(.restingHeartRate, from: start)
        let workouts = try await fetchWorkouts(from: start)

        let nights = buildNights(from: sleepSamples)
        let hrvDaily = dailyAccumulators(hrvSamples, unit: HKUnit.secondUnit(with: .milli))
        let rhrDaily = dailyAccumulators(rhrSamples, unit: HKUnit.count().unitDivided(by: HKUnit.minute()))

        let hrvBaseline = baselineAverage(hrvDaily, days: settings.hrvBaselineDays)
        let rhrBaseline = baselineAverage(rhrDaily, days: settings.hrvBaselineDays)
        let lastNight = nights.first
        let hrvLatest = latestValue(hrvDaily, withinDays: 7)
        let rhrLatest = latestValue(rhrDaily, withinDays: 7)

        let snapshot = RecoveryEngine.snapshot(
            sleepHours: lastNight?.asleepHours ?? 0,
            sleepGoalHours: settings.sleepGoalHours,
            hrv: hrvLatest,
            hrvBaseline: hrvBaseline,
            restingHR: rhrLatest,
            rhrBaseline: rhrBaseline
        )

        let nightsByDay = Dictionary(uniqueKeysWithValues: nights.map { ($0.id, $0) })
        var points: [DailyPoint] = []

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = DateKey.string(date, calendar: calendar)
            let sleepHours = nightsByDay[key]?.asleepHours ?? 0
            let hrv = hrvDaily[key]?.average ?? 0
            let rhr = rhrDaily[key]?.average ?? 0
            guard sleepHours > 0 || hrv > 0 || rhr > 0 else { continue }

            let score = RecoveryEngine.breakdown(
                sleepHours: sleepHours,
                sleepGoalHours: settings.sleepGoalHours,
                hrv: hrv,
                hrvBaseline: hrvBaseline,
                restingHR: rhr,
                rhrBaseline: rhrBaseline
            ).score

            points.append(DailyPoint(
                id: key,
                date: date,
                sleepHours: sleepHours,
                hrv: hrv,
                rhr: rhr,
                recovery: score
            ))
        }

        return DashboardData(snapshot: snapshot, nights: nights, workouts: workouts, trend: points)
    }

    // MARK: - 查询

    private func fetchSleepSamples(from start: Date) async throws -> [HKCategorySample] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictEndDate)
        let descriptor = HKSampleQueryDescriptor<HKCategorySample>(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await descriptor.result(for: store)
    }

    private func fetchQuantity(_ identifier: HKQuantityTypeIdentifier, from start: Date) async throws -> [HKQuantitySample] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await descriptor.result(for: store)
    }

    private func fetchWorkouts(from start: Date) async throws -> [WorkoutRecord] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor<HKWorkout>(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 40
        )
        let workouts = try await descriptor.result(for: store)
        return workouts.map { record(from: $0) }
    }

    // MARK: - 聚合

    private struct DailyAccumulator {
        var date: Date
        var total: Double = 0
        var count: Int = 0

        var average: Double {
            count > 0 ? total / Double(count) : 0
        }
    }

    private func dailyAccumulators(_ samples: [HKQuantitySample], unit: HKUnit) -> [String: DailyAccumulator] {
        var result: [String: DailyAccumulator] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.endDate)
            let key = DateKey.string(day, calendar: calendar)
            var accumulator = result[key] ?? DailyAccumulator(date: day)
            accumulator.total += sample.quantity.doubleValue(for: unit)
            accumulator.count += 1
            result[key] = accumulator
        }
        return result
    }

    private func baselineAverage(_ values: [String: DailyAccumulator], days: Int) -> Double {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -max(days, 1), to: today) else { return 0 }
        let samples = values.values.filter { $0.date >= start && $0.date < today }
        guard samples.count >= 3 else { return 0 }
        return samples.map(\.average).reduce(0, +) / Double(samples.count)
    }

    private func latestValue(_ values: [String: DailyAccumulator], withinDays days: Int) -> Double {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        return values.values
            .filter { $0.date >= start }
            .sorted { $0.date > $1.date }
            .first?.average ?? 0
    }

    // MARK: - 睡眠整理

    private func buildNights(from samples: [HKCategorySample]) -> [SleepNight] {
        var seen = Set<String>()
        let unique = samples.filter { sample in
            let token = "\(sample.value)-\(Int(sample.startDate.timeIntervalSince1970))-\(Int(sample.endDate.timeIntervalSince1970))"
            if seen.contains(token) { return false }
            seen.insert(token)
            return true
        }

        var sessions: [[HKCategorySample]] = []
        var current: [HKCategorySample] = []
        for sample in unique.sorted(by: { $0.startDate < $1.startDate }) {
            if let last = current.last,
               sample.startDate.timeIntervalSince(last.endDate) > 3 * 3600 {
                sessions.append(current)
                current = []
            }
            current.append(sample)
        }
        if !current.isEmpty {
            sessions.append(current)
        }

        var byDay: [String: SleepNight] = [:]
        for session in sessions {
            guard let night = makeNight(from: session) else { continue }
            if let existing = byDay[night.id], existing.asleepHours >= night.asleepHours {
                continue
            }
            byDay[night.id] = night
        }

        return byDay.values.sorted { $0.date > $1.date }
    }

    private func makeNight(from session: [HKCategorySample]) -> SleepNight? {
        var core = 0.0
        var deep = 0.0
        var rem = 0.0
        var unspecified = 0.0
        var awake = 0.0
        var asleepStart: Date?
        var asleepEnd: Date?

        for sample in session {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60

            switch value {
            case .inBed:
                break
            case .awake:
                awake += minutes
            case .asleepCore:
                core += minutes
            case .asleepDeep:
                deep += minutes
            case .asleepREM:
                rem += minutes
            case .asleepUnspecified:
                unspecified += minutes
            @unknown default:
                break
            }

            if value != .inBed, value != .awake {
                if asleepStart == nil {
                    asleepStart = sample.startDate
                }
                asleepEnd = sample.endDate
            }
        }

        let total = core + deep + rem + unspecified
        guard total > 10 else { return nil }

        let wakeDate = asleepEnd ?? session.last?.endDate ?? Date()
        return SleepNight(
            id: DateKey.string(wakeDate, calendar: calendar),
            date: calendar.startOfDay(for: wakeDate),
            asleepHours: total / 60,
            coreHours: core / 60,
            deepHours: deep / 60,
            remHours: rem / 60,
            awakeHours: awake / 60,
            bedTime: asleepStart,
            wakeTime: asleepEnd
        )
    }

    // MARK: - 训练整理

    private func record(from workout: HKWorkout) -> WorkoutRecord {
        let bpm = HKUnit.count().unitDivided(by: HKUnit.minute())
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)

        let averageHR = hrType.flatMap {
            workout.statistics(for: $0)?.averageQuantity()?.doubleValue(for: bpm)
        } ?? 0
        let energy = energyType.flatMap {
            workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        } ?? 0
        let info = describe(workout.workoutActivityType)

        return WorkoutRecord(
            id: workout.uuid.uuidString,
            date: workout.startDate,
            name: info.name,
            symbol: info.symbol,
            durationMinutes: workout.duration / 60,
            activeEnergy: energy,
            averageHR: averageHR
        )
    }

    private func describe(_ type: HKWorkoutActivityType) -> (name: String, symbol: String) {
        switch type {
        case .running:
            return ("跑步", "figure.run")
        case .walking:
            return ("步行", "figure.walk")
        case .cycling:
            return ("骑行", "figure.outdoor.cycle")
        case .swimming:
            return ("游泳", "figure.pool.swim")
        case .hiking:
            return ("徒步", "figure.hiking")
        case .yoga:
            return ("瑜伽", "figure.yoga")
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return ("力量训练", "figure.strengthtraining.traditional")
        case .highIntensityIntervalTraining:
            return ("HIIT", "figure.highintensity.intervaltraining")
        case .elliptical:
            return ("椭圆机", "figure.elliptical")
        case .rowing:
            return ("划船", "figure.rower")
        case .stairClimbing, .stairs:
            return ("爬楼", "figure.stairs")
        case .pilates:
            return ("普拉提", "figure.pilates")
        case .coreTraining:
            return ("核心训练", "figure.core.training")
        case .flexibility:
            return ("拉伸", "figure.flexibility")
        case .mindAndBody:
            return ("身心训练", "figure.mind.and.body")
        case .soccer:
            return ("足球", "figure.soccer")
        case .basketball:
            return ("篮球", "figure.basketball")
        case .tennis:
            return ("网球", "figure.tennis")
        case .badminton:
            return ("羽毛球", "figure.badminton")
        default:
            return ("训练", "figure.mixed.cardio")
        }
    }
}
