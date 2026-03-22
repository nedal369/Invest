import SwiftUI

struct ZakatView: View {
    @StateObject private var viewModel = ZakatViewModel()
    @State private var showCalculateSheet = false
    @State private var showPaymentSheet = false
    @State private var selectedCalculation: ZakatCalculation?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Current Status Card
                    ZakatStatusCard(
                        goldPrice: viewModel.goldPrice24K,
                        nisab: viewModel.nisabAmount,
                        personalBase: viewModel.personalZakatBase,
                        dueAmount: viewModel.personalZakatDue
                    )

                    // Calculate Button
                    Button {
                        viewModel.calculatePersonalZakat()
                        showCalculateSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                            Text("احتساب الزكاة الشخصية")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appGold)
                        .foregroundColor(.appDarkBlue)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)

                    // Fund Zakat Section
                    if !viewModel.funds.isEmpty {
                        FundZakatSection(funds: viewModel.funds, onCalculate: { fund in
                            viewModel.calculateFundZakat(fund: fund)
                            showCalculateSheet = true
                        })
                    }

                    // Haol Progress
                    HaolProgressSection(holdings: viewModel.holdingsForHaol)

                    // Zakat History
                    ZakatHistorySection(history: viewModel.history)
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("الزكاة")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCalculateSheet) {
                if let calc = viewModel.latestCalculation {
                    ZakatCalculationDetailView(
                        calculation: calc,
                        isPresented: $showCalculateSheet,
                        onPay: { amount in
                            viewModel.recordPayment(calculationId: calc.id, amount: amount)
                        }
                    )
                }
            }
            .onAppear { viewModel.loadData() }
        }
    }
}

// MARK: - Zakat Status Card
struct ZakatStatusCard: View {
    let goldPrice: Decimal
    let nisab: Decimal
    let personalBase: Decimal
    let dueAmount: Decimal

