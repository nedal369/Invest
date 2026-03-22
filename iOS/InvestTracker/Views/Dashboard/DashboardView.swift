import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var priceService: PriceService
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showRefreshIndicator = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Portfolio Value Card
                    PortfolioValueCard(summary: viewModel.summary)

                    // Performance Chart
                    PerformanceChartCard(data: viewModel.chartData)

                    // PnL Cards Row
                    HStack(spacing: 12) {
                        PnLCard(title: "ربح محقق", amount: viewModel.summary.realizedPnL, icon: "checkmark.seal.fill")
                        PnLCard(title: "ربح غير محقق", amount: viewModel.summary.unrealizedPnL, icon: "chart.line.uptrend.xyaxis")
                    }

                    // Holdings Section
                    HoldingsSummaryCard(holdings: viewModel.topHoldings)

                    // Best/Worst Asset
                    if let best = viewModel.bestAsset, let worst = viewModel.worstAsset {
                        BestWorstCard(best: best, worst: worst)
                    }

                    // Currency Distribution
                    CurrencyDistributionCard(distribution: viewModel.currencyDistribution)

                    // Active Alerts
                    if !viewModel.activeAlerts.isEmpty {
                        AlertsCard(alerts: viewModel.activeAlerts)
                    }

                    // Recent Transactions
                    RecentTransactionsCard(transactions: viewModel.recentTransactions)
                }
                .padding()
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("لوحة المعلومات")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        priceService.updateAllPrices()
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.appGold)
                    }
                }
            }
            .refreshable {
                priceService.updateAllPrices()
                viewModel.refresh()
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }
}

// MARK: - Portfolio Value Card
struct PortfolioValueCard: View {
    let summary: PortfolioSummary

    var body: some View {
        VStack(spacing: 12) {
            Text("إجمالي قيمة المحفظة")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Text(summary.totalCurrentValue.formattedSAR())
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.appGold)

            HStack(spacing: 20) {
                VStack(alignment: .center) {
                    Text("إجمالي الإيداعات")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text(summary.totalDeposits.formattedSAR())
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }

                Divider().frame(height: 30).background(Color.white.opacity(0.3))

                VStack(alignment: .center) {
                    Text("العائد الإجمالي")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 4) {
                        Text(summary.returnPercentage.formattedPct())
                            .font(.subheadline.bold())
                            .foregroundColor(summary.totalReturn >= 0 ? .appSuccess : .appDanger)
                        Image(systemName: summary.totalReturn >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundColor(summary.totalReturn >= 0 ? .appSuccess : .appDanger)
                            .font(.caption)
                    }
                }

                Divider().frame(height: 30).background(Color.white.opacity(0.3))

                VStack(alignment: .center) {
                    Text("الكاش")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text(summary.cashBalance.formattedSAR())
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .background(Color.appCardBg)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 8)
    }
}

// MARK: - Performance Chart Card
struct PerformanceChartCard: View {
    let data: [ChartDataPoint]
    @State private var selectedPeriod: ChartPeriod = .oneMonth

    enum ChartPeriod: String, CaseIterable {
        case oneWeek = "أسبوع"
        case oneMonth = "شهر"
        case threeMonths = "3 أشهر"
        case sixMonths = "6 أشهر"
        case oneYear = "سنة"
        case all = "الكل"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("أداء المحفظة")
                .font(.headline)
                .foregroundColor(.white)

            // Period selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChartPeriod.allCases, id: \.self) { period in
                        Button {
                            selectedPeriod = period
                        } label: {
                            Text(period.rawValue)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedPeriod == period ? Color.appGold : Color.white.opacity(0.1))
                                .foregroundColor(selectedPeriod == period ? .appDarkBlue : .white)
                                .cornerRadius(20)
                        }
                    }
                }
            }

            // Chart
            if !data.isEmpty {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("التاريخ", point.date),
                            y: .value("القيمة", point.portfolioValue)
                        )
                        .foregroundStyle(Color.appGold)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("التاريخ", point.date),
                            y: .value("القيمة", point.portfolioValue)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [.appGold.opacity(0.3), .clear],
                                          startPoint: .top, endPoint: .bottom)
                        )

                        LineMark(
                            x: .value("التاريخ", point.date),
                            y: .value("الإيداعات", point.depositsValue)
                        )
                        .foregroundStyle(Color.blue.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                    }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Rectangle().fill(Color.appGold).frame(width: 20, height: 2)
                        Text("قيمة المحفظة").font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                    HStack(spacing: 6) {
                        Rectangle().fill(Color.blue.opacity(0.7)).frame(width: 20, height: 2)
                        Text("الإيداعات").font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                Text("لا توجد بيانات كافية للرسم البياني")
                    .foregroundColor(.white.opacity(0.5))
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(16)
    }
}

