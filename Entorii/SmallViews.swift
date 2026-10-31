import SwiftUI
import UIKit

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func lift() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func reveal() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func warn() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

enum KanaFont {
    /// Хирагино Минтё есть в iOS; начертание ближе к рукописному, чем рубленый шрифт.
    static func answer(_ size: CGFloat) -> Font { .custom("HiraMinProN-W6", size: size) }
}

/// «Спойлер» из мерцающих точек поверх скрытого ответа.
struct SpoilerView: View {
    var paused: Bool

    private struct Dot {
        let x, y, r, sx, sy, ph, fa: Double
    }

    @State private var dots: [Dot] = (0..<170).map { _ in
        Dot(x: .random(in: 0.1...0.9), y: .random(in: 0.24...0.76), r: .random(in: 0.5...1.7),
            sx: .random(in: 0.4...1.2), sy: .random(in: 0.4...1.2), ph: .random(in: 0...(2 * .pi)), fa: .random(in: 1.5...4))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: paused)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let k = max(0.7, min(1.6, size.height / 110))
                for d in dots {
                    let x = (d.x + sin(t * d.sx + d.ph) * 0.025) * size.width
                    let y = (d.y + cos(t * d.sy + d.ph) * 0.05) * size.height
                    let r = d.r * k
                    ctx.opacity = 0.2 + 0.8 * abs(sin(t * d.fa + d.ph))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.primary))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Главный кружок: пустой контур или залитый круг.
struct AnswerCircle: View {
    let filled: Bool
    let size: CGFloat

    var body: some View {
        let lw = max(2.5, size * 0.036)
        ZStack {
            Circle().fill(Color.primary).scaleEffect(filled ? 1 : 0.001)
            Circle().strokeBorder(Color.primary, lineWidth: lw)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.62), value: filled)
    }
}

/// Кнопка инструмента: показывает инструмент, на который переключит нажатие.
struct ToolButtonFace: View {
    let tool: WritingTool
    let size: CGFloat

    var body: some View {
        let lw = max(2.5, size * 0.036)
        ZStack {
            Circle().fill(Color(.systemBackground))
            ZStack {
                Image(systemName: tool == .pen ? "eraser" : "pencil.tip")
                    .font(.system(size: size * 0.36, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .id(tool)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)))
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            Circle().strokeBorder(Color.primary, lineWidth: lw)
        }
    }
}

/// Сдвиг «нельзя» для строки настроек.
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(animatableData * .pi * 4), y: 0))
    }
}
