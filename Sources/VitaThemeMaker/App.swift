import SwiftUI
import AppKit

@main
struct VitaThemeMakerApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let logo = Bundle.module.image(forResource: "Logo") {
            NSApplication.shared.applicationIconImage = logo
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 1020, minHeight: 660)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
