import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var session: WatchSessionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if let snapshot = session.latestSnapshot {
                        ScoreRing(score: snapshot.score, size: 112)
                        Text(snapshot.headline)
                            .font(.headline)
                        Text(snapshot.advice)
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)

                        factorGrid(snapshot)

                        if snapshot.hasAnyData {
                            Text(snapshot.detail)
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.muted)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Image(systemName: "iphone.gen3")
                            .font(.title2)
                            .foregroundStyle(Palette.muted)
                        Text("等待手机同步")
                            .font(.headline)
                        Text("先在 iPhone 上打开一次 App")
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                    }

                    NavigationLink {
                        WatchCheckInView()
                    } label: {
                        Label("快速打卡", systemImage: "square.and.pencil")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.mint)
                    .foregroundStyle(Color.black)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
            .navigationTitle("恢复")
            .task {
                session.activate()
            }
        }
    }

    @ViewBuilder
    private func factorGrid(_ snapshot: RecoverySnapshot) -> some View {
        VStack(spacing: 6) {
            miniRow("睡眠", value: snapshot.hasSleepData ? Format.hours(snapshot.sleepHours) : "无", score: snapshot.sleepScore)
            miniRow("HRV", value: snapshot.hasHRVData ? "\(Int(snapshot.hrv.rounded()))ms" : "无", score: snapshot.hrvScore)
            miniRow("心率", value: snapshot.hasRHRData ? "\(Int(snapshot.restingHR.rounded()))" : "无", score: snapshot.rhrScore)
        }
        .padding(.top, 2)
    }

    private func miniRow(_ title: String, value: String, score: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.muted)
                .frame(width: 30, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Palette.mint)
                        .frame(width: geometry.size.width * CGFloat(max(0, min(score, 100))) / 100)
                }
            }
            .frame(height: 5)
            Text(value)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
