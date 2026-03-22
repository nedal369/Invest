import Foundation
import Combine

// MARK: - Price Service
class PriceService: ObservableObject {
    static let shared = PriceService()

    @Published var isUpdating = false
    @Published var lastUpdateTime: Date?
    @Published var updateError: String?

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let db = DatabaseManager.shared

    // Free APIs
    private let yahooBaseURL = "https://query1.finance.yahoo.com/v8/finance/chart/"
    private let goldAPIURL = "https://api.gold-api.com/price/XAU"  // free gold API
    private let exchangeRateURL = "https://api.exchangerate-api.com/v4/latest/USD"

    private init() {}

    // MARK: - Auto Update
    func startAutoUpdate() {
        // Update every 24 hours
        updateTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.updateAllPrices()
        }
        // Update on startup if data is stale
        updatePricesIfNeeded()
    }

    func updatePricesIfNeeded() {
        let lastUpdate = db.getSetting("last_price_update")
            .flatMap { Double($0) }
            .map { Date(timeIntervalSince1970: $0) }

        if let last = lastUpdate {
            let hoursSince = Date().timeIntervalSince(last) / 3600
            if hoursSince < 4 { return } // Don't update if less than 4 hours
        }
        updateAllPrices()
    }

    func updateAllPrices() {
        guard !isUpdating else { return }
        isUpdating = true
        updateError = nil

        Task {
            do {
                // Get all unique symbols from holdings and transactions
                let symbols = getTrackedSymbols()

                // Fetch prices in parallel
                async let sarPrices = fetchSaudiPrices(symbols: symbols.saudi)
                async let usPrices = fetchUSPrices(symbols: symbols.us)
                async let goldPrice = fetchGoldPrice()
                async let usdSarRate = fetchUSDSARRate()

                let (saudiResults, usResults, gold, rate) = try await (sarPrices, usPrices, goldPrice, usdSarRate)

                // Cache all results
                for price in saudiResults + usResults {
                    cachePrice(price)
                }
                if let gold = gold { cachePrice(gold) }
                if let rate = rate { cacheExchangeRate(rate) }

                await MainActor.run {
                    self.lastUpdateTime = Date()
                    self.isUpdating = false
                    self.db.setSetting("last_price_update", value: String(Date().timeIntervalSince1970))
                }
            } catch {
                await MainActor.run {
                    self.updateError = "فشل تحديث الأسعار: \(error.localizedDescription)"
                    self.isUpdating = false
                }
            }
        }
    }

    // MARK: - Fetch Prices
    private func fetchSaudiPrices(symbols: [String]) async throws -> [PriceData] {
        guard !symbols.isEmpty else { return [] }
        var results: [PriceData] = []

        // Yahoo Finance supports Saudi stocks with .SR suffix
        for symbol in symbols {
            let yahooSymbol = symbol.hasSuffix(".SR") ? symbol : "\(symbol).SR"
            if let price = try? await fetchYahooPrice(symbol: yahooSymbol, originalSymbol: symbol) {
                results.append(price)
            }
        }
        return results
    }

    private func fetchUSPrices(symbols: [String]) async throws -> [PriceData] {
        guard !symbols.isEmpty else { return [] }
        var results: [PriceData] = []

        for symbol in symbols {
            if let price = try? await fetchYahooPrice(symbol: symbol, originalSymbol: symbol) {
                results.append(price)
            }
        }
        return results
    }

    private func fetchYahooPrice(symbol: String, originalSymbol: String) async throws -> PriceData? {
        let urlString = "\(yahooBaseURL)\(symbol)?interval=1d&range=1d"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let resultArray = chart["result"] as? [[String: Any]],
              let result = resultArray.first,
              let meta = result["meta"] as? [String: Any] else {
            return nil
        }

        let currentPrice = Decimal(meta["regularMarketPrice"] as? Double ?? 0)
        let previousClose = Decimal(meta["previousClose"] as? Double ?? 0)
        let currency = (meta["currency"] as? String) == "USD" ? Currency.usd : Currency.sar

        let dailyChange = currentPrice - previousClose
        let dailyChangePct = previousClose > 0 ? (dailyChange / previousClose * 100) : 0

        return PriceData(
            symbol: originalSymbol,
            price: currentPrice,
            currency: currency,
            timestamp: Date(),
            source: "Yahoo Finance",
            previousClose: previousClose,
            dailyChange: dailyChange,
            dailyChangePct: dailyChangePct
        )
    }

    private func fetchGoldPrice() async throws -> PriceData? {
        // Gold price per troy ounce USD, convert to SAR per gram 24K
        // Using a free API endpoint
        guard let url = URL(string: "https://api.metals.live/v1/spot/gold") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let goldData = json.first,
           let pricePerOunce = goldData["price"] as? Double {
            // Convert USD/troy oz to SAR/gram
            // 1 troy oz = 31.1035 grams
            let pricePerGramUSD = pricePerOunce / 31.1035

            // Get current USD/SAR rate
            let usdSarRate = getCachedExchangeRate(from: "USD", to: "SAR") ?? 3.75

            let pricePerGramSAR = Decimal(pricePerGramUSD) * Decimal(usdSarRate)

            return PriceData(
                symbol: "GOLD_24K",
                price: pricePerGramSAR,
                currency: .sar,
                timestamp: Date(),
                source: "metals.live",
                previousClose: nil,
                dailyChange: nil,
                dailyChangePct: nil
            )
        }
        return nil
    }

    private func fetchUSDSARRate() async throws -> ExchangeRateData? {
        guard let url = URL(string: "https://api.exchangerate-api.com/v4/latest/USD") else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let rates = json["rates"] as? [String: Any],
           let sarRate = rates["SAR"] as? Double {
            return ExchangeRateData(
                from: "USD",
                to: "SAR",
                rate: Decimal(sarRate),
                timestamp: Date(),
                source: "exchangerate-api.com"
            )
        }

        // Fallback to fixed rate if API fails
        return ExchangeRateData(from: "USD", to: "SAR", rate: 3.75, timestamp: Date(), source: "fixed")
    }

    // MARK: - Cache Management
    private func cachePrice(_ price: PriceData) {
        let now = ISO8601DateFormatter().string(from: price.timestamp)
        let prev = price.previousClose.map { String(describing: $0) } ?? "NULL"
        let change = price.dailyChange.map { String(describing: $0) } ?? "NULL"
        let changePct = price.dailyChangePct.map { String(describing: $0) } ?? "NULL"

        db.execute("""
            INSERT OR REPLACE INTO price_cache
            (symbol, price, currency, timestamp, source, previous_close, daily_change, daily_change_pct)
            VALUES ('\(price.symbol)', \(price.price), '\(price.currency.rawValue)',
            '\(now)', '\(price.source)', \(prev), \(change), \(changePct));
        """)
    }

    private func cacheExchangeRate(_ rate: ExchangeRateData) {
        let now = ISO8601DateFormatter().string(from: rate.timestamp)
        let id = "\(rate.from)_\(rate.to)"
        db.execute("""
            INSERT OR REPLACE INTO exchange_rates
            (id, from_currency, to_currency, rate, timestamp, source)
            VALUES ('\(id)', '\(rate.from)', '\(rate.to)', \(rate.rate), '\(now)', '\(rate.source)');
        """)
    }

    // MARK: - Price Getters
    func getPrice(symbol: String) -> PriceData? {
        let rows = db.query("SELECT * FROM price_cache WHERE symbol = ?", params: [symbol])
        guard let row = rows.first else { return nil }

        return PriceData(
            symbol: row["symbol"] as? String ?? symbol,
            price: Decimal(row["price"] as? Double ?? 0),
            currency: Currency(rawValue: row["currency"] as? String ?? "SAR") ?? .sar,
            timestamp: ISO8601DateFormatter().date(from: row["timestamp"] as? String ?? "") ?? Date(),
            source: row["source"] as? String ?? "",
            previousClose: (row["previous_close"] as? Double).map { Decimal($0) },
            dailyChange: (row["daily_change"] as? Double).map { Decimal($0) },
            dailyChangePct: (row["daily_change_pct"] as? Double).map { Decimal($0) }
        )
    }

    func getCachedExchangeRate(from: String, to: String) -> Decimal? {
        let id = "\(from)_\(to)"
        let rows = db.query("SELECT rate FROM exchange_rates WHERE id = ?", params: [id])
        return (rows.first?["rate"] as? Double).map { Decimal($0) }
    }

    func getGoldPrice24K() -> Decimal {
        return getPrice(symbol: "GOLD_24K")?.price ?? 280 // fallback SAR per gram
    }

    func getUSDSARRate() -> Decimal {
        return getCachedExchangeRate(from: "USD", to: "SAR") ?? 3.75
    }

    // MARK: - Symbol Tracking
    private func getTrackedSymbols() -> (saudi: [String], us: [String]) {
        let rows = db.query("""
            SELECT DISTINCT a.symbol, a.currency
            FROM assets a
            INNER JOIN holdings h ON h.asset_id = a.id
            WHERE a.type != 'CASH' AND a.type != 'GOLD'
            AND h.shares_remaining > 0
        """)

        var saudi: [String] = []
        var us: [String] = []

        for row in rows {
            guard let symbol = row["symbol"] as? String,
                  let currency = row["currency"] as? String else { continue }
            if currency == "SAR" {
                saudi.append(symbol)
            } else {
                us.append(symbol)
            }
        }
        return (saudi, us)
    }
}

// MARK: - Price Data Structs
struct PriceData {
    var symbol: String
    var price: Decimal
    var currency: Currency
    var timestamp: Date
    var source: String
    var previousClose: Decimal?
    var dailyChange: Decimal?
    var dailyChangePct: Decimal?
}

struct ExchangeRateData {
    var from: String
    var to: String
    var rate: Decimal
    var timestamp: Date
    var source: String
}
