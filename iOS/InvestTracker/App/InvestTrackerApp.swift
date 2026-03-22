import SwiftUI

@main
struct InvestTrackerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var databaseManager = DatabaseManager.shared
    @StateObject private var priceService = PriceService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(databaseManager)
                .environmentObject(priceService)
                .onAppear {
                    setupApp()
                }
        }
    }

    private func setupApp() {
        databaseManager.initialize()
        priceService.startAutoUpdate()
        NotificationManager.shared.requestPermission()
    }
}
