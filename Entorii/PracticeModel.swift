import SwiftUI

/// Состояние экрана практики. Ничего из этого не сохраняется.
final class PracticeModel: ObservableObject {
    @Published var current: Word?
    @Published var revealed = false
    @Published var clearing = false
    @Published var tool: WritingTool = .pen
    @Published var editingID: String?

    let canvas = CanvasController()
    private let picker = WordPicker()
    private var busy = false

    init() {
        canvas.onBegin = { [weak self] in
            DispatchQueue.main.async { self?.editingID = nil }
        }
    }

    func start(_ settings: AppSettings) {
        if current == nil { current = picker.next(from: settings.allowedWords(), current: nil) }
    }

    func tapCircle(_ settings: AppSettings) {
        if revealed {
            advance(settings)
        } else {
            Haptics.reveal()
            withAnimation(.easeOut(duration: 0.55)) { revealed = true }
        }
    }

    /// Следующее слово: спойлер возвращается, поле плавно очищается, кружок пустеет.
    func advance(_ settings: AppSettings) {
        guard !busy else { return }
        busy = true
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.3)) {
            revealed = false
            clearing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self else { return }
            self.canvas.clear()
            withAnimation(.easeOut(duration: 0.25)) {
                self.current = self.picker.next(from: settings.allowedWords(), current: self.current)
                self.clearing = false
            }
            self.busy = false
        }
    }

    func toggleTool() {
        Haptics.tap()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
            tool = tool == .pen ? .eraser : .pen
        }
    }

    /// После смены категорий: если текущее слово больше не допускается — сразу новое.
    func validate(_ settings: AppSettings) {
        guard let c = current else { start(settings); return }
        if !settings.allowedWords().contains(where: { $0.id == c.id }) { advance(settings) }
    }
}
