import Foundation

/// Выдача слов: вес единицы = базовый вес / (1 + счётчик показов в этом запуске),
/// вес слова = среднее по его единицам, выбор рулеткой, без повторов в окне последних 5 слов.
/// Счётчики живут только в памяти и пропадают при закрытии приложения.
final class WordPicker {
    private var counts: [String: Int] = [:]
    private var recent: [Int] = []

    func next(from allowed: [Word], current: Word?) -> Word? {
        guard !allowed.isEmpty else { return nil }
        let window = allowed.count < 6 ? 1 : 5
        let blocked = Set(recent.suffix(window))
        var pool = allowed.filter { !blocked.contains($0.id) }
        if pool.isEmpty { pool = allowed.filter { $0.id != current?.id } }
        if pool.isEmpty { pool = allowed }

        let weights = pool.map(weight)
        let total = weights.reduce(0, +)
        var pick = pool[pool.count - 1]
        if total > 0 {
            var r = Double.random(in: 0..<total)
            for (i, w) in weights.enumerated() {
                if r < w { pick = pool[i]; break }
                r -= w
            }
        } else if let any = pool.randomElement() {
            pick = any
        }

        recent.append(pick.id)
        if recent.count > 5 { recent.removeFirst(recent.count - 5) }
        for u in pick.units { counts[u.text, default: 0] += 1 }
        return pick
    }

    private func weight(_ w: Word) -> Double {
        guard !w.units.isEmpty else { return 0 }
        let sum = w.units.reduce(0.0) { $0 + $1.weight / Double(1 + (counts[$1.text] ?? 0)) }
        return sum / Double(w.units.count)
    }
}
