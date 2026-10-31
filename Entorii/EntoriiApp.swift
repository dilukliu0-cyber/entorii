import SwiftUI

@main
struct EntoriiApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var stickers = StickerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(stickers)
                .preferredColorScheme(settings.data.theme == .dark ? .dark : .light)
                .persistentSystemOverlays(.hidden)
        }
    }
}
