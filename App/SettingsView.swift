import SwiftUI
import Foundation

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var watch = WatchSessionManager.shared
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("目标") {
                    Stepper(value: $model.settings.sleepGoalHours, in: 5...10, step: 0.5) {
                        HStack {
                            Text("睡眠目标")
                            Spacer()
                            Text(String(format: "%.1f 小时", model.settings.sleepGoalHours))
                                .foregroundStyle(Palette.muted)
                        }
                    }

                    Picker("HRV 基线", selection: $model.settings.hrvBaselineDays) {
                        Text("14 天").tag(14)
                        Text("28 天").tag(28)
                        Text("56 天").tag(56)
                    }

                    Stepper(value: $model.settings.weeklyWorkoutGoal, in: 1...7) {
                        HStack {
                            Text("每周训练目标")
                            Spacer()
                            Text("\(model.settings.weeklyWorkoutGoal) 次")
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }

                Section("健康数据") {
                    HStack {
                        Text("读取权限")
                        Spacer()
                        Text(model.authorizationRequested ? "已请求" : "未请求")
                            .foregroundStyle(model.authorizationRequested ? Palette.mint : Palette.amber)
                    }

                    Button("重新请求健康权限") {
                        Task { await model.reauthorize() }
                    }

                    Button("立即刷新数据") {
                        Task { await model.refresh() }
                    }
                    .disabled(model.isLoading)
                }

                Section("iPhone 与手表同步") {
                    HStack {
                        Text("手表连接")
                        Spacer()
                        Text(watch.isReachable ? "已连接" : "未连接")
                            .foregroundStyle(watch.isReachable ? Palette.mint : Palette.muted)
                    }

                    Button("把恢复分推送到手表") {
                        model.pushToWatch()
                    }

                    Text("同步走 WatchConnectivity 直连，不需要 iCloud。手表不在身边时会排队，下次连上再传。")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }

                Section("本机数据") {
                    HStack {
                        Text("最近更新时间")
                        Spacer()
                        Text(model.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "还没有")
                            .foregroundStyle(Palette.muted)
                    }
                    HStack {
                        Text("手表打卡记录")
                        Spacer()
                        Text("\(model.checkIns.count) 条")
                            .foregroundStyle(Palette.muted)
                    }
                    Button("清空本机缓存", role: .destructive) {
                        showResetAlert = true
                    }
                }

                Section("关于") {
                    Text("恢复分按睡眠 50%、HRV 30%、静息心率 20% 加权，只用于观察自己的趋势，不构成医疗建议。")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                    Text("版本 1.0 · 本地存储，不上传任何数据")
                        .font(.caption2)
                        .foregroundStyle(Palette.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("设置")
            .alert("清空本机缓存？", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    model.clearLocalData()
                }
            } message: {
                Text("会删除本机缓存的睡眠、训练、趋势和打卡记录。健康 App 里的原始数据不受影响。")
            }
        }
    }

}
