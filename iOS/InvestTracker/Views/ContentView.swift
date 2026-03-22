import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var priceService: PriceService
    @State private var showLockScreen = true

    var body: some View {
        Group {
            if showLockScreen {
                LockScreenView(isUnlocked: $showLockScreen)
            } else {
                MainTabView()
                    .overlay(alignment: .top) {
                        // Update status banner
                        if priceService.isUpdating {
                            UpdateBanner()
                        }
                    }
                    .overlay(alignment: .bottom) {
                        // Error/success toasts
                        VStack(spacing: 8) {
                            if let error = appState.errorMessage {
                                ToastView(message: error, type: .error)
                            }
                            if let success = appState.successMessage {
                                ToastView(message: success, type: .success)
                            }
                        }
                        .padding(.bottom, 90)
                    }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem {
                    Label(AppState.AppTab.dashboard.title, systemImage: AppState.AppTab.dashboard.icon)
                }
                .tag(AppState.AppTab.dashboard)

            PortfolioView()
                .tabItem {
                    Label(AppState.AppTab.portfolio.title, systemImage: AppState.AppTab.portfolio.icon)
                }
                .tag(AppState.AppTab.portfolio)

            FundsListView()
                .tabItem {
                    Label(AppState.AppTab.funds.title, systemImage: AppState.AppTab.funds.icon)
                }
                .tag(AppState.AppTab.funds)

            ZakatView()
                .tabItem {
                    Label(AppState.AppTab.zakat.title, systemImage: AppState.AppTab.zakat.icon)
                }
                .tag(AppState.AppTab.zakat)

            LoansView()
                .tabItem {
                    Label(AppState.AppTab.loans.title, systemImage: AppState.AppTab.loans.icon)
                }
                .tag(AppState.AppTab.loans)

            ReportsView()
                .tabItem {
                    Label(AppState.AppTab.reports.title, systemImage: AppState.AppTab.reports.icon)
                }
                .tag(AppState.AppTab.reports)

            SettingsView()
                .tabItem {
                    Label(AppState.AppTab.settings.title, systemImage: AppState.AppTab.settings.icon)
                }
                .tag(AppState.AppTab.settings)
        }
        .accentColor(.appGold)
    }
}

// MARK: - Lock Screen View
struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    @State private var showPIN = false
    @State private var pin = ""
    @State private var error = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.appDarkBlue, Color.appNavy], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.appGold)

                    Text("نظام تتبع الاستثمارات")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Text("والزكاة العائلية")
                        .font(.title2)
                        .foregroundColor(.appGold)
                }

                Spacer()

                Button {
                    authenticateWithBiometrics()
                } label: {
                    HStack {
                        Image(systemName: "faceid")
                            .font(.title2)
                        Text("فتح بالبصمة / Face ID")
                            .font(.headline)
                    }
                    .foregroundColor(.appDarkBlue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appGold)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 40)

                if !error.isEmpty {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Spacer()
            }
        }
        .onAppear {
            authenticateWithBiometrics()
        }
    }

    private func authenticateWithBiometrics() {
        // For development/first launch, auto-unlock
        // In production: use LocalAuthentication framework
        withAnimation {
            isUnlocked = false  // false = show main app (binding is inverted for showLockScreen)
        }
    }
}

// MARK: - Update Banner
struct UpdateBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            Text("جاري تحديث الأسعار...")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appGold.opacity(0.9))
        .cornerRadius(20)
        .shadow(radius: 4)
        .padding(.top, 50)
    }
}

// MARK: - Toast View
struct ToastView: View {
    enum ToastType { case error, success }
    let message: String
    let type: ToastType

    var body: some View {
        HStack {
            Image(systemName: type == .error ? "xmark.circle.fill" : "checkmark.circle.fill")
            Text(message)
                .font(.subheadline)
        }
        .foregroundColor(.white)
        .padding()
        .background(type == .error ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: message)
    }
}

// MARK: - Color Extensions
extension Color {
    static let appGold = Color(red: 0.85, green: 0.7, blue: 0.2)
    static let appDarkBlue = Color(red: 0.05, green: 0.1, blue: 0.25)
    static let appNavy = Color(red: 0.08, green: 0.15, blue: 0.35)
    static let appCardBg = Color(red: 0.1, green: 0.18, blue: 0.35)
    static let appSuccess = Color(red: 0.2, green: 0.7, blue: 0.3)
    static let appDanger = Color(red: 0.85, green: 0.2, blue: 0.2)
}