// MARK: - PnL Card
struct PnLCard: View {
    let title: String
    let amount: Decimal
    let icon: String

    var isPositive: Bool { amount >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isPositive ? .appSuccess : .appDanger)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Text(amount.formattedSAR())
                .font(.headline.bold())
                .foregroundColor(isPositive ? .appSuccess : .appDanger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(14)
    }
}

// MARK: - Holdings Summary Card
struct HoldingsSummaryCard: View {
    let holdings: [HoldingDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("أبرز الممتلكات")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                NavigationLink("عرض الكل", destination: PortfolioView())
                    .font(.caption)
                    .foregroundColor(.appGold)
            }

            if holdings.isEmpty {
                Text("لا توجد ممتلكات بعد")
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(holdings.prefix(5)) { holding in
                    HoldingRow(holding: holding)
                }
            }
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(16)
    }
}

// MARK: - Holding Row
struct HoldingRow: View {
    let holding: HoldingDisplay

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(holding.symbol)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(holding.name)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(holding.currentValue.formattedSAR())
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Image(systemName: holding.pnlPercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(holding.pnlPercent.formattedPct())
                }
                .font(.caption)
                .foregroundColor(holding.pnlPercent >= 0 ? .appSuccess : .appDanger)
            }
        }
        .padding(.vertical, 4)

        Divider().background(Color.white.opacity(0.1))
    }
}

// MARK: - Best/Worst Card
struct BestWorstCard: View {
    let best: HoldingDisplay
    let worst: HoldingDisplay

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("الأفضل", systemImage: "star.fill")
                    .font(.caption.bold())
                    .foregroundColor(.appGold)
                Text(best.symbol)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(best.pnlPercent.formattedPct())
                    .font(.subheadline.bold())
                    .foregroundColor(.appSuccess)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.appSuccess.opacity(0.15))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                Label("الأسوأ", systemImage: "arrow.down.circle.fill")
                    .font(.caption.bold())
                    .foregroundColor(.red)
                Text(worst.symbol)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(worst.pnlPercent.formattedPct())
                    .font(.subheadline.bold())
                    .foregroundColor(.appDanger)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.appDanger.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

// MARK: - Currency Distribution Card
struct CurrencyDistributionCard: View {
    let distribution: [CurrencyDistribution]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("توزيع العملات")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 20) {
                ForEach(distribution) { item in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: item.percentage / 100)
                                .stroke(item.color, lineWidth: 8)
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text("\(Int(item.percentage))%")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }

                        Text(item.currency)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(item.value.formattedSAR())
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(16)
    }
}

// MARK: - Alerts Card
struct AlertsCard: View {
    let alerts: [AlertDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("تنبيهات نشطة", systemImage: "bell.fill")
                .font(.headline)
                .foregroundColor(.appGold)

            ForEach(alerts) { alert in
                HStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text(alert.message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(alert.symbol)
                        .font(.caption.bold())
                        .foregroundColor(.appGold)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Recent Transactions Card
struct RecentTransactionsCard: View {
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("آخر العمليات")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                NavigationLink("عرض الكل", destination: TransactionListView())
                    .font(.caption)
                    .foregroundColor(.appGold)
            }

            if transactions.isEmpty {
                Text("لا توجد عمليات بعد")
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(transactions.prefix(5)) { txn in
                    TransactionRow(transaction: txn)
                }
            }
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(16)
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            Image(systemName: transaction.type.icon)
                .foregroundColor(transaction.type.isInflow ? .appSuccess : .appDanger)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(transaction.type.displayName + (transaction.assetSymbol.map { " - \($0)" } ?? ""))
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Text(transaction.amountSAR.formattedSAR())
                .font(.subheadline.bold())
                .foregroundColor(transaction.type.isInflow ? .appSuccess : .appDanger)
        }
        .padding(.vertical, 4)

        Divider().background(Color.white.opacity(0.1))
    }
}

// MARK: - View Model
class DashboardViewModel: ObservableObject {
    @Published var summary = PortfolioSummary(totalCurrentValue: 0, totalDeposits: 0, totalWithdrawals: 0, realizedPnL: 0, unrealizedPnL: 0, cashBalance: 0, totalDividends: 0, totalFees: 0)
    @Published var chartData: [ChartDataPoint] = []
    @Published var topHoldings: [HoldingDisplay] = []
    @Published var bestAsset: HoldingDisplay?
    @Published var worstAsset: HoldingDisplay?
    @Published var currencyDistribution: [CurrencyDistribution] = []
    @Published var activeAlerts: [AlertDisplay] = []
    @Published var recentTransactions: [Transaction] = []

