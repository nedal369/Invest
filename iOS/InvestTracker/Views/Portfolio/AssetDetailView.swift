import SwiftUI
import Charts

struct AssetDetailView: View {
    let symbol: String
    @StateObject private var viewModel = AssetDetailViewModel()
    @State private var showAddTransaction = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Price Header
                if let asset = viewModel.asset {
                    AssetPriceHeader(asset: asset, priceData: viewModel.priceData)
                }

                // Holdings breakdown by lot
                VStack(alignment: .leading, spacing: 12) {
                    Text("الحيازات")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    ForEach(viewModel.holdings) { holding in
                        HoldingLotRow(holding: holding, currentPrice: viewModel.priceData?.price ?? 0)
                    }
                }
                .padding()
                .background(Color.appCardBg)
                .cornerRadius(16)
                .padding(.horizontal)

                // P&L Summary
                PnLSummaryCard(
                    totalShares: viewModel.totalShares,
                    avgCost: viewModel.avgCost,
                    currentPrice: viewModel.priceData?.price ?? 0,
                    realizedPnL: viewModel.realizedPnL,
                    unrealizedPnL: viewModel.unrealizedPnL
                )

                // Transaction History
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("سجل العمليات")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            showAddTransaction = true
                        } label: {
                            Label("إضافة", systemImage: "plus")
                                .font(.caption)
                                .foregroundColor(.appGold)
                        }
                    }

                    ForEach(viewModel.transactions) { txn in
                        TransactionRow(transaction: txn)
                    }
                }
                .padding()
                .background(Color.appCardBg)
                .cornerRadius(16)
                .padding(.horizontal)

                // Dividends
                if !viewModel.dividends.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("توزيعات الأرباح")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(viewModel.dividends) { div in
                            DividendRow(dividend: div)
                        }
                    }
                    .padding()
                    .background(Color.appCardBg)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                // Zakat Info
                ZakatInfoCard(
                    holdings: viewModel.holdings,
                    symbol: symbol
                )
            }
            .padding(.vertical)
        }
        .background(Color.appDarkBlue.ignoresSafeArea())
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionView(isPresented: $showAddTransaction) {
                viewModel.loadData(symbol: symbol)
            }
        }
        .onAppear {
            viewModel.loadData(symbol: symbol)
        }
    }
}

// MARK: - Asset Price Header
struct AssetPriceHeader: View {
    let asset: Asset
    let priceData: PriceData?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(asset.nameAr ?? asset.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(asset.type.displayName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    if let price = priceData?.price {
                        Text(price.formattedSAR())
                            .font(.title2.bold())
                            .foregroundColor(.appGold)
                    }
                    if let change = priceData?.dailyChangePct {
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(change.formattedPct())
                        }
                        .font(.subheadline)
                        .foregroundColor(change >= 0 ? .appSuccess : .appDanger)
                    }
                }
            }

            if let update = priceData?.timestamp {
                Text("آخر تحديث: \(update.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Holding Lot Row
struct HoldingLotRow: View {
    let holding: Holding
    let currentPrice: Decimal

    var unrealizedPnL: Decimal {
        return (currentPrice - holding.purchasePrice) * holding.sharesRemaining
    }

    var pnlPct: Decimal {
        guard holding.purchasePrice > 0 else { return 0 }
        return (currentPrice - holding.purchasePrice) / holding.purchasePrice * 100
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                HStack {
                    Text("\(holding.sharesRemaining.formatted()) وحدة")
                    Text("@")
                    Text(holding.purchasePrice.formattedSAR())
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

                if holding.haolCompleted {
                    Label("اكتمل الحول", systemImage: "moon.stars.fill")
                        .font(.caption2)
                        .foregroundColor(.appGold)
                } else {
                    Text("الحول: \(holding.daysUntilHaol) يوم متبقي")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(unrealizedPnL.formattedSAR())
                    .font(.subheadline.bold())
                    .foregroundColor(unrealizedPnL >= 0 ? .appSuccess : .appDanger)
                Text(pnlPct.formattedPct())
                    .font(.caption)
                    .foregroundColor(pnlPct >= 0 ? .appSuccess : .appDanger)
            }
        }
        .padding(.vertical, 8)

        Divider().background(Color.white.opacity(0.1))
    }
}

// MARK: - P&L Summary Card
struct PnLSummaryCard: View {
    let totalShares: Decimal
    let avgCost: Decimal
    let currentPrice: Decimal
    let realizedPnL: Decimal
    let unrealizedPnL: Decimal

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                InfoItem(title: "إجمالي الوحدات", value: "\(totalShares.formatted())")
                Spacer()
                InfoItem(title: "متوسط التكلفة", value: avgCost.formattedSAR())
                Spacer()
                InfoItem(title: "السعر الحالي", value: currentPrice.formattedSAR())
            }

            Divider().background(Color.white.opacity(0.2))

            HStack {
                VStack(alignment: .leading) {
                    Text("الربح المحقق")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text(realizedPnL.formattedSAR())
                        .font(.subheadline.bold())
                        .foregroundColor(realizedPnL >= 0 ? .appSuccess : .appDanger)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("الربح غير المحقق")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text(unrealizedPnL.formattedSAR())
                        .font(.subheadline.bold())
                        .foregroundColor(unrealizedPnL >= 0 ? .appSuccess : .appDanger)
                }
            }
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct InfoItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.white)
        }
    }
}

