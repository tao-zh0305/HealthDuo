import SwiftUI
import Charts
import Foundation

enum TrendMetric: String, CaseIterable, Identifiable {
    case recovery = "恢复分"
    case hrv = "HRV"
    case rhr = "静息心率"
    case sleep = "睡眠"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .recovery: return "分"
        case .hrv: return "ms"
        case .rhr: return "bpm"
        case .sleep: return "小时"
        }
    }

    var color: Color {
        switch self {
        case .recovery: return Palette.mint
        case .hrv: return Palette.blue
        case .rhr: return Palette.amber
        case .sleep: return Palette.violet
        }
    }
}

struct TrendsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var metric: TrendMetric = .recovery

    private var points: [DailyPoint] {
        model.trend.filter { value(for: $0) > 0 }
    }

    private var recentPoints: [DailyPoint] {
        Array(points.suffix(7))
    }

    private var summary: (average: Double, low: Double, high: Double)? {
        guard !recentPoints.isEmpty else { return nil }
        let values = recentPoints.map { value(for: $0) }
        let total = values.reduce(0, +)
        return (
            average: total / Double(values.count),
            low: values.min() ?? 0,
            high: values.max() ?? 0
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("指标", selection: $metric) {
                        ForEach(TrendMetric.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    chartCard
                    summaryCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Palette.bg.ignoresSafeArea())
            .refreshable {
                await model.refresh()
            }
            .navigationTitle("趋势")
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "最近 14 天 · \(metric.rawValue)")

            if points.isEmpty {
                Text("还没有足够的数据，连续记录几天后趋势会更有意义。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("日期", point.date),
                            y: .value("值", value(for: point))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [metric.color.opacity(0.25), metric.color.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("值", value(for: point))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(metric.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        PointMark(
                            x: .value("日期", point.date),
                            y: .value("值", value(for: point))
                        )
                        .foregroundStyle(metric.color)
                        .symbolSize(20)
                    }
                }
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 220)
            }
        }
        .card()
    }

    @ViewBuilder
    private var summaryCard: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "最近 7 天")
                HStack(spacing: 10) {
                    stat(String(format: "%.1f", summary.average), "平均", Palette.ink)
                    stat(String(format: "%.1f", summary.low), "最低", Palette.blue)
                    stat(String(format: "%.1f", summary.high), "最高", Palette.amber)
                }
                Text("单位：\(metric.unit)")
                    .font(.caption2)
                    .foregroundStyle(Palette.muted)
            }
            .card()
        }
    }

    private var yDomain: ClosedRange<Double> {
        switch metric {
        case .recovery:
            return 0...100
        case .sleep:
            return 0...max(10, model.settings.sleepGoalHours + 1)
        case .hrv, .rhr:
            let maxValue = points.map { value(for: $0) }.max() ?? 0
            return 0...(max(10, maxValue * 1.2))
        }
    }

    private func value(for point: DailyPoint) -> Double {
        switch metric {
        case .recovery: return Double(point.recovery)
        case .hrv: return point.hrv
        case .rhr: return point.rhr
        case .sleep: return point.sleepHours
        }
    }

    private func stat(_ value: String, _ title: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