    func loadData() {
        // Load from database
        refresh()
    }

    func refresh() {
        loadSummary()
        loadChartData()
        loadHoldings()
        loadAlerts()
        loadRecentTransactions()
    }

    private func loadSummary() {
        let db = DatabaseManager.shared
        let priceService = PriceService.shared

        // Calculate from DB
        let depositRows = db.query("SELECT COALESCE(SUM(amount_sar), 0) as total FROM transactions WHERE type = 'DEPOSIT'")
        let withdrawRows = db.query("SELECT COALESCE(SUM(amount_sar), 0) as total FROM transactions WHERE type = 'WITHDRAW'")
        let dividendRows = db.query("SELECT COALESCE(SUM(amount_sar), 0) as total FROM dividends")

        let deposits = Decimal(depositRows.first?["total"] as? Double ?? 0)
        let withdrawals = Decimal(withdrawRows.first?["total"] as? Double ?? 0)
        let dividends = Decimal(dividendRows.first?["total"] as? Double ?? 0)

        // Get holdings value
        let holdingRows = db.query("""
            SELECT h.shares_remaining, a.symbol, a.currency
            FROM holdings h INNER JOIN assets a ON a.id = h.asset_id
            WHERE h.shares_remaining > 0
        """)

        var currentValue = Decimal(0)
        var sarValue = Decimal(0)
        var usdValue = Decimal(0)

        for row in holdingRows {
            guard let symbol = row["symbol"] as? String,
                  let currency = row["currency"] as? String,
                  let shares = (row["shares_remaining"] as? Double).map({ Decimal($0) }) else { continue }

            let price = priceService.getPrice(symbol: symbol)?.price ?? 0
            let value = shares * price

            if currency == "USD" {
                usdValue += value
                currentValue += value * priceService.getUSDSARRate()
            } else {
                sarValue += value
                currentValue += value
            }
        }

        DispatchQueue.main.async {
            self.summary = PortfolioSummary(
                totalCurrentValue: currentValue,
                totalDeposits: deposits,
                totalWithdrawals: withdrawals,
                realizedPnL: 0, // calculated separately
                unrealizedPnL: currentValue - (deposits - withdrawals),
                cashBalance: 0,
                totalDividends: dividends,
                totalFees: 0
            )

            self.currencyDistribution = [
                CurrencyDistribution(currency: "ريال (SAR)", value: sarValue,
                                     percentage: currentValue > 0 ? Double(truncating: (sarValue / currentValue * 100) as NSDecimalNumber) : 0,
                                     color: .appGold),
                CurrencyDistribution(currency: "دولار (USD)", value: usdValue * PriceService.shared.getUSDSARRate(),
                                     percentage: currentValue > 0 ? Double(truncating: (usdValue * PriceService.shared.getUSDSARRate() / currentValue * 100) as NSDecimalNumber) : 0,
                                     color: .blue)
            ]
        }
    }

    private func loadChartData() {
        // Load historical snapshots from transactions
        let db = DatabaseManager.shared
        let rows = db.query("""
            SELECT date(date) as day, SUM(CASE WHEN type='DEPOSIT' THEN amount_sar ELSE 0 END) as deposits,
            SUM(CASE WHEN type='WITHDRAW' THEN amount_sar ELSE 0 END) as withdrawals
            FROM transactions
            GROUP BY date(date)
            ORDER BY date(date) ASC
        """)

        var runningDeposits = Decimal(0)
        var points: [ChartDataPoint] = []

        for row in rows {
            guard let dayStr = row["day"] as? String else { continue }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: dayStr) else { continue }

            let deposits = Decimal(row["deposits"] as? Double ?? 0)
            let withdrawals = Decimal(row["withdrawals"] as? Double ?? 0)
            runningDeposits += deposits - withdrawals

            points.append(ChartDataPoint(
                date: date,
                portfolioValue: runningDeposits * 1.1, // approximation
                depositsValue: runningDeposits
            ))
        }

