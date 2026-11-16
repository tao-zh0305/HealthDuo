import SwiftUI
import Charts

private struct StageSlice: Identifiable {
    let id: String
    let name: String
    let hours: Double
    let color: Color
}

struct SleepView: View {
    @EnvironmentObject private var model: AppModel

    private var lastNight: SleepNight? { model.nights.first }

    private var stages: [StageSlice] {
        guard let night = lastNight else { return [] }
        return [
            StageSlice(id: "light", name: "浅睡", hours: night.lightHours, color: Palette.blue),
            StageSlice(id: "deep", name: "深睡", hours: night.deepHours, color: Palette.violet),
            StageSlice(id: "rem", name: "REM", hours: night.remHours, color: Palette.mint),
            StageSlice(id: "awake", name: "清醒", hours: night.awakeHours, color: Palette.amber)
        ]
    }

    private var recentNights: [SleepNight] {
        Array(model.nights.prefix(7).reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let night = lastNight {
                        lastNightCard(night)
                        stageCard
                        weekCard
                    } else {
                        emptyCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Palette.bg.ignoresSafeArea())
            .refreshable {
                await model.refresh()
            }
            .navigationTitle("睡眠")
        }
    }

    private func lastNightCard(_ night: SleepNight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "昨晚睡眠")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Format.hours(night.asleepHours))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("目标 \(Format.hours(model.settings.sleepGoalHours))")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }

            HStack(spacing: 18) {
                label("入睡", Format.clock(night.bedTime))
                label("起床", Format.clock(night.wakeTime))
                label("清醒", Format.hours(night.awakeHours))
            }
        }
        .card()
    }

    private var stageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "睡眠结构")

            GeometryReader { geometry in
                let total = max(stages.reduce(0) { $0 + $1.hours }, 0.01)
                HStack(spacing: 2) {
                    ForEach(stages) { stage in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(stage.color)
                            .frame(width: max(3, geometry.size.width * CGFloat(stage.hours / total)))
                    }
                }
            }
            .frame(height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(spacing: 8) {
                ForEach(stages) { stage in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(stage.color)
                            .frame(width: 8, height: 8)
                        Text(stage.name)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text(Format.hours(stage.hours))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
        }
        .card()
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "最近 7 天")

            Chart {
                ForEach(recentNights) { night in
                    BarMark(
                        x: .value("日期", night.date, unit: .day),
                        y: .value("睡眠", night.asleepHours)
                    )
                    .foregroundStyle(Palette.violet.gradient)
                    .cornerRadius(5)
                }

                RuleMark(y: .value("目标", model.settings.sleepGoalHours))
                    .foregroundStyle(Palette.muted.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: 0...max(10, model.settings.sleepGoalHours + 1))
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 180)

            Text("虚线是睡眠目标，柱高是实际睡着的时间。")
                .font(.caption2)
                .foregroundStyle(Palette.muted)
        }
        .card()
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "还没有睡眠数据")
            Text("戴 Apple Watch 睡觉，并在「健康」里开启睡眠追踪，明早这里就会出现睡眠结构和 7 天趋势。")
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func label(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Palette.ink)
        }
    }
}
