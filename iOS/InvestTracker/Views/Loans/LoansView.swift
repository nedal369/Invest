import SwiftUI

struct LoansView: View {
    @StateObject private var viewModel = LoansViewModel()
    @State private var showNewLoan = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary
                    LoansSummaryCard(
                        totalLoaned: viewModel.totalLoaned,
                        totalPaid: viewModel.totalPaid,
                        overdue: viewModel.overdueCount
                    )

                    // Active Loans
                    if viewModel.activeLoans.isEmpty {
                        EmptyLoansView()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("القروض النشطة")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ForEach(viewModel.activeLoans) { loan in
                                NavigationLink(destination: LoanDetailView(loan: loan)) {
                                    LoanCard(loan: loan)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Completed Loans
                    if !viewModel.completedLoans.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("القروض المسددة")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal)

                            ForEach(viewModel.completedLoans) { loan in
                                LoanCard(loan: loan, isCompleted: true)
                                    .padding(.horizontal)
                                    .opacity(0.7)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("القروض الحسنة")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewLoan = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.appGold)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showNewLoan) {
                NewLoanView(isPresented: $showNewLoan) {
                    viewModel.loadData()
                }
            }
            .onAppear { viewModel.loadData() }
        }
    }
}

// MARK: - Loans Summary Card
struct LoansSummaryCard: View {
    let totalLoaned: Decimal
    let totalPaid: Decimal
    let overdue: Int

    var body: some View {
        HStack {
            VStack(spacing: 4) {
                Text("إجمالي القروض")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(totalLoaned.formattedSAR())
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40).background(Color.white.opacity(0.2))

            VStack(spacing: 4) {
                Text("تم تحصيله")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(totalPaid.formattedSAR())
                    .font(.subheadline.bold())
                    .foregroundColor(.appSuccess)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40).background(Color.white.opacity(0.2))

            VStack(spacing: 4) {
                Text("متأخر سداد")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(overdue)")
                    .font(.subheadline.bold())
                    .foregroundColor(overdue > 0 ? .appDanger : .appSuccess)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.appCardBg)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Loan Card
struct LoanCard: View {
    let loan: Loan
    var isCompleted: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(loan.memberName)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text("من \(loan.fundId.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(loan.principalAmount.formattedSAR())
                        .font(.headline.bold())
                        .foregroundColor(isCompleted ? .appSuccess : .appGold)
                    Text(loan.status.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor(loan.status).opacity(0.2))
                        .foregroundColor(statusColor(loan.status))
                        .cornerRadius(6)
                }
            }

            if !isCompleted {
                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("تم سداد")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(loan.completionPercentage))%")
                            .font(.caption.bold())
                            .foregroundColor(.appGold)
                    }
                    ProgressView(value: loan.completionPercentage, total: 100)
                        .tint(.appGold)
                }

