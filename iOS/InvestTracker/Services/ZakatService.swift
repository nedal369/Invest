import Foundation

// MARK: - Zakat Service
class ZakatService {
    static let shared = ZakatService()

    private let db = DatabaseManager.shared
    private let priceService = PriceService.shared

    private init() {}

    // MARK: - Calculate Zakat for Personal Portfolio
    func calculatePersonalZakat(portfolioId: UUID? = nil) -> ZakatCalculation {
        let goldPrice = priceService.getGoldPrice24K()
        let usdSarRate = priceService.getUSDSARRate()

        // 1. Get holdings that completed haol (lunar year)
        let holdingsValue = getZakatableHoldingsValue(portfolioId: portfolioId, usdSarRate: usdSarRate)

        // 2. Get cash that completed haol
        let cashValue = getZakatableCash(portfolioId: portfolioId)

        // 3. Get accumulated dividends
        let dividendsValue = getZakatableDividends(portfolioId: portfolioId)

        var calculation = ZakatCalculation(
            calculationDate: Date(),
            goldPrice: goldPrice,
            holdingsValue: holdingsValue,
            cashValue: cashValue,
            dividendsValue: dividendsValue
        )

        // Set hijri date
        let hijri = HijriCalendar.current.dateComponents(from: Date())
        calculation.hijriYear = hijri.year
        calculation.hijriMonth = hijri.month
        calculation.portfolioId = portfolioId

        saveCalculation(calculation)
        return calculation
    }

    // MARK: - Calculate Zakat for Fund
    func calculateFundZakat(fundId: UUID) -> ZakatCalculation {
        let goldPrice = priceService.getGoldPrice24K()
        let usdSarRate = priceService.getUSDSARRate()

        let holdingsValue = getZakatableHoldingsValue(fundId: fundId, usdSarRate: usdSarRate)
        let cashValue = getFundCashBalance(fundId: fundId)
        let dividendsValue = getZakatableDividends(fundId: fundId)

        var calculation = ZakatCalculation(
            calculationDate: Date(),
            goldPrice: goldPrice,
            holdingsValue: holdingsValue,
            cashValue: cashValue,
            dividendsValue: dividendsValue
        )

        calculation.fundId = fundId

        // Calculate member breakdown
        let members = getFundMembers(fundId: fundId)
        let totalUnits = members.reduce(0) { $0 + $1.units }
        calculation.memberBreakdown = members.map { member in
            MemberZakatShare(
                memberId: member.id,
                memberName: member.name,
                units: member.units,
                totalUnits: totalUnits,
                totalZakatBase: calculation.totalZakatBase
            )
        }

        saveCalculation(calculation)
        return calculation
    }

    // MARK: - Holdings Value (haol completed)
    private func getZakatableHoldingsValue(portfolioId: UUID? = nil, fundId: UUID? = nil, usdSarRate: Decimal) -> Decimal {
        let haolDays = 354.37
        let cutoffDate = Date(timeIntervalSinceNow: -haolDays * 86400)
        let cutoffStr = ISO8601DateFormatter().string(from: cutoffDate)

        var whereClause = "h.purchase_date <= '\(cutoffStr)' AND h.shares_remaining > 0"
        if let pid = portfolioId {
            whereClause += " AND h.portfolio_id = '\(pid.uuidString)'"
        } else if let fid = fundId {
            whereClause += " AND h.fund_id = '\(fid.uuidString)'"
        }

        let rows = db.query("""
            SELECT h.shares_remaining, h.purchase_currency,
                   COALESCE(p.price, h.purchase_price) as current_price,
                   a.symbol
            FROM holdings h
            INNER JOIN assets a ON a.id = h.asset_id
            LEFT JOIN price_cache p ON p.symbol = a.symbol
            WHERE \(whereClause)
        """)

        var totalSAR = Decimal(0)
        for row in rows {
            let shares = Decimal(row["shares_remaining"] as? Double ?? 0)
            let price = Decimal(row["current_price"] as? Double ?? 0)
            let currency = row["purchase_currency"] as? String ?? "SAR"
            let value = shares * price
            if currency == "USD" {
                totalSAR += value * usdSarRate
            } else {
                totalSAR += value
            }
        }
        return totalSAR
    }

    // MARK: - Cash Balance (haol completed)
    private func getZakatableCash(portfolioId: UUID? = nil) -> Decimal {
        // Cash deposited more than one haol ago
        let haolDays = 354.37
        let cutoffDate = Date(timeIntervalSinceNow: -haolDays * 86400)
        let cutoffStr = ISO8601DateFormatter().string(from: cutoffDate)

        var whereClause = "t.type = 'DEPOSIT' AND t.date <= '\(cutoffStr)'"
        if let pid = portfolioId {
            whereClause += " AND t.portfolio_id = '\(pid.uuidString)'"
        }

        // Sum deposits - withdrawals before cutoff
        let depositRows = db.query("""
            SELECT COALESCE(SUM(amount_sar), 0) as total
            FROM transactions
            WHERE type = 'DEPOSIT' AND date <= '\(cutoffStr)'
        """)
        let withdrawRows = db.query("""
            SELECT COALESCE(SUM(amount_sar), 0) as total
            FROM transactions
            WHERE type = 'WITHDRAW' AND date <= '\(cutoffStr)'
        """)

        let deposits = Decimal(depositRows.first?["total"] as? Double ?? 0)
        let withdrawals = Decimal(withdrawRows.first?["total"] as? Double ?? 0)

        return max(0, deposits - withdrawals)
    }

