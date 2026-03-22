import Foundation

// MARK: - Transaction Type
enum TransactionType: String, Codable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"
    case deposit = "DEPOSIT"
    case withdraw = "WITHDRAW"
    case dividend = "DIVIDEND"
    case fee = "FEE"
    case tax = "TAX"
    case split = "SPLIT"
    case bonus = "BONUS"
    case transfer = "TRANSFER"
    case fxConversion = "FX_CONVERSION"

    var displayName: String {
        switch self {
        case .buy: return "شراء"
        case .sell: return "بيع"
        case .deposit: return "إيداع"
        case .withdraw: return "سحب"
        case .dividend: return "توزيع أرباح"
        case .fee: return "رسوم"
        case .tax: return "ضريبة"
        case .split: return "تجزئة"
        case .bonus: return "أسهم مجانية"
        case .transfer: return "تحويل"
        case .fxConversion: return "تحويل عملة"
        }
    }

    var icon: String {
        switch self {
        case .buy: return "arrow.down.circle.fill"
        case .sell: return "arrow.up.circle.fill"
        case .deposit: return "plus.circle.fill"
        case .withdraw: return "minus.circle.fill"
        case .dividend: return "dollarsign.circle.fill"
        case .fee: return "exclamationmark.circle.fill"
        case .tax: return "building.columns.fill"
        case .split: return "scissors"
        case .bonus: return "gift.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        case .fxConversion: return "arrow.2.circlepath"
        }
    }

    var isInflow: Bool {
        switch self {
        case .buy, .deposit, .dividend, .bonus: return true
        case .sell, .withdraw, .fee, .tax: return false
        case .split, .transfer, .fxConversion: return true
        }
    }
}

// MARK: - Transaction Status
enum TransactionStatus: String, Codable {
    case pending = "PENDING"      // pending OCR review
    case confirmed = "CONFIRMED"  // confirmed by user
    case cancelled = "CANCELLED"
}

// MARK: - Transaction
struct Transaction: Identifiable, Codable {
    let id: UUID
    var type: TransactionType
    var date: Date
    var assetId: UUID?
    var assetSymbol: String?
    var portfolioId: UUID?   // nil = personal
    var fundId: UUID?
    var quantity: Decimal
    var price: Decimal
    var amount: Decimal      // total amount = quantity * price
    var currency: Currency
    var exchangeRate: Decimal?   // if converting to SAR
    var amountSAR: Decimal       // always in SAR
    var fees: Decimal
    var taxes: Decimal
    var notes: String?
    var status: TransactionStatus
    var sourceImagePath: String?  // OCR source image
    var ocrRawData: String?       // raw OCR output
    var createdAt: Date
    var updatedAt: Date
    var hijriDate: HijriDate?

    var netAmount: Decimal {
        return amount - fees - taxes
    }

    var netAmountSAR: Decimal {
        return amountSAR - (fees + taxes) * (exchangeRate ?? 1)
    }

    init(id: UUID = UUID(), type: TransactionType, date: Date = Date(),
         assetId: UUID? = nil, assetSymbol: String? = nil,
         portfolioId: UUID? = nil, fundId: UUID? = nil,
         quantity: Decimal = 0, price: Decimal = 0,
         currency: Currency = .sar, fees: Decimal = 0, taxes: Decimal = 0,
         notes: String? = nil) {
        self.id = id
        self.type = type
        self.date = date
        self.assetId = assetId
        self.assetSymbol = assetSymbol
        self.portfolioId = portfolioId
        self.fundId = fundId
        self.quantity = quantity
        self.price = price
        self.amount = quantity * price
        self.currency = currency
        self.amountSAR = quantity * price
        self.fees = fees
        self.taxes = taxes
        self.notes = notes
        self.status = .confirmed
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Dividend Record
struct DividendRecord: Identifiable, Codable {
    let id: UUID
    var assetId: UUID
    var assetSymbol: String
    var assetName: String
    var transactionId: UUID
    var date: Date
    var amountPerShare: Decimal
    var totalShares: Decimal
    var totalAmount: Decimal
    var currency: Currency
    var amountSAR: Decimal
    var portfolioId: UUID?
    var fundId: UUID?
    var isZakatIncluded: Bool  // added to zakat base after haol

    init(id: UUID = UUID(), assetId: UUID, assetSymbol: String, assetName: String,
         transactionId: UUID, date: Date, amountPerShare: Decimal, totalShares: Decimal,
         currency: Currency, amountSAR: Decimal) {
        self.id = id
        self.assetId = assetId
        self.assetSymbol = assetSymbol
        self.assetName = assetName
        self.transactionId = transactionId
        self.date = date
        self.amountPerShare = amountPerShare
        self.totalShares = totalShares
        self.totalAmount = amountPerShare * totalShares
        self.currency = currency
        self.amountSAR = amountSAR
        self.isZakatIncluded = false
    }
}
