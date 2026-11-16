import SwiftUI

struct WatchCheckInView: View {
    @EnvironmentObject private var session: WatchSessionManager

    @State private var fatigue = 3
    @State private var soreness = 2
    @State private var sleepFeeling = 2
    @State private var sent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if sent {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Palette.mint)
                        Text("已记录")
                            .font(.headline)
                        Text("回到手机 App 就能看到")
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    picker("疲劳程度", subtitle: "1 精力充沛 · 5 非常疲劳", selection: $fatigue)
                    picker("肌肉酸痛", subtitle: "1 没有 · 5 全身酸痛", selection: $soreness)
                    picker("睡眠感受", subtitle: "1 很好 · 5 没睡好", selection: $sleepFeeling)

                    Button {
                        submit()
                    } label: {
                        Text("发送到手机")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.mint)
                    .foregroundStyle(Color.black)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("打卡")
    }

    private func picker(_ title: String, subtitle: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(Palette.muted)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        selection.wrappedValue = value
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                selection.wrappedValue == value ? Palette.mint : Color.white.opacity(0.08),
                                in: Capsule()
                            )
                            .foregroundStyle(selection.wrappedValue == value ? Color.black : Palette.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func submit() {
        let checkIn = CheckIn(
            id: UUID().uuidString,
            createdAt: Date(),
            fatigue: fatigue,
            soreness: soreness,
            sleepFeeling: sleepFeeling,
            note: ""
        )
        session.send(checkIn: checkIn)
        sent = true
    }
}
