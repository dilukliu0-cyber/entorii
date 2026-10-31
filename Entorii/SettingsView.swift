import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var stickers: StickerStore
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var confirmReset = false
    @State private var confirmDeleteAll = false
    @State private var shakes: [String: CGFloat] = [:]
    @State private var warning: String?
    @State private var addFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) {
                        leftColumn.frame(minWidth: 340, maxWidth: .infinity)
                        rightColumn.frame(minWidth: 340, maxWidth: .infinity)
                    }
                    VStack(spacing: 0) {
                        leftColumn
                        rightColumn
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .modifier(PageSizing())
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    if let data, stickers.add(data) { Haptics.tap() } else { addFailed = true }
                    pickerItem = nil
                }
            }
        }
        .alert("Сбросить настройки?", isPresented: $confirmReset) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) { settings.reset() }
        } message: {
            Text("Тема, кана, рука, разметка и места кнопок вернутся к исходным. Стикеры останутся.")
        }
        .alert("Удалить все стикеры?", isPresented: $confirmDeleteAll) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) { stickers.removeAll() }
        } message: {
            Text("Картинки исчезнут с главного экрана.")
        }
        .alert("Не удалось добавить картинку", isPresented: $addFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: колонки

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("Тема") {
                Segmented(options: [(Theme.light, "Светлая", "sun.max"), (Theme.dark, "Тёмная", "moon.fill")],
                          selection: Binding(get: { settings.data.theme }, set: { settings.data.theme = $0 }))
            }
            section("Рука") {
                Segmented(options: [(Hand.right, "Правша", nil), (Hand.left, "Левша", nil)],
                          selection: Binding(get: { settings.data.hand }, set: { settings.data.hand = $0 }))
            }
            section("Разметка поля") {
                HStack(spacing: 10) {
                    ForEach(GridStyle.allCases) { g in
                        Button {
                            settings.data.grid = g
                        } label: {
                            VStack(spacing: 6) {
                                GridBackground(style: g, scale: 0.3)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(settings.data.grid == g ? Color.primary : Color.clear, lineWidth: 2.5))
                                Text(g.title)
                                    .font(.caption)
                                    .foregroundStyle(settings.data.grid == g ? Color.primary : Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            section("Стикеры") { stickerSection }
            Button { confirmReset = true } label: {
                Text("Сбросить настройки")
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 22)
            about
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Script.allCases) { script in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(script.title.uppercased()).font(.footnote).foregroundStyle(.secondary)
                        Text(script.symbol).font(KanaFont.answer(15))
                    }
                    .padding(.leading, 14)
                    VStack(spacing: 6) {
                        ForEach(script.categories) { cat in categoryRow(cat, script) }
                    }
                }
                .padding(.bottom, 22)
            }
        }
    }

    // MARK: части

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.footnote).foregroundStyle(.secondary).padding(.leading, 14)
            content()
        }
        .padding(.bottom, 22)
    }

    private func categoryRow(_ cat: KanaCategory, _ script: Script) -> some View {
        let key = script.rawValue + cat.rawValue
        let on = settings.isOn(cat, script)
        let locked = settings.isLocked(cat, script)
        return Button {
            switch settings.toggle(cat, in: script) {
            case .changed:
                Haptics.tap()
            case .lastBasic:
                Haptics.warn()
                warning = key
                withAnimation(.linear(duration: 0.4)) { shakes[key, default: 0] += 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if warning == key { warning = nil } }
            case .locked:
                break
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(on ? Color.primary : Color(.systemGray3), lineWidth: 2)
                    if on {
                        Circle().fill(Color.primary)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(.systemBackground))
                    }
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(cat.title).font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(on ? Color.primary : Color(.systemGray2))
                    Text(warning == key ? "нужна хотя бы одна азбука" : cat.subtitle(script))
                        .font(.caption)
                        .foregroundStyle(on ? Color.secondary : Color(.systemGray2))
                }
                Spacer(minLength: 8)
                Text(cat.sample(script))
                    .font(KanaFont.answer(19))
                    .foregroundStyle(on ? Color.primary : Color(.systemGray2))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(on ? Color(.secondarySystemGroupedBackground) : Color(.systemGray5),
                        in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.45 : 1)
        .modifier(Shake(animatableData: shakes[key] ?? 0))
        .animation(.easeInOut(duration: 0.2), value: on)
    }

    private var stickerSection: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(stickers.items) { st in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let img = stickers.image(st) {
                                Image(uiImage: img).resizable().scaledToFit().padding(6)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        Button {
                            withAnimation { stickers.remove(st.id) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.white, Color(.systemGray))
                        }
                        .offset(x: 7, y: -7)
                        .accessibilityLabel("Удалить стикер")
                    }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                }
                .accessibilityLabel("Добавить из «Фото»")
            }
            .padding(12)
            if stickers.items.isEmpty {
                Text("Добавьте картинку из «Фото» — она появится в свободной зоне.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
            Divider()
            Button { confirmDeleteAll = true } label: {
                Text("Удалить все стикеры")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .foregroundStyle(stickers.items.isEmpty ? Color(.systemGray3) : Color.red)
            .disabled(stickers.items.isEmpty)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var about: some View {
        HStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Entorii").font(.headline)
                Text("円鳥居 · без аккаунта, без сети, без статистики").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}

/// Сегментный переключатель как в iOS, но с иконками.
struct Segmented<T: Hashable>: View {
    let options: [(T, String, String?)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options.indices, id: \.self) { i in
                let o = options[i]
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = o.0 }
                    Haptics.tap()
                } label: {
                    HStack(spacing: 6) {
                        if let icon = o.2 { Image(systemName: icon) }
                        Text(o.1)
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selection == o.0 {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// На iPad (iOS 18+) — широкий лист, чтобы влезли две колонки.
struct PageSizing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}
