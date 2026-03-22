import Foundation
import SQLite3

// MARK: - Database Manager
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbName = "invest_tracker.sqlite"

    private var dbPath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(dbName).path
    }

    private init() {}

    // MARK: - Initialize
    func initialize() {
        openDatabase()
        createTables()
        runMigrations()
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error: Could not open database at \(dbPath)")
        }

        // Enable WAL mode for better performance
        execute("PRAGMA journal_mode=WAL;")
        execute("PRAGMA foreign_keys=ON;")

        // Encrypt database (using SQLCipher if available)
        // sqlite3_key(db, "your_encryption_key", 32)
    }

    private func createTables() {
        // Assets table
        execute("""
            CREATE TABLE IF NOT EXISTS assets (
                id TEXT PRIMARY KEY,
                symbol TEXT NOT NULL,
                name TEXT NOT NULL,
                name_ar TEXT,
                type TEXT NOT NULL,
                currency TEXT NOT NULL,
                current_price REAL DEFAULT 0,
                last_price_update TEXT,
                sector TEXT,
                market TEXT,
                is_active INTEGER DEFAULT 1,
                created_at TEXT NOT NULL
            );
        """)

        // Holdings table (cost basis lots)
        execute("""
            CREATE TABLE IF NOT EXISTS holdings (
                id TEXT PRIMARY KEY,
                asset_id TEXT NOT NULL,
                portfolio_id TEXT,
                fund_id TEXT,
                purchase_date TEXT NOT NULL,
                shares_original REAL NOT NULL,
                shares_remaining REAL NOT NULL,
                purchase_price REAL NOT NULL,
                purchase_currency TEXT NOT NULL,
                exchange_rate_at_purchase REAL,
                fees REAL DEFAULT 0,
                taxes REAL DEFAULT 0,
                hijri_year INTEGER,
                hijri_month INTEGER,
                hijri_day INTEGER,
                FOREIGN KEY (asset_id) REFERENCES assets(id)
            );
        """)

        // Transactions table
        execute("""
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                date TEXT NOT NULL,
                asset_id TEXT,
                asset_symbol TEXT,
                portfolio_id TEXT,
                fund_id TEXT,
                quantity REAL DEFAULT 0,
                price REAL DEFAULT 0,
                amount REAL DEFAULT 0,
                currency TEXT NOT NULL,
                exchange_rate REAL,
                amount_sar REAL DEFAULT 0,
                fees REAL DEFAULT 0,
                taxes REAL DEFAULT 0,
                notes TEXT,
                status TEXT DEFAULT 'CONFIRMED',
                source_image_path TEXT,
                ocr_raw_data TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
        """)

        // Price cache table
        execute("""
            CREATE TABLE IF NOT EXISTS price_cache (
                symbol TEXT PRIMARY KEY,
                price REAL NOT NULL,
                currency TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                source TEXT,
                previous_close REAL,
                daily_change REAL,
                daily_change_pct REAL
            );
        """)

        // Exchange rates table
        execute("""
            CREATE TABLE IF NOT EXISTS exchange_rates (
                id TEXT PRIMARY KEY,
                from_currency TEXT NOT NULL,
                to_currency TEXT NOT NULL,
                rate REAL NOT NULL,
                timestamp TEXT NOT NULL,
                source TEXT
            );
        """)

        // Funds table
        execute("""
            CREATE TABLE IF NOT EXISTS funds (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                currency TEXT DEFAULT 'SAR',
                unit_price REAL NOT NULL,
                payment_day_of_month INTEGER DEFAULT 1,
                start_date TEXT NOT NULL,
                is_active INTEGER DEFAULT 1,
                cash_balance REAL DEFAULT 0,
                created_at TEXT NOT NULL
            );
        """)

        // Fund members table
        execute("""
            CREATE TABLE IF NOT EXISTS fund_members (
                id TEXT PRIMARY KEY,
                fund_id TEXT NOT NULL,
                name TEXT NOT NULL,
                phone TEXT,
                email TEXT,
                units INTEGER DEFAULT 1,
                join_date TEXT NOT NULL,
                is_active INTEGER DEFAULT 1,
                web_access_code TEXT,
                web_access_enabled INTEGER DEFAULT 0,
                FOREIGN KEY (fund_id) REFERENCES funds(id)
            );
        """)

        // Fund payments table
        execute("""
            CREATE TABLE IF NOT EXISTS fund_payments (
                id TEXT PRIMARY KEY,
                fund_id TEXT NOT NULL,
                member_id TEXT NOT NULL,
                member_name TEXT NOT NULL,
                due_date TEXT NOT NULL,
                due_amount REAL NOT NULL,
                paid_amount REAL DEFAULT 0,
                payment_date TEXT,
                status TEXT DEFAULT 'PENDING',
                notes TEXT,
                receipt_image_path TEXT,
                recorded_by TEXT,
                FOREIGN KEY (fund_id) REFERENCES funds(id),
                FOREIGN KEY (member_id) REFERENCES fund_members(id)
            );
        """)

        // Zakat calculations table
        execute("""
            CREATE TABLE IF NOT EXISTS zakat_calculations (
                id TEXT PRIMARY KEY,
                portfolio_id TEXT,
                fund_id TEXT,
                calculation_date TEXT NOT NULL,
                hijri_year INTEGER,
                hijri_month INTEGER,
                gold_price_24k REAL NOT NULL,
                nisab_amount_sar REAL NOT NULL,
                holdings_value REAL DEFAULT 0,
                cash_value REAL DEFAULT 0,
                dividends_value REAL DEFAULT 0,
                total_zakat_base REAL DEFAULT 0,
                is_nisab_met INTEGER DEFAULT 0,
                zakat_due REAL DEFAULT 0,
                status TEXT DEFAULT 'CALCULATED',
                paid_at TEXT,
                paid_amount REAL,
                notes TEXT
            );
        """)

        // Zakat member shares (for funds)
        execute("""
            CREATE TABLE IF NOT EXISTS zakat_member_shares (
                id TEXT PRIMARY KEY,
                zakat_calculation_id TEXT NOT NULL,
                member_id TEXT NOT NULL,
                member_name TEXT NOT NULL,
                units INTEGER NOT NULL,
                total_units INTEGER NOT NULL,
                zakat_base REAL DEFAULT 0,
                zakat_due REAL DEFAULT 0,
                is_paid INTEGER DEFAULT 0,
                FOREIGN KEY (zakat_calculation_id) REFERENCES zakat_calculations(id)
            );
        """)

        // Loans table
        execute("""
            CREATE TABLE IF NOT EXISTS loans (
                id TEXT PRIMARY KEY,
                fund_id TEXT NOT NULL,
                member_id TEXT NOT NULL,
                member_name TEXT NOT NULL,
                principal_amount REAL NOT NULL,
                monthly_installment REAL NOT NULL,
                disbursement_date TEXT NOT NULL,
                first_payment_date TEXT NOT NULL,
                last_payment_date TEXT NOT NULL,
                total_months INTEGER DEFAULT 12,
                status TEXT DEFAULT 'ACTIVE',
                approved_by TEXT,
                notes TEXT,
                FOREIGN KEY (fund_id) REFERENCES funds(id),
                FOREIGN KEY (member_id) REFERENCES fund_members(id)
            );
        """)

        // Loan installments table
        execute("""
            CREATE TABLE IF NOT EXISTS loan_installments (
                id TEXT PRIMARY KEY,
                loan_id TEXT NOT NULL,
                installment_number INTEGER NOT NULL,
                due_date TEXT NOT NULL,
                due_amount REAL NOT NULL,
                paid_amount REAL DEFAULT 0,
                paid_date TEXT,
                status TEXT DEFAULT 'UPCOMING',
                notes TEXT,
                FOREIGN KEY (loan_id) REFERENCES loans(id)
            );
        """)

        // Dividends table
        execute("""
            CREATE TABLE IF NOT EXISTS dividends (
                id TEXT PRIMARY KEY,
                asset_id TEXT NOT NULL,
                asset_symbol TEXT NOT NULL,
                asset_name TEXT NOT NULL,
                transaction_id TEXT NOT NULL,
                date TEXT NOT NULL,
                amount_per_share REAL DEFAULT 0,
                total_shares REAL DEFAULT 0,
                total_amount REAL DEFAULT 0,
                currency TEXT NOT NULL,
                amount_sar REAL DEFAULT 0,
                portfolio_id TEXT,
                fund_id TEXT,
                is_zakat_included INTEGER DEFAULT 0
            );
        """)

        // Alerts table
        execute("""
            CREATE TABLE IF NOT EXISTS alerts (
                id TEXT PRIMARY KEY,
                asset_id TEXT NOT NULL,
                asset_symbol TEXT NOT NULL,
                alert_type TEXT NOT NULL,
                threshold REAL NOT NULL,
                is_active INTEGER DEFAULT 1,
                triggered_at TEXT,
                created_at TEXT NOT NULL
            );
        """)

        // App settings table
        execute("""
            CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
        """)
    }

    private func runMigrations() {
        // Check schema version and run migrations as needed
        let currentVersion = getSetting("schema_version").flatMap { Int($0) } ?? 0
        if currentVersion < 1 {
            // Initial schema - already created above
            setSetting("schema_version", value: "1")
        }
    }

    // MARK: - Generic Execute
    @discardableResult
    func execute(_ sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg {
                print("SQL Error: \(String(cString: err))\nSQL: \(sql)")
                sqlite3_free(errMsg)
            }
            return false
        }
        return true
    }

    func query(_ sql: String, params: [Any?] = []) -> [[String: Any]] {
        var stmt: OpaquePointer?
        var results: [[String: Any]] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return results
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            let idx = Int32(index + 1)
            if let param = param {
                if let intVal = param as? Int {
                    sqlite3_bind_int64(stmt, idx, Int64(intVal))
                } else if let doubleVal = param as? Double {
                    sqlite3_bind_double(stmt, idx, doubleVal)
                } else if let strVal = param as? String {
                    sqlite3_bind_text(stmt, idx, strVal, -1, SQLITE_TRANSIENT)
                } else if let decVal = param as? Decimal {
                    sqlite3_bind_double(stmt, idx, NSDecimalNumber(decimal: decVal).doubleValue)
                }
            } else {
                sqlite3_bind_null(stmt, idx)
            }
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            let columns = sqlite3_column_count(stmt)
            for i in 0..<columns {
                let colName = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER:
                    row[colName] = Int(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT:
                    row[colName] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT:
                    row[colName] = String(cString: sqlite3_column_text(stmt, i))
                case SQLITE_NULL:
                    row[colName] = NSNull()
                default:
                    break
                }
            }
            results.append(row)
        }
        return results
    }

    // MARK: - Settings helpers
    func getSetting(_ key: String) -> String? {
        let rows = query("SELECT value FROM app_settings WHERE key = ?", params: [key])
        return rows.first?["value"] as? String
    }

    func setSetting(_ key: String, value: String) {
        let now = ISO8601DateFormatter().string(from: Date())
        execute("INSERT OR REPLACE INTO app_settings (key, value, updated_at) VALUES ('\(key)', '\(value)', '\(now)');")
    }
}

// MARK: - SQLite transient helper
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
