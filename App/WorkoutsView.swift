import SwiftUI
import Charts

private struct DayLoad: Identifiable {
    let id: String
    let date: Date
    let minutes: Double
}

struct WorkoutsView: View {
    @EnvironmentObject private var model: AppModel

    private var weekStart: Date {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .weekOfYear, for: Date())
        return calendar.startOfDay(for: interval?.start ?? Date())
    }

    private var weeklyWorkouts: [WorkoutRecord] {
        model.workouts.filter { $0.date >= weekStart }
    }

    private var weeklyMinutes: Double {
        weeklyWorkouts.reduce(0) { $0 + $1.durationMinutes }
    }

    private var weeklyEnergy: Double {
        weeklyWorkouts.reduce(0) { $0 + $1.activeEnergy }
    }

    private var dailyLoad: [DayLoad] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset -> DayLoad? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = model.workouts
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.durationMinutes }
            return DayLoad(id: DateKey.string(day, calendar: calendar), date: day, minutes: minutes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    statsCard
                    chartCard
                    listCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Palette.bg.ignoresSafeArea())
            .refreshable {
                await model.refresh()
            }
            .navigationTitle("训练")
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "本周训练")

            HStack(spacing: 10) {
                stat("\(weeklyWorkouts.count)", "次数", Palette.mint)
                stat(Format.duration(weeklyMinutes), "时长", Palette.blue)
                stat("\(Int(weeklyEnergy.rounded()))", "千卡", Palette.amber)
            }

            Text("目标每周 \(model.settings.weeklyWorkoutGoal) 次，已完成 \(weeklyWorkouts.count) 次")
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
        .card()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "最近 7 天负荷")

            Chart(dailyLoad) { day in
                BarMark(
                    x: .value("日期", day.date, unit: .day),
                    y: .value("分钟", day.minutes)
                )
                .foregroundStyle(Palette.mint.gradient)
                .cornerRadius(5)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 160)
        }
        .card()
    }

    @ViewBuilder
    private var listCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "最近训练")

            if model.workouts.isEmpty {
                Text("还没有训练记录。用 Apple Watch 或 iPhone 记录一次训练后，这里会自动出现。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(model.workouts.prefix(15))) { workout in
                    row(workout)
                    if workout.id != model.workouts.prefix(15).last?.id {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .card()
    }

    private func row(_ workout: WorkoutRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: workout.symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(Palette.blue.opacity(0.16), in: Circle())
                .foregroundStyle(Palette.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text("\(Format.day(workout.date)) · \(Format.duration(workout.durationMinutes))")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                if workout.averageHR > 0 {
                    Text("\(Int(workout.averageHR.rounded())) bpm")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                }
                if workout.activeEnergy > 0 {
                    Text("\(Int(workout.activeEnergy.rounded())) kcal")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(_ value: String, _ title: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
