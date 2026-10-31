import SwiftUI

/// Кнопка или стикер свободной зоны.
/// Тап — действие. Долгое нажатие — режим правки: элемент покачивается, его можно таскать,
/// а ручкой в углу менять размер. Двигается только внутри зоны и не заходит на шестерёнку.
struct FloatingItem<Content: View>: View {
    let id: String
    let placement: Placement
    let defaultSize: CGFloat
    let zone: CGSize
    let blocked: CGRect
    let round: Bool
    @Binding var editingID: String?
    var onTap: () -> Void = {}
    let onChange: (Placement) -> Void
    var onCommit: () -> Void = {}
    @ViewBuilder let content: (CGFloat) -> Content

    @State private var pressed = false
    @State private var lifted = false
    @State private var touchActive = false
    @State private var cancelled = false
    @State private var dragStartCenter: CGPoint?
    @State private var sizeStart: CGFloat?
    @State private var wiggle = false
    @State private var liftTask: Task<Void, Never>?

    private var editing: Bool { editingID == id }

    private var maxSize: CGFloat { max(40, min(220, zone.width, zone.height)) }

    private func clampSize(_ s: CGFloat) -> CGFloat { min(max(s, min(48, maxSize)), maxSize) }

    private var size: CGFloat { clampSize(placement.size.map { CGFloat($0) } ?? defaultSize) }

    private func clampCenter(_ p: CGPoint, _ s: CGFloat) -> CGPoint {
        let half = s / 2
        var x = min(max(p.x, half), max(half, zone.width - half))
        var y = min(max(p.y, half), max(half, zone.height - half))
        if blocked != .zero {
            let r = CGRect(x: x - half, y: y - half, width: s, height: s)
            if r.intersects(blocked) { y = blocked.maxY + half + 4 }
        }
        x = x.isFinite ? x : half
        y = y.isFinite ? y : half
        return CGPoint(x: x, y: y)
    }

    private var center: CGPoint {
        clampCenter(CGPoint(x: placement.cx * zone.width, y: placement.cy * zone.height), size)
    }

    private func store(center c: CGPoint, size s: CGFloat?) {
        guard zone.width > 0, zone.height > 0 else { return }
        var p = placement
        p.cx = Double(c.x / zone.width)
        p.cy = Double(c.y / zone.height)
        if let s { p.size = Double(s) }
        onChange(p)
    }

    var body: some View {
        let s = size
        content(s)
            .frame(width: s, height: s)
            .contentShape(round ? AnyShape(Circle()) : AnyShape(Rectangle()))
            .overlay {
                if editing {
                    Group {
                        if round {
                            Circle().stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        } else {
                            RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                    }
                    .padding(-8)
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if editing { resizeHandle }
            }
            .scaleEffect(pressed ? 0.88 : (lifted ? 1.07 : 1))
            .shadow(color: .black.opacity(lifted ? 0.22 : 0), radius: 12, y: 8)
            .rotationEffect(.degrees(editing && !lifted ? (wiggle ? 1.6 : -1.6) : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: pressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lifted)
            .gesture(mainGesture)
            .position(center)
            .zIndex(editing ? 2 : 0)
            .onChange(of: editing) { _, now in
                if now {
                    withAnimation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true)) { wiggle = true }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { wiggle = false }
                }
            }
    }

    private var resizeHandle: some View {
        ZStack {
            Circle().fill(Color.accentColor)
            Circle().strokeBorder(Color(.systemBackground), lineWidth: 3)
            Image(systemName: "arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
        .offset(x: 16, y: 16)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("zone"))
                .onChanged { v in
                    let base = sizeStart ?? size
                    if sizeStart == nil { sizeStart = base }
                    let ns = clampSize(base + max(v.translation.width, v.translation.height))
                    store(center: clampCenter(center, ns), size: ns)
                }
                .onEnded { _ in
                    sizeStart = nil
                    onCommit()
                }
        )
    }

    private var mainGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("zone"))
            .onChanged { v in
                if !touchActive {
                    touchActive = true
                    cancelled = false
                    dragStartCenter = center
                    if editing {
                        lifted = true
                    } else {
                        if editingID != nil { editingID = nil }
                        pressed = true
                        liftTask?.cancel()
                        liftTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 450_000_000)
                            guard !Task.isCancelled, touchActive, !cancelled else { return }
                            pressed = false
                            lifted = true
                            editingID = id
                            Haptics.lift()
                        }
                    }
                }
                if lifted, let start = dragStartCenter {
                    let c = CGPoint(x: start.x + v.translation.width, y: start.y + v.translation.height)
                    store(center: clampCenter(c, size), size: nil)
                } else if !cancelled, hypot(v.translation.width, v.translation.height) > 10 {
                    cancelled = true
                    pressed = false
                    liftTask?.cancel()
                }
            }
            .onEnded { _ in
                liftTask?.cancel()
                let tapped = !lifted && !cancelled && !editing
                if lifted { onCommit() }
                pressed = false
                lifted = false
                touchActive = false
                dragStartCenter = nil
                if tapped { onTap() }
            }
    }
}
