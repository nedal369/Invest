import Foundation

// MARK: - Personal Portfolio
struct Portfolio: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String?
    var createdAt: Date
    var currency: Currency

    // Computed from transactions & holdings
    var totalDeposits: Decimal
    var totalWithdrawals: Decimal
    var realizedPnL: Decimal
    var cashBalance: Decimal

    init(id: UUID = UUID(), name: String = "محفظتي الشخصية", currency: Currency = .sar) {
        self.id = id
        self.name = name
        self.currency = currency
        self.createdAt = Date()
        self.totalDeposits = 0
        self.totalWithdrawals = 0
        self.realizedPnL = 0
        self.cashBalance = 0
    }
}

// MARK: - Portfolio Summary (computed)
struct PortfolioSummary {
    var totalCurrentValue: Decimal     // current market value SAR
    var totalDeposits: Decimal         // total deposited SAR
    var totalWithdrawals: Decimal      // total withdrawn SAR
    var realizedPnL: Decimal           // realized gains/losses
    var unrealizedPnL: Decimal         // unrealized gains/losses
    var cashBalance: Decimal           // cash SAR
    var totalDividends: Decimal        // total dividends received
    var totalFees: Decimal             // total fees paid

    var totalInvested: Decimal {       // net invested capital
        return totalDeposits - totalWithdrawals
    }

    var totalReturn: Decimal {
        return realizedPnL + unrealizedPnL + totalDividends
    }

    var returnPercentage: Decimal {
        guard totalDeposits > 0 else { return 0 }
        return (totalReturn / totalDeposits) * 100
    }

    var netWorth: Decimal {
        return totalCurrentValue + cashBalance
    }
}

// MARK: - Price Alert
struct PriceAlert: Identifiable, Codable {
    let id: UUID
    var assetId: UUID
    var assetSymbol: String
    var alertType: AlertType
    var threshold: Decimal       // percentage or absolute price
    var isActive: Bool
    var triggeredAt: Date?
    var createdAt: Date

    enum AlertType: String, Codable {
        case priceAbove = "PRICE_ABOVE"
        case priceBelow = "PRICE_BELOW"
        case percentageUp = "PCT_UP"       // +5% daily
        case percentageDown = "PCT_DOWN"   // -5% daily

        var displayName: String {
            switch self {
            case .priceAbove: return "السعر أعلى من"
            case .priceBelow: return "السعر أقل من"
            case .percentageUp: return "ارتفاع يومي %"
            case .percentageDown: return "انخفاض يومي %"
            }
        }
    }

    init(id: UUID = UUID(), assetId: UUID, assetSymbol: String,
         alertType: AlertType, threshold: Decimal) {
        self.id = id
        self.assetId = assetId
        self.assetSymbol = assetSymbol
        self.alertType = alertType
        self.threshold = threshold
        self.isActive = true
        self.createdAt = Date()
    }
}

// MARK: - Price Cache
struct PriceCache: Codable {
    var symbol: String
    var price: Decimal
    var currency: Currency
    var timestamp: Date
    var source: String
    var previousClose: Decimal?
    var dailyChange: Decimal?
    var dailyChangePercent: Decimal?

    var isStale: Bool {
        // Consider stale if older than 24 hours
        return Date().timeIntervalSince(timestamp) > 86400
    }
}

// MARK: - Exchange Rate Cache
struct ExchangeRateCache: Codable {
    var fromCurrency: String
    var toCurrency: String
    var rate: Decimal
    var timestamp: Date
    var source: String

    var isStale: Bool {
        return Date().timeIntervalSince(timestamp) > 3600 // 1 hour
    }
}
