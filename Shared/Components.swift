import SwiftUI

// MARK: - 配色

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

enum Palette {
    static let bg = Color(hex: 0x0A0F1C)
    static let card = Color(hex: 0x121A2B)
    static let ink = Color(hex: 0xF2F5FA)
    static let muted = Color(hex: 0x8A96AA)
    static let mint = Color(hex: 0x34D399)
    static let amber = Color(hex: 0xFBBF24)
    static let coral = Color(hex: 0xF87171)
    static let blue = Color(hex: 0x60A5FA)
    static let violet = Color(hex: 0xA78BFA)
}

// MARK: - 通用卡片

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 恢复分圆环

struct ScoreRing: View {
    let score: Int
    let size: CGFloat

    private var lineWidth: CGFloat { max(7, size * 0.085) }

    private var ringColor: Color {
        switch score {
        case 85...: return Palette.mint
        case 70..<85: return Palette.blue
        case 50..<70: return Palette.amber
        default: return Palette.coral
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(score, 100))) / 100)
                .stroke(
                    LinearGradient(
                        colors: [ringColor.opacity(0.55), ringColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("恢复分")
                    .font(.system(size: max(9, size * 0.08), weight: .medium))
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 因子进度条

struct FactorRow: View {
    let title: String
    let valueText: String
    let score: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.muted)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(tint)
                        .frame(width: geometry.size.width * CGFloat(max(0, min(score, 100))) / 100)
                }
            }
            .frame(height: 6)
        }
    }
}
