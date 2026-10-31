import SwiftUI
import PencilKit

enum WritingTool { case pen, eraser }

/// Держит ссылку на холст PencilKit, чтобы очищать его и менять инструмент из модели.
final class CanvasController {
    weak var view: PKCanvasView?
    var onBegin: (() -> Void)?
    private var applied: WritingTool?

    func clear() {
        view?.drawing = PKDrawing()
    }

    func apply(_ tool: WritingTool) {
        guard let view, applied != tool else { return }
        applied = tool
        switch tool {
        case .pen: view.tool = PKInkingTool(.pen, color: .black, width: 7)
        case .eraser: view.tool = PKEraserTool(.bitmap)
        }
    }

    func reattach(_ v: PKCanvasView) {
        view = v
        applied = nil
    }
}

/// Прозрачный холст: на iPad пишет и Apple Pencil, и палец; на iPhone — палец.
/// Чёрные чернила PencilKit сам показывает белыми в тёмной теме.
struct WritingCanvas: UIViewRepresentable {
    let controller: CanvasController
    let tool: WritingTool

    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.drawingPolicy = .anyInput
        v.isScrollEnabled = false
        v.showsVerticalScrollIndicator = false
        v.showsHorizontalScrollIndicator = false
        v.delegate = context.coordinator
        controller.reattach(v)
        controller.apply(tool)
        return v
    }

    func updateUIView(_ v: PKCanvasView, context: Context) {
        if controller.view !== v { controller.reattach(v) }
        controller.apply(tool)
    }

    func makeCoordinator() -> Coordinator { Coordinator(controller) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let controller: CanvasController
        init(_ c: CanvasController) { controller = c }
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            controller.onBegin?()
        }
    }
}

/// Разметка поля для письма — фон под прозрачным холстом.
struct GridBackground: View {
    let style: GridStyle
    var scale: CGFloat = 1

    var body: some View {
        Canvas { ctx, size in
            let strong = Color(.systemGray3)
            let light = Color(.systemGray5)
            switch style {
            case .clean:
                break
            case .dots:
                let step = 28 * scale
                let r = max(1, 1.6 * scale)
                var x = step * 0.85
                while x < size.width {
                    var y = step * 0.85
                    while y < size.height {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(strong))
                        y += step
                    }
                    x += step
                }
            case .squares:
                let step = 32 * scale
                var p = Path()
                var x: CGFloat = 0.5
                while x < size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                var y: CGFloat = 0.5
                while y < size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                ctx.stroke(p, with: .color(Color(.systemGray4)), lineWidth: 1)
            case .genko:
                let s = scale < 1 ? size.width / 2.6 : max(64, min(150, size.height / 3.3))
                let pad = max(2, s * 0.04)
                let cols = max(1, Int((size.width - s * 0.25) / s))
                let rows = max(1, Int((size.height - s * 0.25) / s))
                let ox = (size.width - CGFloat(cols) * s) / 2
                let oy = (size.height - CGFloat(rows) * s) / 2
                var boxes = Path()
                var cross = Path()
                for i in 0..<cols {
                    for j in 0..<rows {
                        let r = CGRect(x: ox + CGFloat(i) * s + pad, y: oy + CGFloat(j) * s + pad, width: s - pad * 2, height: s - pad * 2)
                        boxes.addRect(r)
                        cross.move(to: CGPoint(x: r.midX, y: r.minY)); cross.addLine(to: CGPoint(x: r.midX, y: r.maxY))
                        cross.move(to: CGPoint(x: r.minX, y: r.midY)); cross.addLine(to: CGPoint(x: r.maxX, y: r.midY))
                    }
                }
                ctx.stroke(boxes, with: .color(strong), lineWidth: 1.5)
                let dash = max(3, 6 * scale)
                ctx.stroke(cross, with: .color(light), style: StrokeStyle(lineWidth: 1.2, dash: [dash, dash]))
            }
        }
        .allowsHitTesting(false)
    }
}
