import SwiftUI

struct FundsListView: View {
    @StateObject private var viewModel = FundsViewModel()
    @State private var showCreateFund = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.funds.isEmpty {
                        EmptyFundsView()
                    } else {
                        ForEach(viewModel.funds) { fund in
                            NavigationLink(destination: FundDetailView(fundId: fund.id)) {
                                FundCard(fund: fund, summary: viewModel.fundSummaries[fund.id])
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding()
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("الصناديق الاستثمارية")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateFund = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.appGold)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCreateFund) {
                CreateFundView(isPresented: $showCreateFund) {
                    viewModel.loadFunds()
                }
            }
            .onAppear { viewModel.loadFunds() }
        }
    }
}

// MARK: - Fund Card
struct FundCard: View {
    let fund: Fund
    let summary: FundSummaryData?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(fund.name)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text("\(fund.totalUnits) وحدة | \(fund.members.count) عضو")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(fund.unitPrice.formattedSAR())
                        .font(.subheadline.bold())
                        .foregroundColor(.appGold)
                    Text("/ وحدة شهرياً")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Divider().background(Color.white.opacity(0.2))

            if let summary = summary {
                HStack {
                    SummaryMiniItem(title: "إجمالي القيمة",
                                  value: summary.totalValue.formattedSAR())
                    Spacer()
                    SummaryMiniItem(title: "العائد",
                                  value: summary.returnPct.formattedPct(),
                                  isColored: true,
                                  isPositive: summary.returnPct >= 0)
                    Spacer()
                    SummaryMiniItem(title: "متأخرون",
                                  value: "\(summary.latePaymentsCount)",
                                  isColored: summary.latePaymentsCount > 0,
                                  isPositive: false)
                }
            }

            // Payment status bar
            HStack(spacing: 4) {
                Text("استحقاق يوم \(fund.paymentDayOfMonth)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(fund.isActive ? "نشط" : "موقوف")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(fund.isActive ? Color.appSuccess.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(fund.isActive ? .appSuccess : .gray)
                    .cornerRadius(6)
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 6)
    }
}

struct SummaryMiniItem: View {
    let title: String
    let value: String
    var isColored = false
    var isPositive = true

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.caption.bold())
                .foregroundColor(isColored ? (isPositive ? .appSuccess : .appDanger) : .white)
        }
    }
}

// MARK: - Fund Detail View
struct FundDetailView: View {
    let fundId: UUID
    @StateObject private var viewModel = FundDetailViewModel()
    @State private var selectedTab: FundTab = .members

    enum FundTab: String, CaseIterable {
        case members = "الأعضاء"
        case payments = "الدفعات"
        case investments = "الاستثمارات"
        case performance = "الأداء"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Fund Header
                if let fund = viewModel.fund {
                    FundHeaderCard(fund: fund, summary: viewModel.summary)
                }

                // Tab Selector
                Picker("", selection: $selectedTab) {
                    ForEach(FundTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                switch selectedTab {
                case .members:
                    FundMembersSection(members: viewModel.members, fundId: fundId) {
                        viewModel.loadData(fundId: fundId)
                    }

                case .payments:
                    FundPaymentsSection(payments: viewModel.pendingPayments, fundId: fundId) {
                        viewModel.loadData(fundId: fundId)
                    }

                case .investments:
                    FundInvestmentsSection(holdings: viewModel.holdings)

                case .performance:
                    FundPerformanceSection(summary: viewModel.summary, members: viewModel.members)
                }
            }
            .padding(.vertical)
        }
        .background(Color.appDarkBlue.ignoresSafeArea())
        .navigationTitle(viewModel.fund?.name ?? "الصندوق")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.loadData(fundId: fundId) }
    }
}

