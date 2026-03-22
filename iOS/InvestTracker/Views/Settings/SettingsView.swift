import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var priceService: PriceService
    @State private var useBiometrics = true
    @State private var encryptDB = true
    @State private var autoUpdatePrices = true
    @State private var zakatReminderEnabled = true
    @State private var fundPaymentReminderEnabled = true
    @State private var showPriceHistory = false
    @State private var showAbout = false
    @State private var backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? ""

    var body: some View {
        NavigationView {
            List {
                // Security
                Section {
                    Toggle("قفل بالبصمة / Face ID", isOn: $useBiometrics)
                        .tint(.appGold)
                    Toggle("تشفير قاعدة البيانات", isOn: $encryptDB)
                        .tint(.appGold)
                } header: {
                    Text("الأمان")
                }

                // Prices
                Section {
                    Toggle("تحديث تلقائي للأسعار", isOn: $autoUpdatePrices)
                        .tint(.appGold)

                    if let lastUpdate = priceService.lastUpdateTime {
                        HStack {
                            Text("آخر تحديث")
                            Spacer()
                            Text(lastUpdate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                    Button {
                        priceService.updateAllPrices()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.appGold)
                            Text("تحديث الأسعار الآن")
                                .foregroundColor(.appGold)
                        }
                    }

                    NavigationLink(destination: PriceHistoryView()) {
                        Text("سجل الأسعار")
                    }
                } header: {
                    Text("الأسعار")
                }

                // Notifications
                Section {
                    Toggle("تذكير زكاة (رمضان)", isOn: $zakatReminderEnabled)
                        .tint(.appGold)
                    Toggle("تذكير دفعات الصناديق", isOn: $fundPaymentReminderEnabled)
                        .tint(.appGold)
                } header: {
                    Text("الإشعارات")
                }

                // Web Portal
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("رابط بوابة الأعضاء")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("http://localhost:5000", text: $backendURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .onChange(of: backendURL) { value in
                                UserDefaults.standard.set(value, forKey: "backendURL")
                            }
                    }
                    NavigationLink(destination: WebAccessCodesView()) {
                        Text("رموز وصول الأعضاء")
                    }
                } header: {
                    Text("بوابة الويب")
                }

                // Data
                Section {
                    NavigationLink(destination: ImportExportView()) {
                        Label("استيراد / تصدير", systemImage: "arrow.up.arrow.down")
                    }
                    Button {
                        // Backup database
                        backupDatabase()
                    } label: {
                        Label("نسخ احتياطي", systemImage: "externaldrive.fill")
                            .foregroundColor(.appGold)
                    }
                } header: {
                    Text("البيانات")
                }

                // About
                Section {
                    HStack {
                        Text("الإصدار")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("اسم التطبيق")
                        Spacer()
                        Text("نظام تتبع الاستثمارات والزكاة")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("عن التطبيق")
                }
            }
            .listStyle(.insetGrouped)
            .background(Color.appDarkBlue.ignoresSafeArea())
            .navigationTitle("الإعدادات")
        }
    }

    private func backupDatabase() {
        let db = DatabaseManager.shared
        // Export all data as JSON backup
    }
}

// MARK: - Price History View
struct PriceHistoryView: View {
    @State private var prices: [(symbol: String, price: Decimal, timestamp: Date, source: String)] = []

    var body: some View {
        List {
            ForEach(prices, id: \.symbol) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.symbol)
                            .font(.subheadline.bold())
                        Text(item.source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(item.price.formattedSAR())
                            .font(.subheadline)
                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("سجل الأسعار")
        .onAppear { loadPrices() }
    }

    private func loadPrices() {
        let db = DatabaseManager.shared
        let rows = db.query("SELECT * FROM price_cache ORDER BY timestamp DESC")
        prices = rows.compactMap { row in
            guard let symbol = row["symbol"] as? String,
                  let price = (row["price"] as? Double).map({ Decimal($0) }),
                  let timestampStr = row["timestamp"] as? String,
                  let timestamp = ISO8601DateFormatter().date(from: timestampStr) else { return nil }
            return (symbol: symbol, price: price, timestamp: timestamp,
                    source: row["source"] as? String ?? "")
        }
    }
}

// MARK: - Web Access Codes View
struct WebAccessCodesView: View {
    @State private var members: [(name: String, code: String, fundName: String)] = []

    var body: some View {
        List {
            ForEach(members, id: \.code) { member in
                HStack {
                    VStack(alignment: .leading) {
                        Text(member.name)
                            .font(.subheadline.bold())
                        Text(member.fundName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(member.code)
                            .font(.title3.bold().monospaced())
                            .foregroundColor(.appGold)
                        Button("نسخ") {
                            UIPasteboard.general.string = member.code
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("رموز الوصول")
        .onAppear { loadCodes() }
    }

    private func loadCodes() {
        let db = DatabaseManager.shared
        let rows = db.query("""
            SELECT fm.name, fm.web_access_code, f.name as fund_name
            FROM fund_members fm
            INNER JOIN funds f ON f.id = fm.fund_id
            WHERE fm.web_access_enabled = 1 AND fm.is_active = 1
        """)
        members = rows.compactMap { row in
            guard let name = row["name"] as? String,
                  let code = row["web_access_code"] as? String,
                  let fundName = row["fund_name"] as? String else { return nil }
            return (name: name, code: code, fundName: fundName)
        }
    }
}

// MARK: - Import Export View
struct ImportExportView: View {
    var body: some View {
        List {
            Section("الاستيراد") {
                Button {
                    // Import transactions from Excel
                } label: {
                    Label("استيراد عمليات (Excel)", systemImage: "arrow.down.doc")
                        .foregroundColor(.appGold)
                }
                Button {
                    // Download template
                } label: {
                    Label("تنزيل القالب", systemImage: "arrow.down.circle")
                        .foregroundColor(.appGold)
                }
            }
            Section("التصدير") {
                Button {
                    // Export all transactions
                } label: {
                    Label("تصدير جميع العمليات (CSV)", systemImage: "arrow.up.doc")
                        .foregroundColor(.appGold)
                }
            }
        }
        .navigationTitle("استيراد / تصدير")
    }
}
