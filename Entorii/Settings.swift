import SwiftUI

enum Theme: String, Codable { case light, dark }
enum Hand: String, Codable { case right, left }
enum GridStyle: String, Codable, CaseIterable, Identifiable {
    case clean, dots, squares, genko
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clean: return "чистая"
        case .dots: return "в точку"
        case .squares: return "в клетку"
        case .genko: return "для каны"
        }
    }
}

/// Место элемента в свободной зоне: центр в долях зоны, размер в точках (nil — по умолчанию).
struct Placement: Codable, Equatable {
    var cx: Double
    var cy: Double
    var size: Double?
}

struct SettingsData: Codable, Equatable {
    var theme: Theme = .light
    var hand: Hand = .right
    var grid: GridStyle = .clean
    var hiragana: Set<KanaCategory> = [.basic]
    var katakana: Set<KanaCategory> = []
    var circle = SettingsData.defaultCircle
    var tool = SettingsData.defaultTool

    static let defaultCircle = Placement(cx: 0.5, cy: 0.26, size: nil)
    static let defaultTool = Placement(cx: 0.5, cy: 0.46, size: nil)
}

enum ToggleResult { case changed, locked, lastBasic }

/// Все настройки и места кнопок. Хранятся локально в UserDefaults; данных практики здесь нет.
final class AppSettings: ObservableObject {
    @Published var data: SettingsData {
        didSet { save() }
    }

    private static let key = "entorii.settings.v1"

    init() {
        var loaded = SettingsData()
        if let raw = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: raw) {
            loaded = decoded
        }
        // Хотя бы один Basic включён всегда.
        if !loaded.hiragana.contains(.basic) && !loaded.katakana.contains(.basic) {
            loaded.hiragana.insert(.basic)
        }
        data = loaded
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: Self.key)
        }
    }

    func categories(_ s: Script) -> Set<KanaCategory> {
        s == .hiragana ? data.hiragana : data.katakana
    }

    /// Basic — главный переключатель азбуки: без него остальные категории считаются выключенными.
    func activeCategories(_ s: Script) -> Set<KanaCategory> {
        let set = categories(s)
        return set.contains(.basic) ? set : []
    }

    func isOn(_ c: KanaCategory, _ s: Script) -> Bool {
        activeCategories(s).contains(c)
    }

    func isLocked(_ c: KanaCategory, _ s: Script) -> Bool {
        c != .basic && !categories(s).contains(.basic)
    }

    func toggle(_ c: KanaCategory, in s: Script) -> ToggleResult {
        var set = categories(s)
        if isLocked(c, s) { return .locked }
        if c == .basic && set.contains(.basic) && !categories(s.other).contains(.basic) { return .lastBasic }
        if set.contains(c) { set.remove(c) } else { set.insert(c) }
        if s == .hiragana { data.hiragana = set } else { data.katakana = set }
        return .changed
    }

    /// Слово допускается, если все его единицы из включённых категорий активной азбуки.
    func allowedWords() -> [Word] {
        let on: [Script: Set<KanaCategory>] = [.hiragana: activeCategories(.hiragana), .katakana: activeCategories(.katakana)]
        return Words.all.filter { w in
            guard let set = on[w.script], !set.isEmpty else { return false }
            return w.categories.isSubset(of: set)
        }
    }

    func reset() {
        data = SettingsData()
    }
}
