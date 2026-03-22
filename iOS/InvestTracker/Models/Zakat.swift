import Foundation

// MARK: - Zakat Configuration
struct ZakatConfig: Codable {
    var goldNisabGrams: Decimal = 85.0     // 85g of gold 24K
    var zakatRate: Decimal = 0.025         // 2.5%
    var reminderMonth: Int = 9             // Ramadan (month 9 Hijri)
    var lastCalculationDate: Date?
    var lastPaymentDate: Date?
    var haolStartDate: Date                // start of current haol
    var autoCalculate: Bool = true

    init() {
        self.haolStartDate = Date()
    }
}

// MARK: - Zakat Calculation
struct ZakatCalculation: Identifiable, Codable {
    let id: UUID
    var portfolioId: UUID?
    var fundId: UUID?
    var calculationDate: Date
    var hijriYear: Int
    var hijriMonth: Int

    // Nisab
    var goldPricePer24KGram: Decimal       // SAR per gram
    var nisabAmountSAR: Decimal            // 85g * price

    // Zakat Base Components
    var holdingsValue: Decimal             // value of assets that completed haol
    var cashValue: Decimal                 // cash that completed haol
    var dividendsValue: Decimal            // accumulated dividends
    var totalZakatBase: Decimal            // sum of above

    // Result
    var isNisabMet: Bool                   // base >= nisab
    var zakatDue: Decimal                  // 2.5% of base
    var status: ZakatStatus
    var paidAt: Date?
    var paidAmount: Decimal?
    var notes: String?

    // Fund-specific
    var memberBreakdown: [MemberZakatShare]?

    enum ZakatStatus: String, Codable {
        case calculated = "CALCULATED"
        case paid = "PAID"
        case partiallyPaid = "PARTIAL"
        case waived = "WAIVED"

        var displayName: String {
            switch self {
            case .calculated: return "محسوب"
            case .paid: return "مخرج"
            case .partiallyPaid: return "مخرج جزئياً"
            case .waived: return "معفى"
            }
        }
    }

    init(id: UUID = UUID(), calculationDate: Date = Date(),
         goldPrice: Decimal, holdingsValue: Decimal, cashValue: Decimal,
         dividendsValue: Decimal) {
        self.id = id
        self.calculationDate = calculationDate
        self.hijriYear = 0  // Set from HijriCalendar
        self.hijriMonth = 0
        self.goldPricePer24KGram = goldPrice
        self.nisabAmountSAR = 85 * goldPrice
        self.holdingsValue = holdingsValue
        self.cashValue = cashValue
        self.dividendsValue = dividendsValue
        self.totalZakatBase = holdingsValue + cashValue + dividendsValue
        self.isNisabMet = self.totalZakatBase >= self.nisabAmountSAR
        self.zakatDue = self.isNisabMet ? self.totalZakatBase * 0.025 : 0
        self.status = .calculated
    }
}

// MARK: - Member Zakat Share (for fund zakat)
struct MemberZakatShare: Identifiable, Codable {
    let id: UUID
    var memberId: UUID
    var memberName: String
    var units: Int
    var totalUnits: Int
    var sharePercentage: Decimal
    var zakatBase: Decimal
    var zakatDue: Decimal
    var isPaid: Bool

    var unitsFraction: Decimal {
        guard totalUnits > 0 else { return 0 }
        return Decimal(units) / Decimal(totalUnits)
    }

    init(memberId: UUID, memberName: String, units: Int, totalUnits: Int,
         totalZakatBase: Decimal) {
        self.id = UUID()
        self.memberId = memberId
        self.memberName = memberName
        self.units = units
        self.totalUnits = totalUnits
        self.sharePercentage = totalUnits > 0 ? (Decimal(units) / Decimal(totalUnits)) * 100 : 0
        self.zakatBase = totalUnits > 0 ? (Decimal(units) / Decimal(totalUnits)) * totalZakatBase : 0
        self.zakatDue = self.zakatBase * 0.025
        self.isPaid = false
    }
}

// MARK: - Zakat Payment Record
struct ZakatPaymentRecord: Identifiable, Codable {
    let id: UUID
    var zakatCalculationId: UUID
    var portfolioId: UUID?
    var fundId: UUID?
    var memberId: UUID?          // for fund member
    var paymentDate: Date
    var amountPaid: Decimal
    var notes: String?
    var receiptImagePath: String?

    init(id: UUID = UUID(), zakatCalculationId: UUID, paymentDate: Date = Date(),
         amountPaid: Decimal, notes: String? = nil) {
        self.id = id
        self.zakatCalculationId = zakatCalculationId
        self.paymentDate = paymentDate
        self.amountPaid = amountPaid
        self.notes = notes
    }
}

// MARK: - Zakat History Item (for display)
struct ZakatHistoryItem: Identifiable {
    let id = UUID()
    var year: String        // Hijri year display
    var calculationDate: Date
    var zakatBase: Decimal
    var zakatDue: Decimal
    var paidAmount: Decimal
    var status: ZakatCalculation.ZakatStatus
    var type: String        // "شخصية" or fund name
}
