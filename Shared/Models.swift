import Foundation

// MARK: - 每日恢复快照

struct RecoverySnapshot: Codable, Equatable {
    var date: Date
    var score: Int

    var sleepHours: Double
    var sleepGoalHours: Double
    var sleepScore: Int

    var hrv: Double
    var hrvBaseline: Double
    var hrvScore: Int

    var restingHR: Double
    var rhrBaseline: Double
    var rhrScore: Int

    var headline: String
    var advice: String
    var detail: String

    var hasSleepData: Bool
    var hasHRVData: Bool
    var hasRHRData: Bool

    var hasAnyData: Bool {
        hasSleepData || hasHRVData || hasRHRData
    }
}

// MARK: - 睡眠

struct SleepNight: Codable, Identifiable, Equatable {
    /// 以醒来那天作为 id，格式 yyyy-MM-dd
    var id: String
    var date: Date
    var asleepHours: Double
    var coreHours: Double
    var deepHours: Double
    var remHours: Double
    var awakeHours: Double
    var bedTime: Date?
    var wakeTime: Date?

    /// 除深睡、REM 之外的睡眠（浅睡 + 未分类）
    var lightHours: Double {
        max(0, asleepHours - deepHours - remHours)
    }
}

// MARK: - 训练

struct WorkoutRecord: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var name: String
    var symbol: String
    var durationMinutes: Double
    var activeEnergy: Double
    var averageHR: Double
}

// MARK: - 趋势

struct DailyPoint: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var sleepHours: Double
    var hrv: Double
    var rhr: Double
    var recovery: Int
}

// MARK: - 手表打卡

struct CheckIn: Codable, Identifiable, Equatable {
    var id: String
    var createdAt: Date
    var fatigue: Int
    var soreness: Int
    var sleepFeeling: Int
    var note: String
}

// MARK: - 设置

struct UserSettings: Codable, Equatable {
    var sleepGoalHours: Double
    var hrvBaselineDays: Int
    var weeklyWorkoutGoal: Int

    static let `default` = UserSettings()

    init(sleepGoalHours: Double = 8, hrvBaselineDays: Int = 28, weeklyWorkoutGoal: Int = 3) {
        self.sleepGoalHours = sleepGoalHours
        self.hrvBaselineDays = hrvBaselineDays
        self.weeklyWorkoutGoal = weeklyWorkoutGoal
    }

    private enum CodingKeys: String, CodingKey {
        case sleepGoalHours
        case hrvBaselineDays
        case weeklyWorkoutGoal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sleepGoalHours = try container.decodeIfPresent(Double.self, forKey: .sleepGoalHours) ?? 8
        hrvBaselineDays = try container.decodeIfPresent(Int.self, forKey: .hrvBaselineDays) ?? 28
        weeklyWorkoutGoal = try container.decodeIfPresent(Int.self, forKey: .weeklyWorkoutGoal) ?? 3
    }
}

// MARK: - 页面数据

struct DashboardData {
    var snapshot: RecoverySnapshot
    var nights: [SleepNight]
    var workouts: [WorkoutRecord]
    var trend: [DailyPoint]
}

// MARK: - 日期键

enum DateKey {
    static func string(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
