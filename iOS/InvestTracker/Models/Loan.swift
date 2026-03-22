import Foundation

// MARK: - Loan Status
enum LoanStatus: String, Codable, CaseIterable {
    case active = "ACTIVE"
    case completed = "COMPLETED"
    case defaulted = "DEFAULTED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .active: return "نشط"
        case .completed: return "مسدد"
        case .defaulted: return "متعثر"
        case .cancelled: return "ملغي"
        }
    }
}

// MARK: - Loan (Qard Hasan)
struct Loan: Identifiable, Codable {
    let id: UUID
    var fundId: UUID
    var memberId: UUID
    var memberName: String

    var principalAmount: Decimal      // loan amount
    var monthlyInstallment: Decimal   // principal / 12
    var disbursementDate: Date        // when loan was given
    var firstPaymentDate: Date        // first month after disbursement
    var lastPaymentDate: Date         // disbursement + 13 months
    var totalMonths: Int              // always 12

    var status: LoanStatus
    var approvedBy: String?           // admin name
    var notes: String?

    var installments: [LoanInstallment] = []

    var totalPaid: Decimal {
        installments.filter { $0.status == .paid }.reduce(0) { $0 + $1.paidAmount }
    }

    var remainingBalance: Decimal {
        return principalAmount - totalPaid
    }

    var nextPaymentDate: Date? {
        installments.filter { $0.status != .paid }.sorted { $0.dueDate < $1.dueDate }.first?.dueDate
    }

    var completionPercentage: Double {
        guard principalAmount > 0 else { return 0 }
        return Double(truncating: (totalPaid / principalAmount * 100) as NSDecimalNumber)
    }

    init(id: UUID = UUID(), fundId: UUID, memberId: UUID, memberName: String,
         principalAmount: Decimal, disbursementDate: Date = Date()) {
        self.id = id
        self.fundId = fundId
        self.memberId = memberId
        self.memberName = memberName
        self.principalAmount = principalAmount
        self.monthlyInstallment = (principalAmount / 12).rounded(scale: 2, roundingMode: .up)
        self.disbursementDate = disbursementDate

        // First payment is next month
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: disbursementDate)
        comps.month! += 1
        self.firstPaymentDate = Calendar.current.date(from: comps) ?? disbursementDate
        comps.month! += 12
        self.lastPaymentDate = Calendar.current.date(from: comps) ?? disbursementDate

        self.totalMonths = 12
        self.status = .active
    }

    mutating func generateInstallments() {
        installments = []
        for month in 0..<12 {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: firstPaymentDate)
            comps.month! += month
            let dueDate = Calendar.current.date(from: comps) ?? firstPaymentDate
            let amount = month == 11 ? remainingAfterEleven() : monthlyInstallment

            let installment = LoanInstallment(
                loanId: id,
                installmentNumber: month + 1,
                dueDate: dueDate,
                dueAmount: amount
            )
            installments.append(installment)
        }
    }

    private func remainingAfterEleven() -> Decimal {
        return principalAmount - (monthlyInstallment * 11)
    }
}

// MARK: - Loan Installment
struct LoanInstallment: Identifiable, Codable {
    let id: UUID
    var loanId: UUID
    var installmentNumber: Int
    var dueDate: Date
    var dueAmount: Decimal
    var paidAmount: Decimal
    var paidDate: Date?
    var status: InstallmentStatus
    var notes: String?

    var isOverdue: Bool {
        return Date() > dueDate && status != .paid
    }

    var daysOverdue: Int {
        guard isOverdue else { return 0 }
        return Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
    }

    enum InstallmentStatus: String, Codable {
        case upcoming = "UPCOMING"
        case due = "DUE"
        case paid = "PAID"
        case late = "LATE"
        case partiallyPaid = "PARTIAL"

        var displayName: String {
            switch self {
            case .upcoming: return "قادم"
            case .due: return "مستحق"
            case .paid: return "مسدد"
            case .late: return "متأخر"
            case .partiallyPaid: return "جزئي"
            }
        }
    }

    init(id: UUID = UUID(), loanId: UUID, installmentNumber: Int,
         dueDate: Date, dueAmount: Decimal) {
        self.id = id
        self.loanId = loanId
        self.installmentNumber = installmentNumber
        self.dueDate = dueDate
        self.dueAmount = dueAmount
        self.paidAmount = 0
        self.status = .upcoming
    }
}

// MARK: - Decimal Extension
extension Decimal {
    func rounded(scale: Int, roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var result = self
        var localSelf = self
        NSDecimalRound(&result, &localSelf, scale, roundingMode)
        return result
    }
}