                HStack {
                    Text("القسط الشهري: \(loan.monthlyInstallment.formattedSAR())")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    if let next = loan.nextPaymentDate {
                        Text("القادم: \(next.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.appCardBg)
        .cornerRadius(14)
    }

    private func statusColor(_ status: LoanStatus) -> Color {
        switch status {
        case .active: return .appGold
        case .completed: return .appSuccess
        case .defaulted: return .appDanger
        case .cancelled: return .gray
        }
    }
}

// MARK: - Loan Detail View
struct LoanDetailView: View {
    let loan: Loan
    @State private var installments: [LoanInstallment] = []
    @State private var showPayInstallment = false
    @State private var selectedInstallment: LoanInstallment?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Loan Info Card
                VStack(spacing: 12) {
                    HStack {
                        InfoItem(title: "المبلغ الأصلي", value: loan.principalAmount.formattedSAR())
                        Spacer()
                        InfoItem(title: "القسط الشهري", value: loan.monthlyInstallment.formattedSAR())
                        Spacer()
                        InfoItem(title: "المتبقي", value: loan.remainingBalance.formattedSAR())
                    }

                    ProgressView(value: loan.completionPercentage, total: 100)
                        .tint(.appGold)

                    HStack {
                        Text("صرف في: \(loan.disbursementDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("آخر قسط: \(loan.lastPaymentDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding()
                .background(Color.appCardBg)
                .cornerRadius(16)
                .padding(.horizontal)

                // Installments
                VStack(alignment: .leading, spacing: 8) {
                    Text("جدول السداد")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    ForEach(installments) { installment in
                        InstallmentRow(installment: installment) {
                            selectedInstallment = installment
                            showPayInstallment = true
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.appDarkBlue.ignoresSafeArea())
        .navigationTitle(loan.memberName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPayInstallment) {
            if let installment = selectedInstallment {
                PayInstallmentView(installment: installment, isPresented: $showPayInstallment) {
                    loadInstallments()
                }
            }
        }
        .onAppear { loadInstallments() }
    }

    private func loadInstallments() {
        let db = DatabaseManager.shared
        let rows = db.query("""
            SELECT * FROM loan_installments WHERE loan_id = ? ORDER BY installment_number ASC
        """, params: [loan.id.uuidString])

        installments = rows.compactMap { row in
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let dateStr = row["due_date"] as? String,
                  let dueDate = ISO8601DateFormatter().date(from: dateStr),
                  let dueAmount = (row["due_amount"] as? Double).map({ Decimal($0) }),
                  let num = row["installment_number"] as? Int else { return nil }

            var inst = LoanInstallment(id: id, loanId: loan.id, installmentNumber: num,
                                       dueDate: dueDate, dueAmount: dueAmount)
            inst.paidAmount = Decimal(row["paid_amount"] as? Double ?? 0)
            inst.status = LoanInstallment.InstallmentStatus(rawValue: row["status"] as? String ?? "UPCOMING") ?? .upcoming
            if let paidDateStr = row["paid_date"] as? String {
                inst.paidDate = ISO8601DateFormatter().date(from: paidDateStr)
            }
            return inst
        }
    }
}

// MARK: - Installment Row
struct InstallmentRow: View {
    let installment: LoanInstallment
    let onPay: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("القسط #\(installment.installmentNumber)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(installment.dueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                if installment.isOverdue {
                    Text("متأخر \(installment.daysOverdue) يوم")
                        .font(.caption2)
                        .foregroundColor(.appDanger)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                VStack(alignment: .trailing) {
                    Text(installment.dueAmount.formattedSAR())
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(installment.status.displayName)
                        .font(.caption)
                        .foregroundColor(statusColor(installment.status))
                }

                if installment.status != .paid {
                    Button(action: onPay) {
                        Text("سداد")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appGold)
                            .foregroundColor(.appDarkBlue)
                            .cornerRadius(8)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.appSuccess)
                }
            }
        }
        .padding(12)
        .background(Color.appCardBg)
        .cornerRadius(12)
    }

    private func statusColor(_ status: LoanInstallment.InstallmentStatus) -> Color {
        switch status {
        case .upcoming: return .white.opacity(0.5)
        case .due: return .orange
        case .paid: return .appSuccess
        case .late: return .appDanger
        case .partiallyPaid: return .yellow
        }
    }
}

// MARK: - Pay Installment View
struct PayInstallmentView: View {
    let installment: LoanInstallment
    @Binding var isPresented: Bool
    let onPay: () -> Void

    @State private var paymentDate = Date()
    @State private var amount: String = ""
    @State private var notes = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("سداد القسط #\(installment.installmentNumber)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("المستحق: \(installment.dueAmount.formattedSAR())")
                        .font(.subheadline)
                        .foregroundColor(.appGold)
                }

                FormField(label: "المبلغ المدفوع", placeholder: "\(installment.dueAmount)", text: $amount)
                    .keyboardType(.decimalPad)

                DatePicker("تاريخ الدفع", selection: $paymentDate, displayedComponents: .date)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.appCardBg)
                    .cornerRadius(12)
                    .padding(.horizontal)

                FormField(label: "ملاحظات", placeholder: "اختياري", text: $notes)

                Spacer()

                Button {
                    recordPayment()
                } label: {
                    Text("تأكيد السداد")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appGold)
                        .foregroundColor(.appDarkBlue)
                        .cornerRadius(14)
                        .bold()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("تسجيل سداد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { isPresented = false }.foregroundColor(.appGold)
                }
            }
        }
        .onAppear { amount = "\(installment.dueAmount)" }
    }