        DispatchQueue.main.async {
            self.chartData = points
        }
    }

    private func loadHoldings() {
        let db = DatabaseManager.shared
        let priceService = PriceService.shared

        let rows = db.query("""
            SELECT a.symbol, a.name, a.name_ar, a.currency,
            SUM(h.shares_remaining) as total_shares,
            SUM(h.shares_remaining * h.purchase_price) / SUM(h.shares_remaining) as avg_cost
            FROM holdings h INNER JOIN assets a ON a.id = h.asset_id
            WHERE h.shares_remaining > 0
            GROUP BY a.id
            ORDER BY SUM(h.shares_remaining * a.current_price) DESC
        """)

        let holdings: [HoldingDisplay] = rows.compactMap { row in
            guard let symbol = row["symbol"] as? String,
                  let name = row["name"] as? String,
                  let currency = row["currency"] as? String,
                  let shares = (row["total_shares"] as? Double).map({ Decimal($0) }),
                  let avgCost = (row["avg_cost"] as? Double).map({ Decimal($0) }) else { return nil }

            let currentPrice = priceService.getPrice(symbol: symbol)?.price ?? avgCost
            let currentValue = shares * currentPrice
            let costBasis = shares * avgCost
            let pnl = currentValue - costBasis
            let pnlPct = costBasis > 0 ? (pnl / costBasis * 100) : 0

            let usdSarRate = priceService.getUSDSARRate()
            let valueSAR = currency == "USD" ? currentValue * usdSarRate : currentValue

            return HoldingDisplay(
                symbol: symbol,
                name: row["name_ar"] as? String ?? name,
                shares: shares,
                currentPrice: currentPrice,
                currentValue: valueSAR,
                pnl: pnl,
                pnlPercent: pnlPct,
                currency: Currency(rawValue: currency) ?? .sar
            )
        }

        DispatchQueue.main.async {
            self.topHoldings = holdings
            self.bestAsset = holdings.max(by: { $0.pnlPercent < $1.pnlPercent })
            self.worstAsset = holdings.min(by: { $0.pnlPercent < $1.pnlPercent })
        }
    }

    private func loadAlerts() {
        // Load active triggered alerts
        DispatchQueue.main.async {
            self.activeAlerts = []
        }
    }

    private func loadRecentTransactions() {
        let db = DatabaseManager.shared
        let rows = db.query("""
            SELECT * FROM transactions
            WHERE status = 'CONFIRMED'
            ORDER BY date DESC
            LIMIT 10
        """)

        let txns: [Transaction] = rows.compactMap { row in
            guard let idStr = row["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let typeStr = row["type"] as? String,
                  let type = TransactionType(rawValue: typeStr),
                  let dateStr = row["date"] as? String,
                  let date = ISO8601DateFormatter().date(from: dateStr) else { return nil }

            var txn = Transaction(id: id, type: type, date: date)
            txn.assetSymbol = row["asset_symbol"] as? String
            txn.amountSAR = Decimal(row["amount_sar"] as? Double ?? 0)
            txn.currency = Currency(rawValue: row["currency"] as? String ?? "SAR") ?? .sar
            return txn
        }

        DispatchQueue.main.async {
            self.recentTransactions = txns
        }
    }
}

// MARK: - Display Models
struct HoldingDisplay: Identifiable {
    let id = UUID()
    var symbol: String
    var name: String
    var shares: Decimal
    var currentPrice: Decimal
    var currentValue: Decimal
    var pnl: Decimal
    var pnlPercent: Decimal
    var currency: Currency
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    var date: Date
    var portfolioValue: Decimal
    var depositsValue: Decimal
}

struct CurrencyDistribution: Identifiable {
    let id = UUID()
    var currency: String
    var value: Decimal
    var percentage: Double
    var color: Color
}

struct AlertDisplay: Identifiable {
    let id = UUID()
    var symbol: String
    var message: String
    var alertType: String
}

// MARK: - Decimal Formatting
extension Decimal {
    func formattedSAR() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "ar_SA")
        return (formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0.00") + " ر.س"
    }

    func formattedPct() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let prefix = self >= 0 ? "+" : ""
        return prefix + (formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0.00") + "%"
    }
}