// MARK: - Fund Header Card
struct FundHeaderCard: View {
    let fund: Fund
    let summary: FundSummaryData?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text(fund.name)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("بدأ \(fund.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(summary?.totalValue.formattedSAR() ?? "—")
                        .font(.title2.bold())
                        .foregroundColor(.appGold)
                    Text("إجمالي القيمة")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            HStack(spacing: 0) {
                FundStatItem(title: "الوحدات", value: "\(fund.totalUnits)")
                Divider().frame(height: 40).background(Color.white.opacity(0.2))
                FundStatItem(title: "اشتراك شهري", value: fund.totalMonthlyContribution.formattedSAR())
                Divider().frame(height: 40).background(Color.white.opacity(0.2))
                FundStatItem(title: "NAV/وحدة",
                            value: summary?.navPerUnit.formattedSAR() ?? "—")
            }
        }
        .padding(16)
        .background(Color.appCardBg)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct FundStatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fund Members Section
struct FundMembersSection: View {
    let members: [FundMember]
    let fundId: UUID
    let onUpdate: () -> Void
    @State private var showAddMember = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("الأعضاء (\(members.count))")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showAddMember = true
                } label: {
                    Label("إضافة", systemImage: "person.badge.plus")
                        .font(.caption)
                        .foregroundColor(.appGold)
                }
            }
            .padding(.horizontal)

            ForEach(members) { member in
                MemberCard(member: member)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showAddMember) {
            AddMemberView(fundId: fundId, isPresented: $showAddMember, onSave: onUpdate)
        }
    }
}

