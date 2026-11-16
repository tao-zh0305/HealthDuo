import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !model.authorizationRequested {
                        permissionCard
                    }
                    heroCard
                    factorsCard
                    adviceCard
                    latestCheckInCard
                    disclaimer
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Palette.bg.ignoresSafeArea())
            .refreshable {
                await model.refresh()
            }
            .navigationTitle("今日")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        if model.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isLoading)
                }
            }
            .alert("出错了", isPresented: errorBinding) {
                Button("好", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    // MARK: - 卡片

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("先授权健康数据", systemImage: "heart.text.square.fill")
                .font(.headline)
                .foregroundStyle(Palette.mint)
            Text("只读取睡眠、HRV、静息心率、心率与训练记录，用来算恢复分；不写入、不上传。")
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await model.requestHealthAccess() }
            } label: {
                Text("去授权")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Palette.mint, in: Capsule())
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private var heroCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ScoreRing(score: model.snapshot?.score ?? 0, size: 128)

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.snapshot?.headline ?? "还没有恢复数据")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.ink)

                    if let updated = model.lastUpdated {
                        Text("更新于 \(updated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(Palette.muted.opacity(0.8))
                    }
                }

                Spacer(minLength: 0)
            }

            if let snapshot = model.snapshot, snapshot.hasAnyData {
                Text(snapshot.detail)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }

    private var factorsCard: some View {
        VStack(spacing: 14) {
            SectionTitle(text: "评分构成")
            FactorRow(
                title: "睡眠",
                valueText: sleepText,
                score: model.snapshot?.sleepScore ?? 0,
                tint: Palette.violet
            )
            FactorRow(
                title: "HRV",
                valueText: hrvText,
                score: model.snapshot?.hrvScore ?? 0,
                tint: Palette.mint
            )
            FactorRow(
                title: "静息心率",
                valueText: rhrText,
                score: model.snapshot?.rhrScore ?? 0,
                tint: Palette.amber
            )
        }
        .card()
    }

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "今日建议")
            Text(model.snapshot?.advice ?? "先记录几晚数据，建议会更有参考价值。")
                .font(.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    @ViewBuilder
    private var latestCheckInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "手表打卡")

            if let checkIn = model.checkIns.first {
                HStack(spacing: 8) {
                    chip("疲劳", checkIn.fatigue)
                    chip("酸痛", checkIn.soreness)
                    chip("睡眠感", checkIn.sleepFeeling)
                }
                Text(checkIn.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Palette.muted)
            } else {
                Text("在 Apple Watch 上打开 App，点「快速打卡」记录今天的主观感受，会自动同步到这里。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private var disclaimer: some View {
        Text("恢复分 = 睡眠 50% + HRV 30% + 静息心率 20%，仅用于观察自己的趋势，不构成医疗建议。")
            .font(.caption2)
            .foregroundStyle(Palette.muted.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func chip(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Palette.ink)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 文案

    private var sleepText: String {
        guard let snapshot = model.snapshot, snapshot.hasSleepData else { return "无数据" }
        return "\(Format.hours(snapshot.sleepHours)) / \(Format.hours(snapshot.sleepGoalHours))"
    }

    private var hrvText: String {
        guard let snapshot = model.snapshot, snapshot.hasHRVData else { return "无数据" }
        if snapshot.hrvBaseline > 0 {
            return "\(Int(snapshot.hrv.rounded()))ms · 基线 \(Int(snapshot.hrvBaseline.rounded()))"
        }
        return "\(Int(snapshot.hrv.rounded()))ms"
    }

    private var rhrText: String {
        guard let snapshot = model.snapshot, snapshot.hasRHRData else { return "无数据" }
        if snapshot.rhrBaseline > 0 {
            return "\(Int(snapshot.restingHR.rounded()))bpm · 基线 \(Int(snapshot.rhrBaseline.rounded()))"
        }
        return "\(Int(snapshot.restingHR.rounded()))bpm"
    }
}
