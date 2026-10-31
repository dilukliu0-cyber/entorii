import SwiftUI
import UIKit

struct Sticker: Codable, Identifiable, Equatable {
    let id: UUID
    let file: String
    var place: Placement
}

/// Стикеры — только картинки пользователя из «Фото». Файлы лежат в Application Support/stickers.
final class StickerStore: ObservableObject {
    @Published private(set) var items: [Sticker] = []
    private var cache: [UUID: UIImage] = [:]
    private let dir: URL
    private var listURL: URL { dir.appendingPathComponent("stickers.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        dir = base.appendingPathComponent("stickers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let raw = try? Data(contentsOf: listURL),
           let list = try? JSONDecoder().decode([Sticker].self, from: raw) {
            items = list.filter { FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.file).path) }
        }
    }

    func image(_ s: Sticker) -> UIImage? {
        if let img = cache[s.id] { return img }
        let img = UIImage(contentsOfFile: dir.appendingPathComponent(s.file).path)
        if let img { cache[s.id] = img }
        return img
    }

    /// Добавляет картинку: уменьшает до 600 px по длинной стороне и сохраняет PNG.
    @discardableResult
    func add(_ data: Data) -> Bool {
        guard let src = UIImage(data: data) else { return false }
        let maxSide: CGFloat = 600
        let scale = min(1, maxSide / max(src.size.width, src.size.height, 1))
        let size = CGSize(width: max(1, src.size.width * scale), height: max(1, src.size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            src.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let png = img.pngData() else { return false }
        let id = UUID()
        let file = id.uuidString + ".png"
        do {
            try png.write(to: dir.appendingPathComponent(file), options: .atomic)
        } catch {
            return false
        }
        let slot = Double(items.count % 4)
        items.append(Sticker(id: id, file: file, place: Placement(cx: 0.5, cy: 0.84 - slot * 0.06, size: nil)))
        cache[id] = img
        save()
        return true
    }

    func remove(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(items[i].file))
        cache[id] = nil
        items.remove(at: i)
        save()
    }

    func removeAll() {
        for s in items { try? FileManager.default.removeItem(at: dir.appendingPathComponent(s.file)) }
        cache.removeAll()
        items.removeAll()
        save()
    }

    func placement(_ id: UUID) -> Placement {
        items.first(where: { $0.id == id })?.place ?? Placement(cx: 0.5, cy: 0.8, size: nil)
    }

    /// Меняет место без записи на диск (во время перетаскивания); запись — в commit().
    func setPlacement(_ id: UUID, _ p: Placement) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].place = p
    }

    func commit() { save() }

    private func save() {
        if let raw = try? JSONEncoder().encode(items) {
            try? raw.write(to: listURL, options: .atomic)
        }
    }
}