    var isNisabMet: Bool { personalBase >= nisab }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.appGold)
                    .font(.title2)
                Text("حالة الزكاة")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(isNisabMet ? "بلغ النصاب" : "لم يبلغ النصاب")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isNisabMet ? Color.appGold.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(isNisabMet ? .appGold : .gray)
                    .cornerRadius(8)
            }

            Divider().background(Color.white.opacity(0.2))

            HStack {
                ZakatInfoItem(title: "سعر الذهب 24K", value: "\(goldPrice.formatted()) ر.س/غ")
                Divider().frame(height: 40).background(Color.white.opacity(0.2))
                ZakatInfoItem(title: "النصاب (85غ)", value: nisab.formattedSAR())
                Divider().frame(height: 40).background(Color.white.opacity(0.2))
                ZakatInfoItem(title: "وعاء الزكاة", value: personalBase.formattedSAR())
            }

            if isNisabMet {
                VStack(spacing: 6) {
                    Text("الزكاة المستحقة (2.5%)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Text(dueAmount.formattedSAR())
                        .font(.title.bold())
                        .foregroundColor(.appGold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appGold.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct ZakatInfoItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fund Zakat Section
struct FundZakatSection: View {
    let funds: [Fund]
    let onCalculate: (Fund) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("زكاة الصناديق")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            ForEach(funds) { fund in
                HStack {
                    VStack(alignment: .leading) {
                        Text(fund.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("\(fund.totalUnits) وحدة | \(fund.members.count) عضو")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Button {
                        onCalculate(fund)
                    } label: {
                        Text("احتساب")
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.appGold)
                            .foregroundColor(.appDarkBlue)
                            .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Color.appCardBg)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Haol Progress Section
struct HaolProgressSection: View {
    let holdings: [HaolProgressItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("تقدم الحول")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            if holdings.isEmpty {
                Text("لا توجد حيازات")
                    .foregroundColor(.white.opacity(0.5))
                    .padding()
            } else {
                ForEach(holdings) { item in
                    HaolProgressRow(item: item)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct HaolProgressRow: View {
    let item: HaolProgressItem

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(item.symbol)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                if item.haolCompleted {
                    Label("اكتمل الحول", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.appGold)
                } else {
                    Text("\(item.daysRemaining) يوم متبقي")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            ProgressView(value: item.progressPercentage, total: 1.0)
                .tint(item.haolCompleted ? .appGold : .orange)
                .background(Color.white.opacity(0.1))

            HStack {
                Text("بدأ: \(item.purchaseDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("قيمة: \(item.value.formattedSAR())")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(Color.appCardBg)
        .cornerRadius(12)
    }
}

// MARK: - Zakat History Section
struct ZakatHistorySection: View {
    let history: [ZakatHistoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("سجل الزكاة")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            if history.isEmpty {
                Text("لا يوجد سجل بعد")
                    .foregroundColor(.white.opacity(0.5))
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(history) { item in
                    ZakatHistoryRow(item: item)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct ZakatHistoryRow: View {
    let item: ZakatHistoryItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.year)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(item.type)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(item.calculationDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.zakatDue.formattedSAR())
                    .font(.subheadline.bold())
                    .foregroundColor(.appGold)
                Text(item.status.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(item.status == .paid ? Color.appSuccess.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(item.status == .paid ? .appSuccess : .orange)
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.appCardBg)
        .cornerRadius(12)
    }
}

// MARK: - Zakat Calculation Detail View
struct ZakatCalculationDetailView: View {
    let calculation: ZakatCalculation
    @Binding var isPresented: Bool
    let onPay: (Decimal) -> Void

    @State private var showPayConfirmation = false
    @State private var paymentNotes = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Nisab section
                    VStack(spacing: 12) {
                        Text("النصاب والأساس")
                            .font(.headline)
                            .foregroundColor(.appGold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        DetailRow(label: "سعر الذهب 24K",
                                 value: "\(calculation.goldPricePer24KGram.formatted()) ر.س/غ")
                        DetailRow(label: "النصاب (85 غرام ذهب)",
                                 value: calculation.nisabAmountSAR.formattedSAR())
                    }
                    .padding()
                    .background(Color.appCardBg)
                    .cornerRadius(16)

                    // Zakat Base Breakdown
                    VStack(spacing: 12) {
                        Text("وعاء الزكاة")
                            .font(.headline)
                            .foregroundColor(.appGold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        DetailRow(label: "قيمة الأصول (اكتمل حولها)",
                                 value: calculation.holdingsValue.formattedSAR())
                        DetailRow(label: "الكاش (اكتمل حوله)",
                                 value: calculation.cashValue.formattedSAR())
                        DetailRow(label: "توزيعات الأرباح",
                                 value: calculation.dividendsValue.formattedSAR())

                        Divider().background(Color.white.opacity(0.3))

                        HStack {
                            Text("إجمالي وعاء الزكاة")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Text(calculation.totalZakatBase.formattedSAR())
                                .font(.subheadline.bold())
                                .foregroundColor(.appGold)
                        }
                    }
                    .padding()
                    .background(Color.appCardBg)
                    .cornerRadius(16)

                    // Zakat Due
                    if calculation.isNisabMet {
                        VStack(spacing: 12) {
                            Text("الزكاة المستحقة")
                                .font(.headline)
                                .foregroundColor(.appGold)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                Text("2.5% × \(calculation.totalZakatBase.formattedSAR())")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text(calculation.zakatDue.formattedSAR())
                                    .font(.title2.bold())
                                    .foregroundColor(.appGold)
                            }
                        }
                        .padding()
                        .background(Color.appGold.opacity(0.15))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appGold.opacity(0.4), lineWidth: 1))

                        // Member breakdown (for funds)
                        if let breakdown = calculation.memberBreakdown {
                            VStack(spacing: 12) {
                                Text("توزيع على الأعضاء")
                                    .font(.headline)
                                    .foregroundColor(.appGold)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(breakdown) { share in
                                    HStack {
                                        Text("\(share.memberName) (\(share.units) وحدة)")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(share.zakatDue.formattedSAR())
                                            .font(.subheadline.bold())
                                            .foregroundColor(.appGold)
                                    }
                                    Divider().background(Color.white.opacity(0.1))
                                }
                            }
                            .padding()
                            .background(Color.appCardBg)
                            .cornerRadius(16)
                        }

                        // Pay button
                        if calculation.status == .calculated {
                            Button {
                                showPayConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("أخرجت الزكاة")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appGold)
                                .foregroundColor(.appDarkBlue)
                                .cornerRadius(14)
                                .font(.headline)
                            }
                        } else {
                            Label("تم إخراج الزكاة", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.appSuccess)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    } else {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("لم يبلغ الوعاء النصاب، لا زكاة مستحقة")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("احتساب الزكاة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إغلاق") { isPresented = false }
                        .foregroundColor(.appGold)
                }
            }
            .alert("تأكيد إخراج الزكاة", isPresented: $showPayConfirmation) {
                Button("تأكيد") { onPay(calculation.zakatDue); isPresented = false }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("هل أخرجت زكاة \(calculation.zakatDue.formattedSAR())؟\nسيبدأ حول جديد من تاريخ اليوم.")
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
    }
}

// MARK: - Zakat View Model
class ZakatViewModel: ObservableObject {
    @Published var goldPrice24K: Decimal = 0
    @Published var nisabAmount: Decimal = 0
    @Published var personalZakatBase: Decimal = 0
    @Published var personalZakatDue: Decimal = 0
    @Published var funds: [Fund] = []
    @Published var holdingsForHaol: [HaolProgressItem] = []
    @Published var history: [ZakatHistoryItem] = []
    @Published var latestCalculation: ZakatCalculation?

    func loadData() {
        goldPrice24K = PriceService.shared.getGoldPrice24K()
        nisabAmount = goldPrice24K * 85

        loadFunds()
        loadHaolProgress()
        history = ZakatService.shared.getZakatHistory()
    }

    func calculatePersonalZakat() {
        let calc = ZakatService.shared.calculatePersonalZakat()
        latestCalculation = calc
        personalZakatBase = calc.totalZakatBase
        personalZakatDue = calc.zakatDue
    }

    func calculateFundZakat(fund: Fund) {
        let calc = ZakatService.shared.calculateFundZakat(fundId: fund.id)
        latestCalculation = calc
    }

    func recordPayment(calculationId: UUID, amount: Decimal) {
        ZakatService.shared.recordZakatPayment(calculationId: calculationId, amount: amount)
        loadData()
    }

    private func loadFunds() {
        let db = DatabaseManager.shared
        let rows = db.query("SELECT * FROM funds WHERE is_active = 1")
        funds = rows.compactMap { row in
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let name = row["name"] as? String,
                  let unitPrice = (row["unit_price"] as? Double).map({ Decimal($0) }) else { return nil }
            return Fund(id: id, name: name, unitPrice: unitPrice)
        }
    }

    private func loadHaolProgress() {
        let db = DatabaseManager.shared
        let priceService = PriceService.shared

        let rows = db.query("""
            SELECT h.id, h.purchase_date, h.shares_remaining, h.purchase_price,
                   h.purchase_currency, a.symbol, a.name
            FROM holdings h INNER JOIN assets a ON a.id = h.asset_id
            WHERE h.shares_remaining > 0
            ORDER BY h.purchase_date ASC
        """)

        holdingsForHaol = rows.compactMap { row in
            guard let idStr = row["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let symbol = row["symbol"] as? String,
                  let dateStr = row["purchase_date"] as? String,
                  let date = ISO8601DateFormatter().date(from: dateStr),
                  let shares = (row["shares_remaining"] as? Double).map({ Decimal($0) }),
                  let purchasePrice = (row["purchase_price"] as? Double).map({ Decimal($0) }) else { return nil }

            let haolDays = 354.37
            let elapsed = Date().timeIntervalSince(date) / 86400
            let progress = min(1.0, elapsed / haolDays)
            let daysRemaining = max(0, Int(haolDays - elapsed))
            let completed = elapsed >= haolDays

            let currentPrice = priceService.getPrice(symbol: symbol)?.price ?? purchasePrice
            let value = shares * currentPrice

            return HaolProgressItem(
                id: id,
                symbol: symbol,
                purchaseDate: date,
                value: value,
                progressPercentage: progress,
                daysRemaining: daysRemaining,
                haolCompleted: completed
            )
        }
    }
}

// MARK: - Haol Progress Item
struct HaolProgressItem: Identifiable {
    let id: UUID
    var symbol: String
    var purchaseDate: Date
    var value: Decimal
    var progressPercentage: Double
    var daysRemaining: Int
    var haolCompleted: Bool
}
