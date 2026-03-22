import SwiftUI

struct PortfolioView: View {
    @StateObject private var viewModel = PortfolioViewModel()
    @State private var showAddTransaction = false
    @State private var selectedFilter: AssetType? = nil
    @State private var sortOrder: SortOrder = .valueDesc

    enum SortOrder: String, CaseIterable {
        case valueDesc = "القيمة (تنازلي)"
        case valueAsc = "القيمة (تصاعدي)"
        case pnlDesc = "الربح (تنازلي)"
        case alphabetical = "أبجدي"
    }

    var filteredHoldings: [HoldingDisplay] {
        var holdings = viewModel.holdings
        if let filter = selectedFilter {
            holdings = holdings.filter { $0.assetType == filter.rawValue }
        }
        switch sortOrder {
        case .valueDesc: return holdings.sorted { $0.currentValue > $1.currentValue }
        case .valueAsc: return holdings.sorted { $0.currentValue < $1.currentValue }
        case .pnlDesc: return holdings.sorted { $0.pnlPercent > $1.pnlPercent }
        case .alphabetical: return holdings.sorted { $0.symbol < $1.symbol }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary Header
                    PortfolioSummaryHeader(summary: viewModel.portfolioSummary)

                    // Filters & Sort
                    HStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "الكل", isSelected: selectedFilter == nil) {
                                    selectedFilter = nil
                                }
                                ForEach(AssetType.allCases, id: \.self) { type in
                                    FilterChip(title: type.displayName, isSelected: selectedFilter == type) {
                                        selectedFilter = type
                                    }
                                }
                            }
                        }

                        Menu {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    if sortOrder == order {
                                        Label(order.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(order.rawValue)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.appGold)
                        }
                    }
                    .padding(.horizontal)

                    // Holdings List
                    if filteredHoldings.isEmpty {
                        EmptyPortfolioView()
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredHoldings) { holding in
                                NavigationLink(destination: AssetDetailView(symbol: holding.symbol)) {
                                    AssetCard(holding: holding)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("المحفظة الشخصية")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.appGold)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(isPresented: $showAddTransaction) {
                    viewModel.loadData()
                }
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }
}

// MARK: - Portfolio Summary Header
struct PortfolioSummaryHeader: View {
    let summary: PortfolioSummary

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                SummaryItem(title: "القيمة الحالية", value: summary.totalCurrentValue.formattedSAR(), color: .white)
                Spacer()
                SummaryItem(title: "صافي الاستثمار", value: summary.totalInvested.formattedSAR(), color: .white)
            }

            HStack {
                SummaryItem(title: "محقق", value: summary.realizedPnL.formattedSAR(),
                           color: summary.realizedPnL >= 0 ? .appSuccess : .appDanger)
                Spacer()
                SummaryItem(title: "غير محقق", value: summary.unrealizedPnL.formattedSAR(),
                           color: summary.unrealizedPnL >= 0 ? .appSuccess : .appDanger)
            }
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
        }
    }
}

// MARK: - Asset Card
struct AssetCard: View {
    let holding: HoldingDisplay

    var body: some View {
        HStack(spacing: 12) {
            // Symbol circle
            ZStack {
                Circle()
                    .fill(Color.appGold.opacity(0.2))
                    .frame(width: 46, height: 46)
                Text(String(holding.symbol.prefix(3)))
                    .font(.caption.bold())
                    .foregroundColor(.appGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(holding.symbol)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(holding.name)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                Text("\(holding.shares.formatted()) وحدة")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(holding.currentValue.formattedSAR())
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                HStack(spacing: 3) {
                    Image(systemName: holding.pnlPercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(holding.pnlPercent.formattedPct())
                        .font(.caption)
                }
                .foregroundColor(holding.pnlPercent >= 0 ? .appSuccess : .appDanger)
                Text(holding.pnl.formattedSAR())
                    .font(.caption2)
                    .foregroundColor(holding.pnl >= 0 ? .appSuccess.opacity(0.7) : .appDanger.opacity(0.7))
            }
        }
        .padding(12)
        .background(Color.appCardBg)
        .cornerRadius(14)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appGold : Color.white.opacity(0.1))
                .foregroundColor(isSelected ? .appDarkBlue : .white)
                .cornerRadius(20)
        }
    }
}

// MARK: - Empty State
struct EmptyPortfolioView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "briefcase")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            Text("لا توجد ممتلكات بعد")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            Text("ابدأ بإضافة عملياتك الاستثمارية")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Portfolio View Model
class PortfolioViewModel: ObservableObject {
    @Published var holdings: [HoldingDisplay] = []
    @Published var portfolioSummary = PortfolioSummary(totalCurrentValue: 0, totalDeposits: 0, totalWithdrawals: 0, realizedPnL: 0, unrealizedPnL: 0, cashBalance: 0, totalDividends: 0, totalFees: 0)

    func loadData() {
        let db = DatabaseManager.shared
        let priceService = PriceService.shared

        let rows = db.query("""
            SELECT a.id, a.symbol, a.name, a.name_ar, a.type, a.currency,
                   SUM(h.shares_remaining) as total_shares,
                   SUM(h.shares_remaining * h.purchase_price) as total_cost
            FROM holdings h
            INNER JOIN assets a ON a.id = h.asset_id
            WHERE h.shares_remaining > 0
            GROUP BY a.id
        """)

        let usdSarRate = priceService.getUSDSARRate()

        let holdingsLoaded: [HoldingDisplay] = rows.compactMap { row in
            guard let symbol = row["symbol"] as? String,
                  let name = row["name"] as? String,
                  let currency = row["currency"] as? String,
                  let type = row["type"] as? String,
                  let shares = (row["total_shares"] as? Double).map({ Decimal($0) }),
                  let totalCost = (row["total_cost"] as? Double).map({ Decimal($0) }) else { return nil }

            let currentPrice = priceService.getPrice(symbol: symbol)?.price ?? 0
            let currentValue = shares * currentPrice
            let valueSAR = currency == "USD" ? currentValue * usdSarRate : currentValue
            let pnl = currentValue - (totalCost / shares * shares)  // simplified
            let avgCost = shares > 0 ? totalCost / shares : 0
            let pnlPct = avgCost > 0 ? ((currentPrice - avgCost) / avgCost * 100) : 0

            var display = HoldingDisplay(
                symbol: symbol,
                name: row["name_ar"] as? String ?? name,
                shares: shares,
                currentPrice: currentPrice,
                currentValue: valueSAR,
                pnl: pnl,
                pnlPercent: pnlPct,
                currency: Currency(rawValue: currency) ?? .sar
            )
            display.assetType = type
            return display
        }

        DispatchQueue.main.async {
            self.holdings = holdingsLoaded
        }
    }
}

// Extend HoldingDisplay to include assetType
extension HoldingDisplay {
    var assetType: String {
        get { return _assetType ?? "" }
        set { _assetType = newValue }
    }
}

private var _assetTypeKey = "assetType"
extension HoldingDisplay {
    private var _assetType: String? {
        get { return objc_getAssociatedObject(self as AnyObject, &_assetTypeKey) as? String }
        set { objc_setAssociatedObject(self as AnyObject, &_assetTypeKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}
