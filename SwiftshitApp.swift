import SwiftUI

@main
struct SwiftshitApp: App {
    @StateObject private var viewModel = MusicPlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
    }
}
