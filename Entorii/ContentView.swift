import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var stickers: StickerStore
    @StateObject private var model = PracticeModel()
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 700 || geo.size.height < 500
            let pad: CGFloat = compact ? 12 : 28
            let gap: CGFloat = compact ? 10 : 22
            let zoneW = min(200, max(96, geo.size.width * 0.17))
            let gearSize: CGFloat = 44
            let left = settings.data.hand == .left

            HStack(spacing: gap) {
                if left {
                    mainColumn(compact: compact, gap: gap, leadingInset: gearSize + 8)
                    freeZone(width: zoneW, blocked: .zero, compact: compact)
                } else {
                    freeZone(width: zoneW, blocked: CGRect(x: 0, y: 0, width: gearSize + 8, height: gearSize + 8), compact: compact)
                    mainColumn(compact: compact, gap: gap, leadingInset: 0)
                }
            }
            .padding(pad)
            .overlay(alignment: .topLeading) {
                Button {
                    model.editingID = nil
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Color.primary)
                        .frame(width: gearSize, height: gearSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Настройки")
                .padding(pad)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(stickers)
                .preferredColorScheme(settings.data.theme == .dark ? .dark : .light)
        }
        .onAppear { model.start(settings) }
        .onChange(of: [settings.data.hiragana, settings.data.katakana]) { _, _ in model.validate(settings) }
    }

    // MARK: подсказка, ответ, поле

    private func mainColumn(compact: Bool, gap: CGFloat, leadingInset: CGFloat) -> some View {
        let radius: CGFloat = compact ? 12 : 18
        let topH: CGFloat = compact ? 64 : 120
        return VStack(spacing: gap) {
            HStack(spacing: compact ? 8 : 16) {
                Text(model.current?.script.symbol ?? "あ")
                    .font(KanaFont.answer(compact ? 32 : 60))
                    .foregroundStyle(Color.primary)
                    .frame(width: compact ? 40 : 84)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: model.current?.script)

                ZStack {
                    Text(model.current?.romaji ?? "")
                        .font(.system(size: compact ? 26 : 48, weight: .semibold, design: .rounded))
                        .tracking(compact ? 1 : 3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .padding(.horizontal, compact ? 8 : 16)
                        .id(model.current?.id ?? -1)
                        .transition(.opacity.combined(with: .offset(y: -8)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.primary, lineWidth: 2))

                ZStack {
                    Text(model.current?.kana ?? "")
                        .font(KanaFont.answer(compact ? 28 : 56))
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .padding(.horizontal, compact ? 8 : 16)
                        .opacity(model.revealed ? 1 : 0)
                        .blur(radius: model.revealed ? 0 : 12)
                        .scaleEffect(model.revealed ? 1 : 0.96)
                    SpoilerView(paused: model.revealed)
                        .opacity(model.revealed ? 0 : 1)
                        .scaleEffect(model.revealed ? 1.25 : 1)
                        .blur(radius: model.revealed ? 3 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.primary, lineWidth: 2))
            }
            .frame(height: topH)
            .padding(.leading, leadingInset)

            ZStack {
                GridBackground(style: settings.data.grid)
                WritingCanvas(controller: model.canvas, tool: model.tool)
                    .opacity(model.clearing ? 0 : 1)
                    .blur(radius: model.clearing ? 6 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 22))
            .overlay(RoundedRectangle(cornerRadius: compact ? 14 : 22).strokeBorder(Color.primary, lineWidth: compact ? 2.5 : 3))
        }
    }

    // MARK: свободная зона

    private func freeZone(width: CGFloat, blocked: CGRect, compact: Bool) -> some View {
        GeometryReader { z in
            let zone = z.size
            let defaultSize = min(96, max(56, zone.width * 0.72))
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.editingID = nil }

                ForEach(stickers.items) { st in
                    FloatingItem(id: st.id.uuidString, placement: st.place, defaultSize: defaultSize, zone: zone,
                                 blocked: blocked, round: false, editingID: $model.editingID,
                                 onChange: { stickers.setPlacement(st.id, $0) },
                                 onCommit: { stickers.commit() }) { _ in
                        if let img = stickers.image(st) {
                            Image(uiImage: img).resizable().scaledToFit()
                        } else {
                            Color.clear
                        }
                    }
                }

                FloatingItem(id: "tool", placement: settings.data.tool, defaultSize: defaultSize, zone: zone,
                             blocked: blocked, round: true, editingID: $model.editingID,
                             onTap: { model.toggleTool() },
                             onChange: { settings.data.tool = $0 }) { s in
                    ToolButtonFace(tool: model.tool, size: s)
                }

                FloatingItem(id: "circle", placement: settings.data.circle, defaultSize: defaultSize, zone: zone,
                             blocked: blocked, round: true, editingID: $model.editingID,
                             onTap: { model.tapCircle(settings) },
                             onChange: { settings.data.circle = $0 }) { s in
                    AnswerCircle(filled: model.revealed, size: s)
                }

                if model.editingID != nil {
                    VStack {
                        Spacer()
                        Button("Готово") {
                            withAnimation { model.editingID = nil }
                        }
                        .font(.system(size: compact ? 14 : 16, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                    .transition(.opacity)
                }
            }
            .coordinateSpace(name: "zone")
        }
        .frame(width: width)
    }
}

/// Пружинистое сжатие при нажатии.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