// MARK: - Member Card
struct MemberCard: View {
    let member: FundMember

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.appGold.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(String(member.name.prefix(1)))
                    .font(.headline.bold())
                    .foregroundColor(.appGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                HStack {
                    Text("\(member.units) وحدة")
                    if let phone = member.phone {
                        Text("•")
                        Text(phone)
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing) {
                if member.webAccessEnabled {
                    Label("مفعّل", systemImage: "globe")
                        .font(.caption2)
                        .foregroundColor(.appSuccess)
                }
                if let code = member.webAccessCode {
                    Text("رمز: \(code)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(12)
        .background(Color.appCardBg)
        .cornerRadius(12)
    }
}

// MARK: - Fund Payments Section
struct FundPaymentsSection: View {
    let payments: [FundPayment]
    let fundId: UUID
    let onUpdate: () -> Void
    @State private var showRecordPayment = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("الدفعات المستحقة")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showRecordPayment = true
                } label: {
                    Label("تسجيل دفع", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.appGold)
                }
            }
            .padding(.horizontal)

            if payments.isEmpty {
                Text("لا توجد دفعات معلقة")
                    .foregroundColor(.white.opacity(0.5))
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(payments) { payment in
                    PaymentRow(payment: payment)
                        .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showRecordPayment) {
            RecordPaymentView(fundId: fundId, isPresented: $showRecordPayment, onSave: onUpdate)
        }
    }
}

// MARK: - Payment Row
struct PaymentRow: View {
    let payment: FundPayment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.memberName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("استحقاق: \(payment.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(payment.dueAmount.formattedSAR())
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(payment.status.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusBackground(payment.status))
                    .foregroundColor(statusColor(payment.status))
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.appCardBg)
        .cornerRadius(12)
    }

    private func statusBackground(_ status: PaymentStatus) -> Color {
        switch status {
        case .paid: return .appSuccess.opacity(0.2)
        case .pending: return .orange.opacity(0.2)
        case .late: return .appDanger.opacity(0.2)
        case .partial: return .yellow.opacity(0.2)
        case .carried: return .purple.opacity(0.2)
        }
    }

    private func statusColor(_ status: PaymentStatus) -> Color {
        switch status {
        case .paid: return .appSuccess
        case .pending: return .orange
        case .late: return .appDanger
        case .partial: return .yellow
        case .carried: return .purple
        }
    }
}

// MARK: - Fund Investments Section
struct FundInvestmentsSection: View {
    let holdings: [HoldingDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("استثمارات الصندوق")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            if holdings.isEmpty {
                Text("لا توجد استثمارات بعد")
                    .foregroundColor(.white.opacity(0.5))
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(holdings) { holding in
                    AssetCard(holding: holding)
                        .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Fund Performance Section
struct FundPerformanceSection: View {
    let summary: FundSummaryData?
    let members: [FundMember]

    var body: some View {
        VStack(spacing: 16) {
            if let summary = summary {
                VStack(spacing: 12) {
                    Text("أداء الصندوق")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    HStack {
                        SummaryItem(title: "إجمالي المستثمر", value: summary.totalInvested.formattedSAR(), color: .white)
                        Spacer()
                        SummaryItem(title: "الربح الإجمالي", value: summary.totalReturn.formattedSAR(),
                                   color: summary.totalReturn >= 0 ? .appSuccess : .appDanger)
                    }
                    .padding()
                    .background(Color.appCardBg)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }

            // Member shares breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("نصيب كل عضو")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                ForEach(members) { member in
                    MemberShareRow(member: member, totalUnits: members.reduce(0) { $0 + $1.units },
                                  totalValue: summary?.totalValue ?? 0)
                }
            }
        }
    }
}

struct MemberShareRow: View {
    let member: FundMember
    let totalUnits: Int
    let totalValue: Decimal

    var sharePercentage: Decimal {
        guard totalUnits > 0 else { return 0 }
        return (Decimal(member.units) / Decimal(totalUnits)) * 100
    }

    var shareValue: Decimal {
        guard totalUnits > 0 else { return 0 }
        return (Decimal(member.units) / Decimal(totalUnits)) * totalValue
    }

    var body: some View {
        HStack {
            Text(member.name)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            VStack(alignment: .trailing) {
                Text(shareValue.formattedSAR())
                    .font(.subheadline.bold())
                    .foregroundColor(.appGold)
                Text("\(sharePercentage.formatted())% | \(member.units) وحدة")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.appCardBg)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Create Fund View
struct CreateFundView: View {
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @State private var name = ""
    @State private var unitPrice = ""
    @State private var paymentDay = 1
    @State private var startDate = Date()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    FormField(label: "اسم الصندوق", placeholder: "مثال: صندوق العائلة 2024", text: $name)

                    FormField(label: "قيمة الوحدة الشهرية (ر.س)", placeholder: "مثال: 1000", text: $unitPrice)
                        .keyboardType(.decimalPad)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("يوم الاستحقاق الشهري")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)

                        Stepper("يوم \(paymentDay)", value: $paymentDay, in: 1...28)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.appCardBg)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

                    DatePicker("تاريخ البدء", selection: $startDate, displayedComponents: .date)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("إنشاء صندوق جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { isPresented = false }
                        .foregroundColor(.appGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { saveFund() }
                        .foregroundColor(.appGold)
                        .bold()
                        .disabled(name.isEmpty || unitPrice.isEmpty)
                }
            }
        }
    }

    private func saveFund() {
        guard let price = Decimal(string: unitPrice), !name.isEmpty else { return }
        let db = DatabaseManager.shared
        let fund = Fund(name: name, unitPrice: price, paymentDayOfMonth: paymentDay, startDate: startDate)
        let now = ISO8601DateFormatter().string(from: Date())
        let startStr = ISO8601DateFormatter().string(from: startDate)

        db.execute("""
            INSERT INTO funds (id, name, currency, unit_price, payment_day_of_month, start_date, is_active, cash_balance, created_at)
            VALUES ('\(fund.id.uuidString)', '\(name)', 'SAR', \(price), \(paymentDay),
            '\(startStr)', 1, 0, '\(now)');
        """)

        onSave()
        isPresented = false
    }
}

// MARK: - Add Member View
struct AddMemberView: View {
    let fundId: UUID
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var units = 1
    @State private var enableWebAccess = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    FormField(label: "الاسم الكامل", placeholder: "اسم العضو", text: $name)
                    FormField(label: "رقم الجوال", placeholder: "05xxxxxxxx", text: $phone)
                        .keyboardType(.phonePad)
                    FormField(label: "البريد الإلكتروني (اختياري)", placeholder: "example@email.com", text: $email)
                        .keyboardType(.emailAddress)

                    Stepper("عدد الوحدات: \(units)", value: $units, in: 1...10)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    Toggle("تفعيل الوصول لبوابة الويب", isOn: $enableWebAccess)
                        .foregroundColor(.white)
                        .tint(.appGold)
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    if enableWebAccess {
                        Text("سيتم إنشاء رمز وصول تلقائي للعضو للدخول من الجوال")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("إضافة عضو")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { isPresented = false }.foregroundColor(.appGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { saveMember() }
                        .foregroundColor(.appGold).bold()
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveMember() {
        let db = DatabaseManager.shared
        var member = FundMember(fundId: fundId, name: name, phone: phone.isEmpty ? nil : phone,
                                email: email.isEmpty ? nil : email, units: units)
        member.webAccessEnabled = enableWebAccess
        let now = ISO8601DateFormatter().string(from: Date())

        db.execute("""
            INSERT INTO fund_members (id, fund_id, name, phone, email, units, join_date,
            is_active, web_access_code, web_access_enabled)
            VALUES ('\(member.id.uuidString)', '\(fundId.uuidString)', '\(name)',
            \(phone.isEmpty ? "NULL" : "'\(phone)'"),
            \(email.isEmpty ? "NULL" : "'\(email)'"),
            \(units), '\(now)', 1, '\(member.webAccessCode ?? "")', \(enableWebAccess ? 1 : 0));
        """)

        onSave()
        isPresented = false
    }
}

// MARK: - Record Payment View
struct RecordPaymentView: View {
    let fundId: UUID
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @StateObject private var viewModel = RecordPaymentViewModel()
    @State private var selectedMembers: Set<UUID> = []
    @State private var amount = ""
    @State private var paymentDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("اختر الأعضاء الذين دفعوا")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ForEach(viewModel.members) { member in
                        HStack {
                            Image(systemName: selectedMembers.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedMembers.contains(member.id) ? .appGold : .white.opacity(0.4))
                                .font(.title3)
                            Text(member.name)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(member.units) × الوحدة")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(12)
                        .background(selectedMembers.contains(member.id) ? Color.appGold.opacity(0.1) : Color.appCardBg)
                        .cornerRadius(12)
                        .onTapGesture {
                            if selectedMembers.contains(member.id) {
                                selectedMembers.remove(member.id)
                            } else {
                                selectedMembers.insert(member.id)
                            }
                        }
                        .padding(.horizontal)
                    }

                    DatePicker("تاريخ الدفع", selection: $paymentDate, displayedComponents: .date)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    FormField(label: "ملاحظات (اختياري)", placeholder: "مثال: حوالة بنكية", text: $notes)
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("تسجيل دفعات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { isPresented = false }.foregroundColor(.appGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { recordPayments() }
                        .foregroundColor(.appGold).bold()
                        .disabled(selectedMembers.isEmpty)
                }
            }
            .onAppear { viewModel.loadMembers(fundId: fundId) }
        }
    }

    private func recordPayments() {
        let db = DatabaseManager.shared
        let dateStr = ISO8601DateFormatter().string(from: paymentDate)

        for memberId in selectedMembers {
            guard let member = viewModel.members.first(where: { $0.id == memberId }) else { continue }
            guard let fund = db.query("SELECT unit_price FROM funds WHERE id = ?", params: [fundId.uuidString]).first,
                  let unitPrice = (fund["unit_price"] as? Double).map({ Decimal($0) }) else { continue }

            let dueAmount = unitPrice * Decimal(member.units)
            let paymentId = UUID().uuidString

            db.execute("""
                INSERT OR REPLACE INTO fund_payments
                (id, fund_id, member_id, member_name, due_date, due_amount, paid_amount,
                 payment_date, status, notes)
                VALUES ('\(paymentId)', '\(fundId.uuidString)', '\(memberId.uuidString)',
                '\(member.name)', '\(dateStr)', \(dueAmount), \(dueAmount),
                '\(dateStr)', 'PAID', \(notes.isEmpty ? "NULL" : "'\(notes)'"));
            """)
        }

        onSave()
        isPresented = false
    }
}

class RecordPaymentViewModel: ObservableObject {
    @Published var members: [FundMember] = []

    func loadMembers(fundId: UUID) {
        let db = DatabaseManager.shared
        let rows = db.query("SELECT * FROM fund_members WHERE fund_id = ? AND is_active = 1",
                            params: [fundId.uuidString])
        members = rows.compactMap { row in
            guard let idStr = row["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let name = row["name"] as? String else { return nil }
            return FundMember(id: id, fundId: fundId, name: name,
                              units: row["units"] as? Int ?? 1)
        }
    }
}

// MARK: - View Models
struct FundSummaryData {
    var totalValue: Decimal
    var totalInvested: Decimal
    var totalReturn: Decimal
    var returnPct: Decimal
    var navPerUnit: Decimal
    var latePaymentsCount: Int
}

class FundsViewModel: ObservableObject {
    @Published var funds: [Fund] = []
    @Published var fundSummaries: [UUID: FundSummaryData] = [:]

    func loadFunds() {
        let db = DatabaseManager.shared
        let rows = db.query("SELECT * FROM funds WHERE is_active = 1 ORDER BY created_at DESC")

        funds = rows.compactMap { row in
            guard let idStr = row["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let name = row["name"] as? String,
                  let unitPrice = (row["unit_price"] as? Double).map({ Decimal($0) }) else { return nil }

            var fund = Fund(id: id, name: name, unitPrice: unitPrice)
            fund.cashBalance = Decimal(row["cash_balance"] as? Double ?? 0)

            // Load members
            let memberRows = db.query("SELECT * FROM fund_members WHERE fund_id = ? AND is_active = 1",
                                     params: [idStr])
            fund.members = memberRows.compactMap { mr in
                guard let midStr = mr["id"] as? String, let mid = UUID(uuidString: midStr),
                      let mname = mr["name"] as? String else { return nil }
                return FundMember(id: mid, fundId: id, name: mname,
                                  units: mr["units"] as? Int ?? 1)
            }

            // Calculate summary
            let lateRows = db.query("""
                SELECT COUNT(*) as cnt FROM fund_payments
                WHERE fund_id = ? AND status = 'LATE'
            """, params: [idStr])
            let lateCount = lateRows.first?["cnt"] as? Int ?? 0

            fundSummaries[id] = FundSummaryData(
                totalValue: fund.cashBalance,
                totalInvested: fund.totalMonthlyContribution,
                totalReturn: 0,
                returnPct: 0,
                navPerUnit: fund.totalUnits > 0 ? fund.cashBalance / Decimal(fund.totalUnits) : 0,
                latePaymentsCount: lateCount
            )

            return fund
        }
    }
}

class FundDetailViewModel: ObservableObject {
    @Published var fund: Fund?
    @Published var summary: FundSummaryData?
    @Published var members: [FundMember] = []
    @Published var pendingPayments: [FundPayment] = []
    @Published var holdings: [HoldingDisplay] = []

    func loadData(fundId: UUID) {
        let db = DatabaseManager.shared
        let fundsVM = FundsViewModel()
        fundsVM.loadFunds()
        fund = fundsVM.funds.first(where: { $0.id == fundId })
        summary = fundsVM.fundSummaries[fundId]
        members = fund?.members ?? []

        let paymentRows = db.query("""
            SELECT * FROM fund_payments WHERE fund_id = ? AND status != 'PAID'
            ORDER BY due_date ASC
        """, params: [fundId.uuidString])

        pendingPayments = paymentRows.compactMap { row in
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let midStr = row["member_id"] as? String, let memberId = UUID(uuidString: midStr),
                  let memberName = row["member_name"] as? String,
                  let dateStr = row["due_date"] as? String,
                  let dueDate = ISO8601DateFormatter().date(from: dateStr),
                  let dueAmount = (row["due_amount"] as? Double).map({ Decimal($0) }) else { return nil }

            var payment = FundPayment(id: id, fundId: fundId, memberId: memberId,
                                     memberName: memberName, dueDate: dueDate, dueAmount: dueAmount)
            payment.paidAmount = Decimal(row["paid_amount"] as? Double ?? 0)
            payment.status = PaymentStatus(rawValue: row["status"] as? String ?? "PENDING") ?? .pending
            return payment
        }
    }
}

struct EmptyFundsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            Text("لا توجد صناديق بعد")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            Text("أنشئ صندوقك الأول الآن")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 60)
    }
}
