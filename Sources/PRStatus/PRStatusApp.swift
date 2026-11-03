import SwiftUI

@main
struct PRStatusApp: App {
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        model.startPolling()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
                .accessibilityLabel("Cosine pull request status")
        }
        .menuBarExtraStyle(.window)
    }
}
