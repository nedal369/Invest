import Foundation

// MARK: - Investment Fund
struct Fund: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String?
    var currency: Currency
    var unitPrice: Decimal       // fixed monthly contribution per unit
    var paymentDayOfMonth: Int   // day of month payment is due (1-28)
    var startDate: Date
    var isActive: Bool
    var createdAt: Date

    // Computed
    var members: [FundMember] = []
    var cashBalance: Decimal = 0

    var totalUnits: Int {
        members.filter { $0.isActive }.reduce(0) { $0 + $1.units }
    }

    var totalMonthlyContribution: Decimal {
        return Decimal(totalUnits) * unitPrice
    }

    init(id: UUID = UUID(), name: String, currency: Currency = .sar,
         unitPrice: Decimal, paymentDayOfMonth: Int = 1, startDate: Date = Date()) {
        self.id = id
        self.name = name
        self.currency = currency
        self.unitPrice = unitPrice
        self.paymentDayOfMonth = paymentDayOfMonth
        self.startDate = startDate
        self.isActive = true
        self.createdAt = Date()
    }
}

// MARK: - Fund Member
struct FundMember: Identifiable, Codable {
    let id: UUID
    var fundId: UUID
    var name: String
    var phone: String?
    var email: String?
    var units: Int
    var joinDate: Date
    var isActive: Bool
    var webAccessCode: String?    // for web portal login
    var webAccessEnabled: Bool

    init(id: UUID = UUID(), fundId: UUID, name: String, phone: String? = nil,
         email: String? = nil, units: Int = 1, joinDate: Date = Date()) {
        self.id = id
        self.fundId = fundId
        self.name = name
        self.phone = phone
        self.email = email
        self.units = units
        self.joinDate = joinDate
        self.isActive = true
        self.webAccessEnabled = false
        // Generate 6-digit access code
        self.webAccessCode = String(format: "%06d", Int.random(in: 100000...999999))
    }
}

// MARK: - Payment Status
enum PaymentStatus: String, Codable, CaseIterable {
    case paid = "PAID"
    case pending = "PENDING"
    case partial = "PARTIAL"
    case late = "LATE"
    case carried = "CARRIED"     // مرحّل

    var displayName: String {
        switch self {
        case .paid: return "مدفوع"
        case .pending: return "معلق"
        case .partial: return "جزئي"
        case .late: return "متأخر"
        case .carried: return "مرحّل"
        }
    }

    var color: String {  // SwiftUI color name
        switch self {
        case .paid: return "green"
        case .pending: return "orange"
        case .partial: return "yellow"
        case .late: return "red"
        case .carried: return "purple"
        }
    }
}

// MARK: - Fund Payment
struct FundPayment: Identifiable, Codable {
    let id: UUID
    var fundId: UUID
    var memberId: UUID
    var memberName: String
    var dueDate: Date
    var dueAmount: Decimal        // units * unitPrice
    var paidAmount: Decimal
    var paymentDate: Date?
    var status: PaymentStatus
    var notes: String?
    var receiptImagePath: String?
    var recordedBy: String?       // can record one transfer for multiple members

    var remainingAmount: Decimal {
        return dueAmount - paidAmount
    }

    var isPastDue: Bool {
        return Date() > dueDate && status != .paid
    }

    init(id: UUID = UUID(), fundId: UUID, memberId: UUID, memberName: String,
         dueDate: Date, dueAmount: Decimal) {
        self.id = id
        self.fundId = fundId
        self.memberId = memberId
        self.memberName = memberName
        self.dueDate = dueDate
        self.dueAmount = dueAmount
        self.paidAmount = 0
        self.status = .pending
    }
}

// MARK: - Fund Summary (computed)
struct FundSummary {
    var fund: Fund
    var totalCurrentValue: Decimal    // investments + cash
    var totalInvested: Decimal        // total contributions received
    var realizedPnL: Decimal
    var unrealizedPnL: Decimal
    var cashBalance: Decimal
    var navPerUnit: Decimal           // Net Asset Value per unit

    var totalReturn: Decimal {
        return realizedPnL + unrealizedPnL
    }

    var returnPercentage: Decimal {
        guard totalInvested > 0 else { return 0 }
        return (totalReturn / totalInvested) * 100
    }

    var memberShare: (member: FundMember, share: Decimal) -> Decimal {
        return { member, totalValue in
            guard fund.totalUnits > 0 else { return 0 }
            return (Decimal(member.units) / Decimal(fund.totalUnits)) * totalValue
        }
    }
}

// MARK: - Bulk Payment Record
struct BulkPaymentRecord: Identifiable, Codable {
    let id: UUID
    var fundId: UUID
    var date: Date
    var totalAmount: Decimal
    var notes: String?
    var paymentIds: [UUID]     // individual payment IDs covered
    var receiptImagePath: String?

    init(id: UUID = UUID(), fundId: UUID, date: Date = Date(),
         totalAmount: Decimal, paymentIds: [UUID]) {
        self.id = id
        self.fundId = fundId
        self.date = date
        self.totalAmount = totalAmount
        self.paymentIds = paymentIds
    }
}
