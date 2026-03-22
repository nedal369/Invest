import Foundation

// MARK: - Asset Types
enum AssetType: String, Codable, CaseIterable {
    case saStock = "SA_STOCK"          // سهم سعودي
    case saFund = "SA_FUND"            // صندوق سعودي
    case usStock = "US_STOCK"          // سهم أمريكي
    case usFund = "US_FUND"            // صندوق أمريكي
    case etf = "ETF"                   // صندوق ETF
    case gold = "GOLD"                 // ذهب
    case cash = "CASH"                 // كاش

    var displayName: String {
        switch self {
        case .saStock: return "سهم سعودي"
        case .saFund: return "صندوق استثماري سعودي"
        case .usStock: return "سهم أمريكي"
        case .usFund: return "صندوق أمريكي"
        case .etf: return "ETF"
        case .gold: return "ذهب"
        case .cash: return "كاش"
        }
    }

    var currency: Currency {
        switch self {
        case .saStock, .saFund, .gold, .cash: return .sar
        case .usStock, .usFund, .etf: return .usd
        }
    }

    var isZakatable: Bool {
        return self != .cash // Cash is calculated separately
    }
}

// MARK: - Currency
enum Currency: String, Codable, CaseIterable {
    case sar = "SAR"
    case usd = "USD"

    var symbol: String {
        switch self {
        case .sar: return "ر.س"
        case .usd: return "$"
        }
    }

    var displayName: String {
        switch self {
        case .sar: return "ريال سعودي"
        case .usd: return "دولار أمريكي"
        }
    }
}

// MARK: - Asset Model
struct Asset: Identifiable, Codable {
    let id: UUID
    var symbol: String
    var name: String
    var nameAr: String?
    var type: AssetType
    var currency: Currency
    var currentPrice: Decimal
    var lastPriceUpdate: Date?
    var sector: String?
    var market: String?  // TASI, NYSE, NASDAQ, etc.
    var isActive: Bool

    var holdings: [Holding] = []

    var totalShares: Decimal {
        holdings.filter { $0.portfolioId == nil || true }.reduce(0) { $0 + $1.sharesRemaining }
    }

    var averageCostBasis: Decimal {
        let totalCost = holdings.reduce(Decimal(0)) { $0 + ($1.averageCost * $1.sharesRemaining) }
        let totalShares = holdings.reduce(Decimal(0)) { $0 + $1.sharesRemaining }
        guard totalShares > 0 else { return 0 }
        return totalCost / totalShares
    }

    var currentValueSAR: Decimal {
        // Will be calculated using exchange rate when USD
        return currentPrice * totalShares
    }

    var unrealizedPnL: Decimal {
        return (currentPrice - averageCostBasis) * totalShares
    }

    var unrealizedPnLPercentage: Decimal {
        guard averageCostBasis > 0 else { return 0 }
        return ((currentPrice - averageCostBasis) / averageCostBasis) * 100
    }

    init(id: UUID = UUID(), symbol: String, name: String, nameAr: String? = nil,
         type: AssetType, currency: Currency, currentPrice: Decimal = 0,
         sector: String? = nil, market: String? = nil) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.nameAr = nameAr
        self.type = type
        self.currency = currency
        self.currentPrice = currentPrice
        self.sector = sector
        self.market = market
        self.isActive = true
    }
}

// MARK: - Holding Model (tracks cost basis per purchase lot)
struct Holding: Identifiable, Codable {
    let id: UUID
    var assetId: UUID
    var portfolioId: UUID?    // nil = personal portfolio
    var fundId: UUID?         // if in a fund
    var purchaseDate: Date
    var sharesOriginal: Decimal
    var sharesRemaining: Decimal
    var purchasePrice: Decimal    // price per share at purchase
    var purchaseCurrency: Currency
    var exchangeRateAtPurchase: Decimal?  // USD/SAR at time of purchase
    var fees: Decimal
    var taxes: Decimal
    var hijriDate: HijriDate?   // for zakat calculation

    var averageCost: Decimal {
        let totalCost = (purchasePrice * sharesRemaining) + fees + taxes
        guard sharesRemaining > 0 else { return 0 }
        return totalCost / sharesRemaining
    }

    var haolCompleted: Bool {
        // Check if one lunar year (354.37 days) has passed
        let haolDays = 354.37
        return Date().timeIntervalSince(purchaseDate) >= haolDays * 24 * 3600
    }

    var daysUntilHaol: Int {
        let haolDays = 354.37
        let elapsed = Date().timeIntervalSince(purchaseDate) / (24 * 3600)
        let remaining = haolDays - elapsed
        return max(0, Int(remaining))
    }

    init(id: UUID = UUID(), assetId: UUID, portfolioId: UUID? = nil,
         purchaseDate: Date, sharesOriginal: Decimal, purchasePrice: Decimal,
         purchaseCurrency: Currency, fees: Decimal = 0, taxes: Decimal = 0) {
        self.id = id
        self.assetId = assetId
        self.portfolioId = portfolioId
        self.purchaseDate = purchaseDate
        self.sharesOriginal = sharesOriginal
        self.sharesRemaining = sharesOriginal
        self.purchasePrice = purchasePrice
        self.purchaseCurrency = purchaseCurrency
        self.fees = fees
        self.taxes = taxes
    }
}

// MARK: - Hijri Date
struct HijriDate: Codable {
    var year: Int
    var month: Int
    var day: Int

    var description: String {
        return "\(day)/\(month)/\(year) هـ"
    }
}