    private func recordPayment() {
        guard let paidAmount = Decimal(string: amount) else { return }
        let db = DatabaseManager.shared
        let dateStr = ISO8601DateFormatter().string(from: paymentDate)
        let status: String = paidAmount >= installment.dueAmount ? "PAID" : "PARTIAL"

        db.execute("""
            UPDATE loan_installments
            SET paid_amount = \(paidAmount), paid_date = '\(dateStr)', status = '\(status)'
            WHERE id = '\(installment.id.uuidString)';
        """)

        onPay()
        isPresented = false
    }
}

// MARK: - New Loan View
struct NewLoanView: View {
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @StateObject private var viewModel = NewLoanViewModel()
    @State private var selectedFundId: UUID?
    @State private var selectedMemberId: UUID?
    @State private var amount = ""
    @State private var disbursementDate = Date()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Fund Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("الصندوق")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)

                        Picker("الصندوق", selection: $selectedFundId) {
                            Text("اختر صندوقاً").tag(UUID?.none)
                            ForEach(viewModel.funds) { fund in
                                Text(fund.name).tag(UUID?.some(fund.id))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .onChange(of: selectedFundId) { id in
                            if let id = id { viewModel.loadMembers(fundId: id) }
                        }
                    }

                    if !viewModel.members.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("العضو")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal)

                            Picker("العضو", selection: $selectedMemberId) {
                                Text("اختر عضواً").tag(UUID?.none)
                                ForEach(viewModel.members) { member in
                                    Text(member.name).tag(UUID?.some(member.id))
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color.appCardBg)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        }
                    }

                    FormField(label: "مبلغ القرض (ر.س)", placeholder: "الحد الأعلى: اشتراكه السنوي", text: $amount)
                        .keyboardType(.decimalPad)

                    DatePicker("تاريخ الصرف", selection: $disbursementDate, displayedComponents: .date)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    if let memberId = selectedMemberId,
                       let member = viewModel.members.first(where: { $0.id == memberId }),
                       let fundId = selectedFundId,
                       let fund = viewModel.funds.first(where: { $0.id == fundId }),
                       let amt = Decimal(string: amount) {
                        let annualContribution = fund.unitPrice * Decimal(member.units) * 12
                        let monthly = (amt / 12).rounded(scale: 2, roundingMode: .up)

                        VStack(spacing: 8) {
                            Text("ملخص القرض")
                                .font(.headline)
                                .foregroundColor(.appGold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            DetailRow(label: "المبلغ", value: amt.formattedSAR())
                            DetailRow(label: "القسط الشهري", value: monthly.formattedSAR())
                            DetailRow(label: "المدة", value: "12 شهر")
                            DetailRow(label: "حد اشتراكه السنوي", value: annualContribution.formattedSAR())
                            if amt > annualContribution {
                                Label("تجاوز الحد المسموح", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.appDanger)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.appCardBg)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("قرض حسن جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { isPresented = false }.foregroundColor(.appGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("حفظ") { saveLoan() }
                        .foregroundColor(.appGold).bold()
                        .disabled(selectedFundId == nil || selectedMemberId == nil || amount.isEmpty)
                }
            }
            .onAppear { viewModel.loadFunds() }
        }
    }

    private func saveLoan() {
        guard let fundId = selectedFundId, let memberId = selectedMemberId,
              let amt = Decimal(string: amount),
              let member = viewModel.members.first(where: { $0.id == memberId }) else { return }

        var loan = Loan(fundId: fundId, memberId: memberId, memberName: member.name,
                       principalAmount: amt, disbursementDate: disbursementDate)
        loan.generateInstallments()

        let db = DatabaseManager.shared
        let dateStr = ISO8601DateFormatter().string(from: disbursementDate)
        let firstStr = ISO8601DateFormatter().string(from: loan.firstPaymentDate)
        let lastStr = ISO8601DateFormatter().string(from: loan.lastPaymentDate)

        db.execute("""
            INSERT INTO loans (id, fund_id, member_id, member_name, principal_amount,
            monthly_installment, disbursement_date, first_payment_date, last_payment_date,
            total_months, status)
            VALUES ('\(loan.id.uuidString)', '\(fundId.uuidString)', '\(memberId.uuidString)',
            '\(member.name)', \(amt), \(loan.monthlyInstallment), '\(dateStr)',
            '\(firstStr)', '\(lastStr)', 12, 'ACTIVE');
        """)

        // Insert installments
        for inst in loan.installments {
            let instDateStr = ISO8601DateFormatter().string(from: inst.dueDate)
            db.execute("""
                INSERT INTO loan_installments (id, loan_id, installment_number, due_date,
                due_amount, paid_amount, status)
                VALUES ('\(inst.id.uuidString)', '\(loan.id.uuidString)',
                \(inst.installmentNumber), '\(instDateStr)', \(inst.dueAmount), 0, 'UPCOMING');
            """)
        }

        onSave()
        isPresented = false
    }
}