// MARK: - Dividend Row
struct DividendRow: View {
    let dividend: DividendRecord

    var body: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundColor(.appGold)
            VStack(alignment: .leading) {
                Text(dividend.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(dividend.amountPerShare.formatted()) × \(dividend.totalShares.formatted())")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            Text(dividend.amountSAR.formattedSAR())
                .font(.subheadline.bold())
                .foregroundColor(.appGold)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Zakat Info Card
struct ZakatInfoCard: View {
    let holdings: [Holding]
    let symbol: String

    var zakatable: [Holding] { holdings.filter { $0.haolCompleted } }
    var pendingHaol: [Holding] { holdings.filter { !$0.haolCompleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("معلومات الزكاة", systemImage: "moon.stars.fill")
                .font(.headline)
                .foregroundColor(.appGold)

            HStack {
                VStack(alignment: .leading) {
                    Text("حال عليها الحول")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(zakatable.count) دفعة")
                        .font(.subheadline.bold())
                        .foregroundColor(.appSuccess)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("لم يكتمل حولها")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(pendingHaol.count) دفعة")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                }
            }

            if let nextHaol = pendingHaol.sorted(by: { $0.daysUntilHaol < $1.daysUntilHaol }).first {
                Text("أقرب حول: \(nextHaol.daysUntilHaol) يوم")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color.appGold.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appGold.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Transaction List View
struct TransactionListView: View {
    @StateObject private var viewModel = TransactionListViewModel()

    var body: some View {
        List {
            ForEach(viewModel.transactions) { txn in
                TransactionRow(transaction: txn)
                    .listRowBackground(Color.appCardBg)
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appDarkBlue.ignoresSafeArea())
        .navigationTitle("جميع العمليات")
        .onAppear { viewModel.loadAll() }
    }
}

class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []

    func loadAll() {
        let db = DatabaseManager.shared
        let rows = db.query("SELECT * FROM transactions WHERE status = 'CONFIRMED' ORDER BY date DESC")
        transactions = rows.compactMap { parseTransaction(from: $0) }
    }

    private func parseTransaction(from row: [String: Any]) -> Transaction? {
        guard let idStr = row["id"] as? String,
              let id = UUID(uuidString: idStr),
              let typeStr = row["type"] as? String,
              let type = TransactionType(rawValue: typeStr),
              let dateStr = row["date"] as? String,
              let date = ISO8601DateFormatter().date(from: dateStr) else { return nil }

        var txn = Transaction(id: id, type: type, date: date)
        txn.assetSymbol = row["asset_symbol"] as? String
        txn.quantity = Decimal(row["quantity"] as? Double ?? 0)
        txn.price = Decimal(row["price"] as? Double ?? 0)
        txn.amountSAR = Decimal(row["amount_sar"] as? Double ?? 0)
        txn.fees = Decimal(row["fees"] as? Double ?? 0)
        txn.notes = row["notes"] as? String
        txn.currency = Currency(rawValue: row["currency"] as? String ?? "SAR") ?? .sar
        return txn
    }
}

// MARK: - Asset Detail ViewModel
class AssetDetailViewModel: ObservableObject {
    @Published var asset: Asset?
    @Published var priceData: PriceData?
    @Published var holdings: [Holding] = []
    @Published var transactions: [Transaction] = []
    @Published var dividends: [DividendRecord] = []
    @Published var totalShares: Decimal = 0
    @Published var avgCost: Decimal = 0
    @Published var realizedPnL: Decimal = 0
    @Published var unrealizedPnL: Decimal = 0

    func loadData(symbol: String) {
        let db = DatabaseManager.shared
        let priceService = PriceService.shared

        priceData = priceService.getPrice(symbol: symbol)

        // Load holdings
        let holdingRows = db.query("""
            SELECT h.* FROM holdings h
            INNER JOIN assets a ON a.id = h.asset_id
            WHERE a.symbol = ? AND h.shares_remaining > 0
        """, params: [symbol])

        holdings = holdingRows.compactMap { row in
            guard let idStr = row["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let assetIdStr = row["asset_id"] as? String,
                  let assetId = UUID(uuidString: assetIdStr),
                  let dateStr = row["purchase_date"] as? String,
                  let date = ISO8601DateFormatter().date(from: dateStr) else { return nil }

            var holding = Holding(
                id: id,
                assetId: assetId,
                purchaseDate: date,
                sharesOriginal: Decimal(row["shares_original"] as? Double ?? 0),
                purchasePrice: Decimal(row["purchase_price"] as? Double ?? 0),
                purchaseCurrency: Currency(rawValue: row["purchase_currency"] as? String ?? "SAR") ?? .sar
            )
            holding.sharesRemaining = Decimal(row["shares_remaining"] as? Double ?? 0)
            return holding
        }

        totalShares = holdings.reduce(0) { $0 + $1.sharesRemaining }
        let totalCost = holdings.reduce(Decimal(0)) { $0 + ($1.purchasePrice * $1.sharesRemaining) }
        avgCost = totalShares > 0 ? totalCost / totalShares : 0

        let currentPrice = priceData?.price ?? avgCost
        unrealizedPnL = (currentPrice - avgCost) * totalShares

        // Load transactions
        let txnRows = db.query("""
            SELECT t.* FROM transactions t
            INNER JOIN assets a ON a.id = t.asset_id
            WHERE a.symbol = ? ORDER BY t.date DESC
        """, params: [symbol])
        // Parse transactions...
    }
}
