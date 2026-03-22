import SwiftUI

struct ReportsView: View {
    @StateObject private var viewModel = ReportsViewModel()
    @State private var selectedReport: ReportType?
    @State private var isGenerating = false

    enum ReportType: String, CaseIterable {
        case personalPortfolio = "محفظة شخصية"
        case fundSummary = "ملخص الصندوق"
        case zakatReport = "تقرير الزكاة"
        case dividends = "توزيعات الأرباح"
        case loans = "القروض"
        case transactions = "سجل العمليات"

        var icon: String {
            switch self {
            case .personalPortfolio: return "briefcase.fill"
            case .fundSummary: return "person.3.fill"
            case .zakatReport: return "moon.stars.fill"
            case .dividends: return "dollarsign.circle.fill"
            case .loans: return "banknote.fill"
            case .transactions: return "list.bullet.rectangle"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("اختر نوع التقرير")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            ReportTypeCard(type: type, isSelected: selectedReport == type) {
                                selectedReport = type
                            }
                        }
                    }
                    .padding(.horizontal)

                    if let selected = selectedReport {
                        VStack(spacing: 12) {
                            Text("خيارات التصدير")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                ExportButton(title: "PDF", icon: "doc.fill", color: .red) {
                                    generateReport(type: selected, format: .pdf)
                                }

                                ExportButton(title: "Excel", icon: "tablecells.fill", color: .green) {
                                    generateReport(type: selected, format: .csv)
                                }

                                ExportButton(title: "مشاركة", icon: "square.and.arrow.up", color: .blue) {
                                    generateReport(type: selected, format: .share)
                                }
                            }
                        }
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    if isGenerating {
                        HStack {
                            ProgressView().tint(.appGold)
                            Text("جاري توليد التقرير...")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("التقارير")
        }
    }

    private func generateReport(type: ReportType, format: ExportFormat) {
        isGenerating = true
        Task {
            let url: URL?
            switch type {
            case .personalPortfolio:
                url = ExportService.shared.generatePortfolioReport(
                    summary: viewModel.portfolioSummary,
                    transactions: viewModel.transactions
                )
            case .zakatReport:
                url = ExportService.shared.generateZakatReport(calculations: viewModel.zakatCalculations)
            default:
                url = ExportService.shared.generateCSV(
                    transactions: viewModel.transactions,
                    filename: type.rawValue
                )
            }

            await MainActor.run {
                isGenerating = false
                if let url = url, format == .share {
                    shareURL(url)
                }
            }
        }
    }

    private func shareURL(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Report Type Card
struct ReportTypeCard: View {
    let type: ReportsView.ReportType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .appDarkBlue : .appGold)
                Text(type.rawValue)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? .appDarkBlue : .white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.appGold : Color.appCardBg)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.appGold : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Export Button
struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

enum ExportFormat { case pdf, csv, share }

class ReportsViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var portfolioSummary = PortfolioSummary(totalCurrentValue: 0, totalDeposits: 0, totalWithdrawals: 0, realizedPnL: 0, unrealizedPnL: 0, cashBalance: 0, totalDividends: 0, totalFees: 0)
    @Published var zakatCalculations: [ZakatCalculation] = []
}