class NewLoanViewModel: ObservableObject {
    @Published var funds: [Fund] = []
    @Published var members: [FundMember] = []

    func loadFunds() {
        let db = DatabaseManager.shared
        let rows = db.query("SELECT * FROM funds WHERE is_active = 1")
        funds = rows.compactMap { row in
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let name = row["name"] as? String,
                  let unitPrice = (row["unit_price"] as? Double).map({ Decimal($0) }) else { return nil }
            return Fund(id: id, name: name, unitPrice: unitPrice)
        }
    }

    func loadMembers(fundId: UUID) {
        let db = DatabaseManager.shared
        let rows = db.query("SELECT * FROM fund_members WHERE fund_id = ? AND is_active = 1",
                            params: [fundId.uuidString])
        members = rows.compactMap { row in
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let name = row["name"] as? String else { return nil }
            return FundMember(id: id, fundId: fundId, name: name,
                              units: row["units"] as? Int ?? 1)
        }
    }
}

class LoansViewModel: ObservableObject {
    @Published var activeLoans: [Loan] = []
    @Published var completedLoans: [Loan] = []
    @Published var totalLoaned: Decimal = 0
    @Published var totalPaid: Decimal = 0
    @Published var overdueCount: Int = 0

    func loadData() {
        let db = DatabaseManager.shared
        let rows = db.query("SELECT * FROM loans ORDER BY disbursement_date DESC")

        var active: [Loan] = []
        var completed: [Loan] = []
        var loaned = Decimal(0)
        var paid = Decimal(0)
        var overdue = 0

        for row in rows {
            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let fundIdStr = row["fund_id"] as? String, let fundId = UUID(uuidString: fundIdStr),
                  let memberIdStr = row["member_id"] as? String, let memberId = UUID(uuidString: memberIdStr),
                  let memberName = row["member_name"] as? String,
                  let principal = (row["principal_amount"] as? Double).map({ Decimal($0) }),
                  let dateStr = row["disbursement_date"] as? String,
                  let disbDate = ISO8601DateFormatter().date(from: dateStr) else { continue }

            var loan = Loan(id: id, fundId: fundId, memberId: memberId,
                           memberName: memberName, principalAmount: principal,
                           disbursementDate: disbDate)
            loan.status = LoanStatus(rawValue: row["status"] as? String ?? "ACTIVE") ?? .active

            // Load installments
            let instRows = db.query("SELECT * FROM loan_installments WHERE loan_id = ? ORDER BY installment_number",
                                    params: [idStr])
            loan.installments = instRows.compactMap { ir in
                guard let instIdStr = ir["id"] as? String, let instId = UUID(uuidString: instIdStr),
                      let instDateStr = ir["due_date"] as? String,
                      let instDate = ISO8601DateFormatter().date(from: instDateStr),
                      let dueAmt = (ir["due_amount"] as? Double).map({ Decimal($0) }),
                      let num = ir["installment_number"] as? Int else { return nil }

                var inst = LoanInstallment(id: instId, loanId: id, installmentNumber: num,
                                           dueDate: instDate, dueAmount: dueAmt)
                inst.paidAmount = Decimal(ir["paid_amount"] as? Double ?? 0)
                inst.status = LoanInstallment.InstallmentStatus(rawValue: ir["status"] as? String ?? "UPCOMING") ?? .upcoming
                return inst
            }

            loaned += principal
            paid += loan.totalPaid

            let overdueInsts = loan.installments.filter { $0.isOverdue }.count
            overdue += overdueInsts

            if loan.status == .active {
                active.append(loan)
            } else if loan.status == .completed {
                completed.append(loan)
            }
        }

        DispatchQueue.main.async {
            self.activeLoans = active
            self.completedLoans = completed
            self.totalLoaned = loaned
            self.totalPaid = paid
            self.overdueCount = overdue
        }
    }
}

struct EmptyLoansView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            Text("لا توجد قروض نشطة")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 60)
    }
}
