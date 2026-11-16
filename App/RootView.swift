import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "sun.max.fill") }

            SleepView()
                .tabItem { Label("睡眠", systemImage: "moon.zzz.fill") }

            WorkoutsView()
                .tabItem { Label("训练", systemImage: "figure.run") }

            TrendsView()
                .tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(Palette.mint)
        .task {
            await model.bootstrap()
        }
    }
}
