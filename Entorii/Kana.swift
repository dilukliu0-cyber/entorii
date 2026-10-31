import Foundation

enum Script: String, Codable, CaseIterable, Identifiable {
    case hiragana, katakana

    var id: String { rawValue }
    var symbol: String { self == .hiragana ? "あ" : "ア" }
    var title: String { self == .hiragana ? "Хирагана" : "Катакана" }
    var other: Script { self == .hiragana ? .katakana : .hiragana }

    var categories: [KanaCategory] {
        switch self {
        case .hiragana: return [.basic, .dakuten, .yoon, .small, .rare]
        case .katakana: return [.basic, .dakuten, .yoon, .small, .long, .special, .rare]
        }
    }
}

enum KanaCategory: String, Codable, CaseIterable, Identifiable {
    case basic, dakuten, yoon, small, long, special, rare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "Basic"
        case .dakuten: return "Dakuten"
        case .yoon: return "Yoon"
        case .small: return "Small"
        case .long: return "Long"
        case .special: return "Special"
        case .rare: return "Rare"
        }
    }

    func subtitle(_ s: Script) -> String {
        switch self {
        case .basic: return "базовые 46"
        case .dakuten: return "дакутэн и хандакутэн"
        case .yoon: return s == .hiragana ? "с маленькими ゃゅょ" : "с маленькими ャュョ"
        case .small: return s == .hiragana ? "маленькие ぁぃぅぇぉ и っ" : "маленькие ァィゥェォ и ッ"
        case .long: return "долгота"
        case .special: return "для заимствованных слов"
        case .rare: return "устаревшие"
        }
    }

    func sample(_ s: Script) -> String {
        let h = s == .hiragana
        switch self {
        case .basic: return h ? "あ か さ" : "ア カ サ"
        case .dakuten: return h ? "が ぱ" : "ガ パ"
        case .yoon: return h ? "きゃ しゅ" : "キャ シュ"
        case .small: return h ? "っ ぁ" : "ッ ァ"
        case .long: return "ー"
        case .special: return "ファ ティ ヴ"
        case .rare: return h ? "ゐ ゑ" : "ヰ ヱ"
        }
    }
}

/// Единица написания: обычная кана, кана с дакутэном, ёон целиком, маленькая кана, ー или особое сочетание.
struct KanaUnit: Hashable {
    let text: String
    let category: KanaCategory
    let weight: Double
}

enum KanaTokenizer {
    private static let smallY: Set<Character> = ["ゃ", "ゅ", "ょ", "ャ", "ュ", "ョ"]
    private static let smallV: Set<Character> = ["ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ァ", "ィ", "ゥ", "ェ", "ォ"]
    private static let yoonBase: Set<Character> = Set("きしちにひみりぎじびぴぢ")
    private static let dakuten: Set<Character> = Set("がぎぐげござじずぜぞだぢづでどばびぶべぼ")
    private static let handakuten: Set<Character> = Set("ぱぴぷぺぽ")
    private static let rare: Set<Character> = ["ゐ", "ゑ"]
    private static let weight3Basic: Set<Character> = Set("やゆよわを")
    private static let specials: Set<String> = [
        "ファ", "フィ", "フェ", "フォ", "フュ",
        "ウィ", "ウェ", "ウォ",
        "ティ", "ディ", "トゥ", "ドゥ", "テュ", "デュ",
        "ヴァ", "ヴィ", "ヴェ", "ヴォ", "ヴュ",
        "シェ", "ジェ", "チェ",
        "ツァ", "ツィ", "ツェ", "ツォ",
        "イェ", "クァ", "クィ", "クェ", "クォ", "グァ", "スィ", "ズィ"
    ]

    /// Катакана → хирагана (для таблиц весов и категорий).
    static func toHiragana(_ c: Character) -> Character {
        guard c.unicodeScalars.count == 1,
              let s = c.unicodeScalars.first,
              (0x30A1...0x30F6).contains(s.value),
              let h = Unicode.Scalar(s.value - 0x60) else { return c }
        return Character(h)
    }

    static func units(_ word: String, script: Script) -> [KanaUnit] {
        let ch = Array(word)
        var out: [KanaUnit] = []
        var i = 0
        while i < ch.count {
            let c = ch[i]
            let n: Character? = i + 1 < ch.count ? ch[i + 1] : nil
            let h = toHiragana(c)
            if c == " " { i += 1; continue }
            if let n, smallY.contains(n), yoonBase.contains(h) {
                out.append(KanaUnit(text: String([c, n]), category: .yoon, weight: 2)); i += 2; continue
            }
            if script == .katakana, let n, specials.contains(String([c, n])) {
                out.append(KanaUnit(text: String([c, n]), category: .special, weight: 1)); i += 2; continue
            }
            let unit: KanaUnit
            if c == "ヴ" {
                unit = KanaUnit(text: String(c), category: .special, weight: 1)
            } else if c == "ー" {
                unit = KanaUnit(text: String(c), category: .long, weight: 3)
            } else if h == "っ" {
                unit = KanaUnit(text: String(c), category: .small, weight: 4)
            } else if smallV.contains(c) {
                unit = KanaUnit(text: String(c), category: .small, weight: 2)
            } else if rare.contains(h) {
                unit = KanaUnit(text: String(c), category: .rare, weight: 1)
            } else if handakuten.contains(h) {
                unit = KanaUnit(text: String(c), category: .dakuten, weight: 2)
            } else if dakuten.contains(h) {
                unit = KanaUnit(text: String(c), category: .dakuten, weight: 3)
            } else {
                unit = KanaUnit(text: String(c), category: .basic, weight: weight3Basic.contains(h) ? 3 : 4)
            }
            out.append(unit)
            i += 1
        }
        return out
    }
}
