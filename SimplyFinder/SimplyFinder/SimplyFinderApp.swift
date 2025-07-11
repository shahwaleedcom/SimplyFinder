import SwiftUI

@main
struct SimplyFinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, CoreDataStack.shared.ctx)
                .tint(Color("AccentColor"))
        }
    }
}