    private func getFundCashBalance(fundId: UUID) -> Decimal {
        let rows = db.query("SELECT cash_balance FROM funds WHERE id = ?",
                            params: [fundId.uuidString])
        return Decimal(rows.first?["cash_balance"] as? Double ?? 0)
    }

    // MARK: - Dividends
    private func getZakatableDividends(portfolioId: UUID? = nil, fundId: UUID? = nil) -> Decimal {
        var whereClause = "is_zakat_included = 0"
        if let pid = portfolioId {
            whereClause += " AND portfolio_id = '\(pid.uuidString)'"
        } else if let fid = fundId {
            whereClause += " AND fund_id = '\(fid.uuidString)'"
        }

        let rows = db.query("""
            SELECT COALESCE(SUM(amount_sar), 0) as total
            FROM dividends WHERE \(whereClause)
        """)
        return Decimal(rows.first?["total"] as? Double ?? 0)
    }

    // MARK: - Record Payment
    func recordZakatPayment(calculationId: UUID, amount: Decimal, date: Date = Date(), notes: String? = nil) {
        let record = ZakatPaymentRecord(
            zakatCalculationId: calculationId,
            paymentDate: date,
            amountPaid: amount,
            notes: notes
        )

        let dateStr = ISO8601DateFormatter().string(from: date)
        let calcIdStr = calculationId.uuidString
        let idStr = record.id.uuidString
        let notesVal = notes ?? ""

        db.execute("""
            INSERT INTO zakat_calculations
            SET status = 'PAID', paid_at = '\(dateStr)', paid_amount = \(amount)
            WHERE id = '\(calcIdStr)';
        """)

        // Mark dividends as included
        db.execute("UPDATE dividends SET is_zakat_included = 1;")
    }

    // MARK: - History
    func getZakatHistory() -> [ZakatHistoryItem] {
        let rows = db.query("""
            SELECT * FROM zakat_calculations
            ORDER BY calculation_date DESC
        """)

        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let dateStr = row["calculation_date"] as? String,
                  let date = ISO8601DateFormatter().date(from: dateStr) else { return nil }

            let hijriYear = row["hijri_year"] as? Int ?? 0
            let base = Decimal(row["total_zakat_base"] as? Double ?? 0)
            let due = Decimal(row["zakat_due"] as? Double ?? 0)
            let paid = Decimal(row["paid_amount"] as? Double ?? 0)
            let statusStr = row["status"] as? String ?? "CALCULATED"
            let status = ZakatCalculation.ZakatStatus(rawValue: statusStr) ?? .calculated

            let fundId = row["fund_id"] as? String
            let type = fundId != nil ? "صندوق" : "شخصية"

            return ZakatHistoryItem(
                year: "\(hijriYear) هـ",
                calculationDate: date,
                zakatBase: base,
                zakatDue: due,
                paidAmount: paid,
                status: status,
                type: type
            )
        }
    }

    // MARK: - Save Calculation
    private func saveCalculation(_ calc: ZakatCalculation) {
        let dateStr = ISO8601DateFormatter().string(from: calc.calculationDate)
        let portfolioId = calc.portfolioId?.uuidString ?? "NULL"
        let fundId = calc.fundId?.uuidString ?? "NULL"

        db.execute("""
            INSERT OR REPLACE INTO zakat_calculations
            (id, portfolio_id, fund_id, calculation_date, hijri_year, hijri_month,
             gold_price_24k, nisab_amount_sar, holdings_value, cash_value, dividends_value,
             total_zakat_base, is_nisab_met, zakat_due, status)
            VALUES (
                '\(calc.id.uuidString)',
                \(portfolioId == "NULL" ? "NULL" : "'\(portfolioId)'"),
                \(fundId == "NULL" ? "NULL" : "'\(fundId)'"),
                '\(dateStr)', \(calc.hijriYear), \(calc.hijriMonth),
                \(calc.goldPricePer24KGram), \(calc.nisabAmountSAR),
                \(calc.holdingsValue), \(calc.cashValue), \(calc.dividendsValue),
                \(calc.totalZakatBase), \(calc.isNisabMet ? 1 : 0),
                \(calc.zakatDue), '\(calc.status.rawValue)'
            );
        """)

        // Save member breakdown if fund
        if let breakdown = calc.memberBreakdown {
            for share in breakdown {
                db.execute("""
                    INSERT OR REPLACE INTO zakat_member_shares
                    (id, zakat_calculation_id, member_id, member_name, units, total_units,
                     zakat_base, zakat_due, is_paid)
                    VALUES ('\(share.id.uuidString)', '\(calc.id.uuidString)',
                    '\(share.memberId.uuidString)', '\(share.memberName)',
                    \(share.units), \(share.totalUnits),
                    \(share.zakatBase), \(share.zakatDue), 0);
                """)
            }
        }
    }

    // MARK: - Fund Members Helper
    private func getFundMembers(fundId: UUID) -> [FundMember] {
        let rows = db.query("""
            SELECT * FROM fund_members WHERE fund_id = ? AND is_active = 1
        """, params: [fundId.uuidString])

        return rows.compactMap { row in
            guard let idStr = row["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let name = row["name"] as? String,
                  let units = row["units"] as? Int else { return nil }

            var member = FundMember(
                id: id,
                fundId: fundId,
                name: name,
                units: units
            )
            member.phone = row["phone"] as? String
            return member
        }
    }
}

// MARK: - Simple Hijri Calendar
struct HijriCalendar {
    static let current = HijriCalendar()

    struct HijriComponents {
        var year: Int
        var month: Int
        var day: Int
    }

    func dateComponents(from date: Date) -> HijriComponents {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return HijriComponents(
            year: comps.year ?? 0,
            month: comps.month ?? 0,
            day: comps.day ?? 0
        )
    }
}
