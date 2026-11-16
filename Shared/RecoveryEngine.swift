import Foundation

// MARK: - 恢复分

struct RecoveryBreakdown {
    var score: Int
    var sleepScore: Int
    var hrvScore: Int
    var rhrScore: Int
}

/// 恢复分 = 睡眠 50% + HRV 30% + 静息心率 20%
/// 只做趋势参考，不做医疗判断。
enum RecoveryEngine {

    static func breakdown(
        sleepHours: Double,
        sleepGoalHours: Double,
        hrv: Double,
        hrvBaseline: Double,
        restingHR: Double,
        rhrBaseline: Double
    ) -> RecoveryBreakdown {
        let goal = max(sleepGoalHours, 4)
        let sleepScore = sleepHours > 0
            ? Int((clamp(sleepHours / goal, 0, 1) * 100).rounded())
            : 0

        var hrvScore = 60
        if hrv > 0, hrvBaseline > 0 {
            let ratio = hrv / hrvBaseline
            hrvScore = Int(clamp(20 + (ratio - 0.7) * 200, 0, 100).rounded())
        }

        var rhrScore = 60
        if restingHR > 0, rhrBaseline > 0 {
            // 比基线每低 1 bpm 加一点分，每高 1 bpm 扣 6 分
            rhrScore = Int(clamp(100 - (restingHR - rhrBaseline) * 6, 0, 100).rounded())
        }

        var weighted: Double

        // 缺哪项数据，就把权重让给有的项，避免用中性分把结果压扁
        let sleepAvailable = sleepHours > 0
        let hrvAvailable = hrv > 0 && hrvBaseline > 0
        let rhrAvailable = restingHR > 0 && rhrBaseline > 0
        let s = Double(sleepScore)
        let h = Double(hrvScore)
        let r = Double(rhrScore)

        switch (sleepAvailable, hrvAvailable, rhrAvailable) {
        case (true, true, true):
            weighted = s * 0.5 + h * 0.3 + r * 0.2
        case (true, true, false):
            weighted = s * 0.65 + h * 0.35
        case (true, false, true):
            weighted = s * 0.7 + r * 0.3
        case (true, false, false):
            weighted = s
        case (false, true, true):
            weighted = h * 0.6 + r * 0.4
        case (false, true, false):
            weighted = h
        case (false, false, true):
            weighted = r
        case (false, false, false):
            weighted = 0
        }

        return RecoveryBreakdown(
            score: Int(clamp(weighted, 0, 100).rounded()),
            sleepScore: sleepScore,
            hrvScore: hrvScore,
            rhrScore: rhrScore
        )
    }

    static func snapshot(
        date: Date = Date(),
        sleepHours: Double,
        sleepGoalHours: Double,
        hrv: Double,
        hrvBaseline: Double,
        restingHR: Double,
        rhrBaseline: Double
    ) -> RecoverySnapshot {
        let parts = breakdown(
            sleepHours: sleepHours,
            sleepGoalHours: sleepGoalHours,
            hrv: hrv,
            hrvBaseline: hrvBaseline,
            restingHR: restingHR,
            rhrBaseline: rhrBaseline
        )

        let hasSleep = sleepHours > 0
        let hasHRV = hrv > 0
        let hasRHR = restingHR > 0
        let score = parts.score

        let headline: String
        let advice: String

        if !hasSleep && !hasHRV && !hasRHR {
            headline = "还没有健康数据"
            advice = "先授权 Apple 健康，再佩戴手表睡一晚，明早就能看到恢复分。"
        } else {
            switch score {
            case 85...:
                headline = "恢复良好"
                advice = "今天可以正常训练，想上强度也没问题。"
            case 70..<85:
                headline = "状态可用"
                advice = "按计划训练，热身多做两分钟，留意身体反馈。"
            case 50..<70:
                headline = "需要缓一缓"
                advice = "建议低强度有氧或拉伸，别硬顶大重量。"
            default:
                headline = "优先恢复"
                advice = "今天以休息为主，散步、拉伸、早睡，比多练一次更有价值。"
            }
        }

        var detailParts: [String] = []
        if hasSleep {
            detailParts.append(String(format: "睡眠 %.1f 小时（目标 %.1f）", sleepHours, sleepGoalHours))
        }
        if hasHRV {
            if hrvBaseline > 0 {
                detailParts.append(String(format: "HRV %.0fms（基线 %.0fms）", hrv, hrvBaseline))
            } else {
                detailParts.append(String(format: "HRV %.0fms", hrv))
            }
        }
        if hasRHR {
            if rhrBaseline > 0 {
                detailParts.append(String(format: "静息心率 %.0f（基线 %.0f）", restingHR, rhrBaseline))
            } else {
                detailParts.append(String(format: "静息心率 %.0f", restingHR))
            }
        }

        var detail: String
        if !hasSleep && !hasHRV && !hasRHR {
            detail = "等待健康数据"
        } else {
            detail = detailParts.joined(separator: " · ")
            if !hasHRV || !hasRHR {
                let missing = [!hasHRV ? "HRV" : nil, !hasRHR ? "静息心率" : nil]
                    .compactMap { $0 }
                    .joined(separator: "、")
                if !missing.isEmpty {
                    detail += detail.isEmpty ? "暂缺 \(missing) 数据" : "；暂缺 \(missing) 数据"
                }
            }
        }

        return RecoverySnapshot(
            date: date,
            score: score,
            sleepHours: sleepHours,
            sleepGoalHours: sleepGoalHours,
            sleepScore: parts.sleepScore,
            hrv: hrv,
            hrvBaseline: hrvBaseline,
            hrvScore: parts.hrvScore,
            restingHR: restingHR,
            rhrBaseline: rhrBaseline,
            rhrScore: parts.rhrScore,
            headline: headline,
            advice: advice,
            detail: detail,
            hasSleepData: hasSleep,
            hasHRVData: hasHRV,
            hasRHRData: hasRHR
        )
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
