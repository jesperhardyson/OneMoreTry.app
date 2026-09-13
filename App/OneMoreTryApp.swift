import SwiftUI

@main
struct OneMoreTryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .persistentSystemOverlays(.hidden)
                .statusBarHidden()
        }
    }
}
