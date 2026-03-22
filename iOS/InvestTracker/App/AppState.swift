import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var selectedTab: AppTab = .dashboard
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    enum AppTab: Int, CaseIterable {
        case dashboard = 0
        case portfolio = 1
        case funds = 2
        case zakat = 3
        case loans = 4
        case reports = 5
        case settings = 6

        var title: String {
            switch self {
            case .dashboard: return "لوحة المعلومات"
            case .portfolio: return "المحفظة"
            case .funds: return "الصناديق"
            case .zakat: return "الزكاة"
            case .loans: return "القروض"
            case .reports: return "التقارير"
            case .settings: return "الإعدادات"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .portfolio: return "briefcase.fill"
            case .funds: return "person.3.fill"
            case .zakat: return "moon.stars.fill"
            case .loans: return "dollarsign.circle.fill"
            case .reports: return "doc.text.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    func showError(_ message: String) {
        errorMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.errorMessage = nil
        }
    }

    func showSuccess(_ message: String) {
        successMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }
}
